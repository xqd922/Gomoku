#!/usr/bin/env python3
"""Root-only, bounded deployment operations for the small Debian 12 host.

Secrets stay in /etc/gomoku. No credential is passed to a log or release asset.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import socket
import subprocess
import tarfile
import tempfile
import time
import urllib.request

ROOT = Path('/opt/gomoku')
ETC = Path('/etc/gomoku')
DATA = Path('/var/lib/gomoku')
BACKUPS = Path('/var/backups/gomoku')
SOURCE = Path(__file__).resolve().parent


def run(args, *, text=None, capture=False, check=True, env=None, cwd=None, timeout=300):
    return subprocess.run(args, input=text, text=True, capture_output=capture,
                          check=check, env=env, cwd=cwd, timeout=timeout)


def write(path, value, mode=0o644):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, mode)
    with os.fdopen(fd, 'w') as handle:
        handle.write(value)
    path.chmod(mode)


def replace_owned(path, value, metadata):
    """Atomically replace an existing service config without changing its access."""
    path = Path(path)
    fd, name = tempfile.mkstemp(prefix=path.name + '.', dir=path.parent)
    try:
        os.fchown(fd, metadata.st_uid, metadata.st_gid)
        os.fchmod(fd, metadata.st_mode & 0o777)
        with os.fdopen(fd, 'w') as handle:
            handle.write(value)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def environment():
    result = os.environ.copy()
    for line in (ETC / 'runtime.env').read_text().splitlines():
        if line and not line.startswith('#'):
            key, value = line.split('=', 1)
            result[key] = value
    return result


def systemctl(*args, check=True):
    return run(['systemctl', *args], check=check)


def status():
    with urllib.request.urlopen('http://127.0.0.1:8082/health', timeout=3) as response:
        return json.load(response)


def wait_health(commit=None):
    for _ in range(40):
        try:
            value = status()
            if value['status'] == 'ok' and (commit is None or value['commit'] == commit):
                return value
        except Exception:
            pass
        time.sleep(2)
    raise RuntimeError('The application did not become healthy; inspect its journal.')


def caddy_config(domain, production=False):
    tls = 'tls {\n        issuer acme {\n            disable_http_challenge\n        }\n    }' if production else 'tls internal'
    return (SOURCE / 'Caddyfile').read_text().replace('@DOMAIN@', domain).replace('@TLS@', tls)


def proxy_config(domain, testing=False):
    return ((SOURCE / 'haproxy.cfg').read_text().replace('@DOMAIN@', domain)
            .replace('@BIND@', '127.0.0.1:11443' if testing else '[::]:443 v4v6')
            .replace('@XRAY_PORT@', '443' if testing else '10443'))


def bootstrap(domain):
    if not re.fullmatch(r'[a-z0-9][a-z0-9.-]+\.[a-z]{2,}', domain):
        raise ValueError('Provide a DNS hostname.')
    ROOT.mkdir(parents=True, exist_ok=True)
    ETC.mkdir(mode=0o750, parents=True, exist_ok=True)
    DATA.mkdir(mode=0o750, parents=True, exist_ok=True)
    swap = Path('/var/lib/gomoku.swap')
    if not swap.exists():
        run(['fallocate', '-l', '512M', str(swap)])
        swap.chmod(0o600)
        run(['mkswap', str(swap)], capture=True)
    active_swap = run(['swapon', '--show=NAME', '--noheadings'], capture=True).stdout.splitlines()
    if str(swap) not in active_swap:
        run(['swapon', str(swap)])
    if str(swap) not in Path('/etc/fstab').read_text():
        with open('/etc/fstab', 'a') as handle:
            handle.write(f'\n{swap} none swap sw 0 0\n')
    run(['apt-get', 'update', '-qq'])
    run(['apt-get', 'install', '-y', '--no-install-recommends', 'ca-certificates', 'curl', 'gnupg'],
        env={**os.environ, 'DEBIAN_FRONTEND': 'noninteractive'})
    with tempfile.TemporaryDirectory(prefix='gomoku-pgdg-') as temporary:
        key = Path(temporary) / 'key.asc'
        run(['curl', '-fsSL', 'https://www.postgresql.org/media/keys/ACCC4CF8.asc', '-o', str(key)])
        run(['gpg', '--batch', '--yes', '--dearmor', '-o', '/usr/share/keyrings/gomoku-pgdg.gpg', str(key)])
    write('/etc/apt/sources.list.d/gomoku-pgdg.list',
          'deb [signed-by=/usr/share/keyrings/gomoku-pgdg.gpg] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main\n')
    run(['apt-get', 'update', '-qq'])
    run(['apt-get', 'install', '-y', '--no-install-recommends', 'postgresql-17', 'redis-server', 'haproxy', 'nftables'],
        env={**os.environ, 'DEBIAN_FRONTEND': 'noninteractive'})
    for name in ['gomoku', 'caddy']:
        if run(['id', '-u', name], capture=True, check=False).returncode:
            run(['useradd', '--system', '--create-home', '--home-dir', f'/var/lib/{name}', '--shell', '/usr/sbin/nologin', name])
    run(['chown', 'gomoku:gomoku', str(DATA)])
    if not (ETC / 'runtime.env').exists():
        values = {
            'GOMOKU_DOMAIN': domain, 'GOMOKU_AUTH_MODE': 'private',
            'COOKIE_SECURE': 'true', 'TRUST_PROXY': 'true',
            'ALLOWED_ORIGINS': 'https://' + domain,
            'SERVERPOD_API_SERVER_PUBLIC_HOST': domain,
            'SERVERPOD_WEB_SERVER_PUBLIC_HOST': domain,
            'SERVERPOD_PASSWORD_database': secrets.token_hex(32),
            'SERVERPOD_PASSWORD_redis': secrets.token_hex(32),
            'SERVERPOD_PASSWORD_emailSecretHashPepper': secrets.token_hex(32),
            'SERVERPOD_PASSWORD_serverSideSessionKeyHashPepper': secrets.token_hex(32),
            'GOMOKU_ACCOUNTS_FILE': str(ETC / 'initial-accounts.json'),
        }
        write(ETC / 'runtime.env', ''.join(f'{k}={v}\n' for k, v in values.items()), 0o600)
    env = environment()
    if env['GOMOKU_DOMAIN'] != domain:
        raise RuntimeError('The existing deployment uses a different domain.')
    if not (ETC / 'initial-accounts.json').exists():
        passwords = set()
        while len(passwords) < 2:
            passwords.add(str(secrets.randbelow(90_000_000) + 10_000_000))
        accounts = [{'login': str(i), 'email': f'player{i}@{domain}',
                     'nickname': '玩家一' if i == 1 else '玩家二',
                     'password': passwords.pop()} for i in (1, 2)]
        write(ETC / 'initial-accounts.json', json.dumps(accounts, ensure_ascii=False, indent=2), 0o600)
    write('/etc/postgresql/17/main/conf.d/gomoku.conf',
          "listen_addresses = '127.0.0.1'\nshared_buffers = '16MB'\nmax_connections = 16\nwork_mem = '1MB'\nmaintenance_work_mem = '16MB'\nmax_wal_size = '128MB'\nmin_wal_size = '32MB'\n")
    systemctl('restart', 'postgresql@17-main')
    role = run(['runuser', '-u', 'postgres', '--', 'psql', '-Atqc', "SELECT 1 FROM pg_roles WHERE rolname='gomoku'"], capture=True).stdout.strip()
    if not role:
        run(['runuser', '-u', 'postgres', '--', 'psql', '-v', 'ON_ERROR_STOP=1'],
            text=f"CREATE ROLE gomoku LOGIN PASSWORD '{env['SERVERPOD_PASSWORD_database']}';\n", capture=True)
    database = run(['runuser', '-u', 'postgres', '--', 'psql', '-Atqc', "SELECT 1 FROM pg_database WHERE datname='gomoku'"], capture=True).stdout.strip()
    if not database:
        run(['runuser', '-u', 'postgres', '--', 'createdb', '--owner=gomoku', 'gomoku'])
    write('/etc/redis/redis.conf',
          f"bind 127.0.0.1\nport 6379\nprotected-mode yes\ndaemonize no\nsupervised systemd\nrequirepass {env['SERVERPOD_PASSWORD_redis']}\nmaxmemory 16mb\nmaxmemory-policy allkeys-lru\nsave \"\"\nappendonly no\nlogfile \"\"\ndir /var/lib/redis\n", 0o640)
    run(['chown', 'redis:redis', '/etc/redis/redis.conf'])
    systemctl('restart', 'redis-server')
    with tempfile.TemporaryDirectory(prefix='gomoku-caddy-') as temporary:
        folder = Path(temporary)
        name = 'caddy_2.10.2_linux_amd64.tar.gz'
        base = 'https://github.com/caddyserver/caddy/releases/download/v2.10.2/'
        for filename in [name, 'caddy_2.10.2_checksums.txt']:
            run(['curl', '-fLsS', '--retry', '3', base + filename, '-o', str(folder / filename)])
        expected = next(line.split()[0] for line in (folder / 'caddy_2.10.2_checksums.txt').read_text().splitlines() if line.split()[-1] == name)
        digest = hashlib.sha512 if len(expected) == 128 else hashlib.sha256
        if digest((folder / name).read_bytes()).hexdigest() != expected:
            raise RuntimeError('Caddy checksum mismatch.')
        with tarfile.open(folder / name) as archive:
            with archive.extractfile('caddy') as source, open('/usr/local/bin/caddy', 'wb') as target:
                shutil.copyfileobj(source, target)
        Path('/usr/local/bin/caddy').chmod(0o755)
    modules = run(['/usr/local/bin/caddy', 'list-modules'], capture=True).stdout
    if 'caddy.listeners.proxy_protocol' not in modules:
        raise RuntimeError('The Caddy build must support the PROXY protocol.')
    write('/etc/systemd/system/gomoku.service', '''[Unit]
Description=Gomoku private game service
After=network-online.target postgresql@17-main.service redis-server.service
Wants=network-online.target
[Service]
User=gomoku
Group=gomoku
WorkingDirectory=/opt/gomoku/current
EnvironmentFile=/etc/gomoku/runtime.env
EnvironmentFile=-/opt/gomoku/current/build.env
ExecStart=/opt/gomoku/current/gomoku-server --mode production --apply-migrations
Restart=on-failure
RestartSec=5
TimeoutStopSec=20
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=/var/lib/gomoku
IPAddressDeny=any
IPAddressAllow=localhost
MemoryHigh=160M
MemoryMax=224M
[Install]
WantedBy=multi-user.target
''')
    write('/etc/systemd/system/caddy.service', '''[Unit]
Description=Gomoku HTTPS and Web
After=network-online.target
Wants=network-online.target
[Service]
User=caddy
Group=caddy
Environment=HOME=/var/lib/caddy
ExecStart=/usr/local/bin/caddy run --config /etc/gomoku/Caddyfile --adapter caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/gomoku/Caddyfile --adapter caddyfile
Restart=on-failure
RestartSec=5
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/var/lib/caddy
MemoryHigh=64M
[Install]
WantedBy=multi-user.target
''')
    # Only the loopback proxy can reach the game services. Existing ports are untouched.
    rules = '''table inet gomoku_guard {
chain input {
type filter hook input priority -5; policy accept;
iifname != "lo" tcp dport {8080,8081,8082,5432,6379,9443,10443,2019} drop
}
}
'''
    write(ETC / 'firewall.nft', rules)
    write('/etc/systemd/system/gomoku-firewall.service', '''[Unit]
Description=Gomoku private service ports
Before=gomoku.service caddy.service
[Service]
Type=oneshot
ExecStartPre=-/usr/sbin/nft delete table inet gomoku_guard
ExecStart=/usr/sbin/nft -f /etc/gomoku/firewall.nft
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
''')
    write('/etc/systemd/journald.conf.d/gomoku-limits.conf', '[Journal]\nSystemMaxUse=50M\nRuntimeMaxUse=20M\n')
    systemctl('restart', 'systemd-journald')
    if not (ETC / 'Caddyfile').exists():
        write(ETC / 'Caddyfile', caddy_config(domain))
    ETC.chmod(0o755)  # Secret files themselves are root-readable only.
    systemctl('daemon-reload')
    systemctl('enable', '--now', 'gomoku-firewall.service')
    systemctl('enable', 'postgresql', 'redis-server', 'caddy', 'gomoku')
    run(['apt-get', 'clean'])
    print('Native dependencies and private configuration are ready. No credentials were printed.')


def backup():
    folder = BACKUPS
    folder.mkdir(mode=0o700, parents=True, exist_ok=True)
    path = folder / time.strftime('gomoku-%Y%m%d-%H%M%S.dump')
    if path.exists():
        path = folder / (path.stem + '-' + secrets.token_hex(3) + '.dump')
    temp = path.with_suffix('.partial')
    with open(temp, 'wb') as handle:
        os.chmod(temp, 0o600)
        subprocess.run(['runuser', '-u', 'postgres', '--', 'pg_dump', '-Fc', '-d', 'gomoku'], stdout=handle, check=True)
    run(['pg_restore', '--list', str(temp)], capture=True)
    temp.rename(path)
    for old in sorted(folder.glob('gomoku-*.dump'), reverse=True)[3:]:
        old.unlink()
    print('Database backup verified:', path.name)
    return path


def install_archive(archive_path):
    releases = ROOT / 'releases'
    releases.mkdir(parents=True, exist_ok=True)
    with tarfile.open(archive_path) as archive:
        for member in archive.getmembers():
            if member.name.startswith('/') or '..' in Path(member.name).parts or not (member.isfile() or member.isdir()):
                raise ValueError('Unsafe release archive entry.')
        with archive.extractfile('build-info.json') as handle:
            meta = json.load(handle)
        if not re.fullmatch(r'[0-9a-f]{40}', meta['commit']):
            raise ValueError('A release must identify its source commit.')
        target = releases / meta['commit']
        if not target.exists():
            target.mkdir()
            try:
                archive.extractall(target)
                for name in ['gomoku-server', 'config/production.yaml', 'db/003_private_accounts.sql', 'build.env', 'web/index.html']:
                    if not (target / name).is_file():
                        raise ValueError('Incomplete release archive.')
                (target / 'gomoku-server').chmod(0o755)
            except Exception:
                shutil.rmtree(target)
                raise
    backup()
    current = ROOT / 'current'
    previous = current.resolve() if current.exists() else None
    link = ROOT / 'next'
    link.unlink(missing_ok=True)
    link.symlink_to(target, target_is_directory=True)
    systemctl('stop', 'gomoku', check=False)
    os.replace(link, current)
    try:
        systemctl('start', 'gomoku')
        wait_health(meta['commit'])
        run([str(target / 'gomoku-server'), '--mode', 'production', '--gomoku-admin=provision'],
            env=environment(), cwd=target, capture=True)
        if shutil.disk_usage(ROOT).free < 500 * 1024 * 1024:
            raise RuntimeError('Deployment must retain 500 MiB free disk space.')
        systemctl('start', 'caddy')
        if previous and previous != target:
            saved = ROOT / 'previous'
            saved.unlink(missing_ok=True)
            saved.symlink_to(previous, target_is_directory=True)
        retained = ROOT / 'previous'
        keep = {target, retained.resolve() if retained.is_symlink() else previous}
        for folder in releases.iterdir():
            if folder.is_dir() and folder not in keep and folder.parent == releases:
                shutil.rmtree(folder)
    except Exception:
        systemctl('stop', 'gomoku', check=False)
        if previous:
            current.unlink()
            current.symlink_to(previous, target_is_directory=True)
            systemctl('start', 'gomoku')
        raise
    write('/etc/systemd/system/gomoku-backup.service', f'[Service]\nType=oneshot\nExecStart=/usr/bin/python3 {SOURCE / "manage.py"} backup\n')
    write('/etc/systemd/system/gomoku-backup.timer', '[Unit]\nDescription=Daily Gomoku backup\n[Timer]\nOnCalendar=*-*-* 03:30:00\nPersistent=true\n[Install]\nWantedBy=timers.target\n')
    systemctl('daemon-reload')
    systemctl('enable', '--now', 'gomoku-backup.timer')
    print('Application installed:', meta['version'], meta['commit'])


def rollback():
    current, previous = ROOT / 'current', ROOT / 'previous'
    if not current.is_symlink() or not previous.is_symlink():
        raise RuntimeError('A current and previous release are required.')
    old, target = current.resolve(), previous.resolve()
    if target.parent != ROOT / 'releases' or not target.is_dir():
        raise ValueError('The previous release is outside the release directory.')
    backup()
    systemctl('stop', 'gomoku')
    current.unlink()
    current.symlink_to(target, target_is_directory=True)
    try:
        systemctl('start', 'gomoku')
        wait_health(json.loads((target / 'build-info.json').read_text())['commit'])
    except Exception:
        systemctl('stop', 'gomoku', check=False)
        current.unlink()
        current.symlink_to(old, target_is_directory=True)
        systemctl('start', 'gomoku')
        raise
    previous.unlink()
    previous.symlink_to(old, target_is_directory=True)
    print('Previous application restored. Database migrations remain append-only.')


def restore_backup(value, confirm):
    if confirm != 'gomoku':
        raise ValueError('Database restore requires --confirm-database gomoku.')
    source = Path(value).resolve(strict=True)
    run(['pg_restore', '--list', str(source)], capture=True)
    # Preserve the selected backup even if retention cleanup would remove it.
    with tempfile.TemporaryDirectory(prefix='gomoku-restore-') as temporary:
        copy = Path(temporary) / 'restore.dump'
        shutil.copyfile(source, copy)
        copy.chmod(0o600)
        backup()
        systemctl('stop', 'gomoku')
        # --single-transaction leaves the existing database intact on failure.
        try:
            with copy.open('rb') as handle:
                subprocess.run(['runuser', '-u', 'postgres', '--', 'pg_restore',
                                '--clean', '--if-exists', '--single-transaction',
                                '--exit-on-error', '--dbname=gomoku'], stdin=handle,
                               check=True, capture_output=True)
        finally:
            systemctl('start', 'gomoku')
        wait_health()
    print('Database restored and application health verified.')


def proxy_probe(configuration, port):
    inbound = next(i for i in configuration['inbounds'] if i.get('streamSettings', {}).get('security') == 'reality')
    reality = inbound['streamSettings']['realitySettings']
    # Derive X25519 via stdin: never expose the private key in process arguments.
    private_key = base64.urlsafe_b64decode(reality['privateKey'] + '==')
    if len(private_key) != 32:
        raise ValueError('The existing REALITY key has an unexpected format.')
    derived = subprocess.run(['openssl', 'pkey', '-inform', 'DER', '-pubout', '-outform', 'DER'],
                             input=bytes.fromhex('302e020100300506032b656e04220420') + private_key,
                             capture_output=True, check=True).stdout
    public_key = base64.urlsafe_b64encode(derived[-32:]).decode().rstrip('=')
    client = inbound['settings']['clients'][0]
    with socket.socket() as s:
        s.bind(('127.0.0.1', 0))
        socks_port = s.getsockname()[1]
    with tempfile.TemporaryDirectory(prefix='gomoku-proxy-check-') as temporary:
        path = Path(temporary) / 'client.json'
        config = {'log': {'loglevel': 'none'}, 'inbounds': [{'listen': '127.0.0.1', 'port': socks_port, 'protocol': 'socks', 'settings': {'auth': 'noauth'}}],
                  'outbounds': [{'protocol': 'vless', 'settings': {'vnext': [{'address':'127.0.0.1', 'port':port, 'users':[{'id':client['id'],'encryption':'none','flow':client.get('flow','')}]}]},
                                 'streamSettings': {'network':'tcp','security':'reality','realitySettings': {'fingerprint':'chrome','serverName':reality['serverNames'][0],'publicKey':public_key,'shortId':reality['shortIds'][0]}}}]}
        write(path, json.dumps(config), 0o600)
        process = subprocess.Popen(['/usr/local/bin/xray', 'run', '-config', str(path)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            time.sleep(1)
            run(['curl','-fsS','--max-time','20','--socks5-hostname',f'127.0.0.1:{socks_port}','https://example.com/'], capture=True)
        finally:
            process.terminate()
            process.wait(timeout=10)


def gateway():
    domain = environment()['GOMOKU_DOMAIN']
    xray_path = Path('/usr/local/etc/xray/config.json')
    original = xray_path.read_text()
    original_metadata = xray_path.stat()
    config = json.loads(original)
    inbound = next(i for i in config['inbounds'] if i.get('port') in (443,10443) and i.get('streamSettings',{}).get('security') == 'reality')
    if inbound['port'] == 10443:
        proxy_probe(config, 443)
        run(['curl','-fsS','--max-time','10',f'https://{domain}/health'], capture=True)
        print('The shared HTTPS gateway is already healthy.')
        return
    proxy_probe(config, 443)
    write(ETC / 'haproxy-test.cfg', proxy_config(domain, testing=True))
    run(['haproxy','-c','-f',str(ETC / 'haproxy-test.cfg')], capture=True)
    test_process = subprocess.Popen(['haproxy','-db','-f',str(ETC / 'haproxy-test.cfg')], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        time.sleep(1)
        proxy_probe(config, 11443)
        run(['curl','-kfsS','--max-time','10','--resolve',f'{domain}:11443:127.0.0.1',f'https://{domain}:11443/health'], capture=True)
    finally:
        test_process.terminate()
        test_process.wait(timeout=10)
    write(ETC / 'xray-before-gomoku.json', original, 0o600)
    old_caddy = (ETC / 'Caddyfile').read_text()
    inbound['listen'] = '127.0.0.1'
    inbound['port'] = 10443
    write(ETC / 'xray-candidate.json', json.dumps(config, indent=2), 0o600)
    run(['/usr/local/bin/xray','run','-test','-config',str(ETC / 'xray-candidate.json')], capture=True)
    write('/etc/haproxy/haproxy.cfg', proxy_config(domain))
    run(['haproxy','-c','-f','/etc/haproxy/haproxy.cfg'], capture=True)
    try:
        replace_owned(xray_path, json.dumps(config, indent=2), original_metadata)
        systemctl('restart','xray')
        systemctl('enable','haproxy')
        # Debian may already have started the package's default configuration.
        # A restart is required to load the newly validated listener and routes.
        systemctl('restart','haproxy')
        proxy_probe(config, 443)
        write(ETC / 'Caddyfile', caddy_config(domain, production=True))
        systemctl('reload','caddy')
        for _ in range(40):
            result = run(['curl','-fsS','--max-time','5','--resolve',f'{domain}:443:127.0.0.1',f'https://{domain}/health'], capture=True, check=False)
            if result.returncode == 0:
                break
            time.sleep(3)
        else:
            raise RuntimeError('Public TLS verification failed.')
        proxy_probe(config, 443)
    except Exception:
        systemctl('stop','haproxy', check=False)
        replace_owned(xray_path, original, original_metadata)
        systemctl('restart','xray')
        write(ETC / 'Caddyfile', old_caddy)
        systemctl('reload','caddy', check=False)
        raise
    print('HTTPS and the existing REALITY proxy passed gateway checks. Test WebSocket gameplay separately.')


def reset_password(email):
    import getpass
    password = getpass.getpass('New password (8–128 characters): ')
    if password != getpass.getpass('Confirm password: '):
        raise ValueError('Passwords do not match.')
    with tempfile.TemporaryDirectory(prefix='gomoku-reset-') as temporary:
        path = Path(temporary) / 'reset.json'
        write(path, json.dumps({'email': email,'password': password}), 0o600)
        run([str(ROOT / 'current/gomoku-server'),'--mode','production','--gomoku-admin=reset-password'],
            env={**environment(),'GOMOKU_RESET_FILE':str(path)},cwd=ROOT / 'current',capture=True)
    print('Password changed and prior sessions revoked.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['bootstrap','install','gateway','backup','restore','rollback','status','reset-password'])
    parser.add_argument('value', nargs='?')
    parser.add_argument('--confirm-database')
    args = parser.parse_args()
    if os.geteuid() != 0:
        raise SystemExit('Run this deployment tool as root.')
    try:
        if args.operation == 'bootstrap': bootstrap(args.value)
        elif args.operation == 'install': install_archive(args.value)
        elif args.operation == 'gateway': gateway()
        elif args.operation == 'backup': backup()
        elif args.operation == 'restore': restore_backup(args.value, args.confirm_database)
        elif args.operation == 'rollback': rollback()
        elif args.operation == 'reset-password': reset_password(args.value)
        else: print(json.dumps(status()))
    except Exception as error:
        # Subprocess details and configuration may include credentials.
        program = f', program={Path(error.cmd[0]).name}' if isinstance(error, subprocess.CalledProcessError) else ''
        detail = f' {error}' if type(error) is RuntimeError else ''
        raise SystemExit(f'{args.operation} failed ({type(error).__name__}{program}).{detail} Inspect the relevant service journal; credentials were not printed.') from None
