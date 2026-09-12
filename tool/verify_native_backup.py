"""Restore a production backup into an isolated local PostgreSQL 17 database.

Uses the deployed backup command over pinned SSH. On Windows the existing
development PostgreSQL container is reached through WSL; no production data is
restored to the development database. Private dumps stay under .local/private.
"""
import datetime as dt
import csv
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
COUNT_SQL = r"""
SELECT format('SELECT %L,count(*) FROM %I.%I', tablename, schemaname, tablename)
FROM pg_tables WHERE schemaname='public' ORDER BY tablename
\gexec
"""


def run(args, *, input=None, timeout=180):
    result = subprocess.run(args, input=input, text=True, capture_output=True,
                            encoding='utf-8', timeout=timeout, cwd=ROOT)
    if result.returncode:
        # pg_restore errors can include row contents. Keep them out of reports.
        raise RuntimeError(f'{Path(args[0]).name} failed (exit {result.returncode}).')
    return result.stdout.strip()


def counts(text):
    return {name: int(value) for name, value in
            (line.split('|', 1) for line in text.splitlines() if line)}


def main():
    key = ROOT / '.local/private/deploy_key'
    hosts = ROOT / '.local/private/known_hosts'
    private = ROOT / '.local/private/backups'
    private.mkdir(parents=True, exist_ok=True)
    if os.name == 'nt':
        sid = next(csv.reader([run(['whoami', '/user', '/fo', 'csv', '/nh'])]))[1]
        run(['icacls', str(private), '/inheritance:r', '/grant:r',
             f'*{sid}:(OI)(CI)F', '*S-1-5-18:(OI)(CI)F'])
    else:
        private.chmod(0o700)
    ssh_options = ['-i', str(key), '-o', 'IdentitiesOnly=yes', '-o', 'BatchMode=yes',
                   '-o', 'StrictHostKeyChecking=yes', '-o', f'UserKnownHostsFile={hosts}']
    target = 'root@103.49.61.222'
    remote = '''import contextlib, hashlib, importlib.util, io, json, subprocess
spec = importlib.util.spec_from_file_location('manage','/opt/gomoku/native/manage.py')
manage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manage)
sql = SQL_PLACEHOLDER
def counts():
    raw = subprocess.run(['runuser','-u','postgres','--','psql','-XAtq','-v',
                         'ON_ERROR_STOP=1','-d','gomoku'], input=sql, text=True,
                         capture_output=True, check=True).stdout
    return {name:int(value) for name,value in
            (line.split('|',1) for line in raw.splitlines() if line)}
before = counts()
with contextlib.redirect_stdout(io.StringIO()):
    path = manage.backup()
after = counts()
print(json.dumps({'file':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                  'before':before,'after':after}))
'''.replace('SQL_PLACEHOLDER', repr(COUNT_SQL))
    docker = (['wsl', '-d', os.environ.get('GOMOKU_WSL_DISTRIBUTION', 'Ubuntu-22.04'),
               '-u', 'root', '--exec', 'docker'] if os.name == 'nt' else ['docker'])
    container = os.environ.get('GOMOKU_POSTGRES_CONTAINER', 'gomoku-postgres-1')
    stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%d_%H%M%S')
    database = f'gomoku_restore_{stamp}'
    if not re.fullmatch(r'gomoku_restore_\d{8}_\d{6}', database):
        raise ValueError('Invalid isolated database name.')
    temporary = f'/tmp/{database}.dump'
    created = False
    copied = False
    report = {'startedAt': dt.datetime.now(dt.timezone.utc).isoformat(),
              'status': 'running', 'database': database, 'stage': 'remote backup'}
    output = ROOT / 'artifacts/production/backup-restore.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    try:
        metadata = json.loads(run(['ssh', *ssh_options, target, 'python3', '-'], input=remote))
        source = metadata['file']
        if not re.fullmatch(r'/var/backups/gomoku/gomoku-[\d-]+(?:-[a-f0-9]+)?\.dump', source):
            raise ValueError('Unexpected remote backup path.')
        backup = private / Path(source).name
        report['stage'] = 'private download'
        run(['scp', *ssh_options, f'{target}:{source}', str(backup)])
        if os.name != 'nt':
            backup.chmod(0o600)
        digest = hashlib.sha256(backup.read_bytes()).hexdigest()
        if digest != metadata['sha256']:
            raise RuntimeError('Downloaded backup checksum mismatch.')
        report.update({'backup': backup.name, 'sha256': digest, 'bytes': backup.stat().st_size})
        version = run([*docker, 'exec', container, 'psql', '-U', 'postgres', '-Atqc',
                       'SHOW server_version_num'])
        if not version.startswith('17'):
            raise RuntimeError('Restore verification requires PostgreSQL 17.')
        report['postgresVersion'] = version
        exists = run([*docker, 'exec', container, 'psql', '-U', 'postgres', '-Atqc',
                      f"SELECT 1 FROM pg_database WHERE datname='{database}'"])
        if exists:
            raise RuntimeError('The isolated restore database already exists.')
        run([*docker, 'exec', container, 'createdb', '-U', 'postgres', database])
        created = True
        local_path = str(backup)
        if os.name == 'nt':
            local_path = run([*docker[:-1], 'wslpath', '-u', str(backup)])
        run([*docker, 'cp', local_path, f'{container}:{temporary}'])
        copied = True
        report['stage'] = 'isolated restore'
        run([*docker, 'exec', container, 'pg_restore', '--exit-on-error', '--single-transaction',
             '--no-owner', '--no-acl', '-U', 'postgres', '--dbname', database, temporary])
        restored = counts(run([*docker, 'exec', '-i', container, 'psql', '-XAtq',
                               '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', database],
                              input=COUNT_SQL))
        before, after = metadata['before'], metadata['after']
        if restored.keys() != before.keys() or restored.keys() != after.keys():
            raise RuntimeError('The restored schema has a different set of tables.')
        # Play continues during pg_dump. Stable table counts must match exactly;
        # changing table counts must lie within the observed backup interval.
        for table, count in restored.items():
            if not min(before[table], after[table]) <= count <= max(before[table], after[table]):
                raise RuntimeError(f'Restored row count is outside the backup interval: {table}.')
        if restored['gm_private_accounts'] != 2 or restored['gm_players'] != 2:
            raise RuntimeError('The fixed account identities were not restored.')
        report.update({'status': 'passed', 'tables': len(restored),
                       'rowCounts': restored, 'sourceBefore': before, 'sourceAfter': after,
                       'verification': 'All objects restored in one transaction; stable counts match, '
                                       'changing counts lie within the concurrent backup interval.'})
        report.pop('stage', None)
        print(f'PASS: PostgreSQL 17 restored {len(restored)} tables; checksum and row counts verified.')
    except Exception as error:
        report.update({'status': 'failed', 'error': type(error).__name__})
        print('Backup verification failed during ' + report['stage'] + '.', file=sys.stderr)
        raise
    finally:
        # Only this invocation's newly created database and temporary file.
        if created:
            run([*docker, 'exec', container, 'dropdb', '-U', 'postgres', database])
        if copied:
            run([*docker, 'exec', container, 'rm', '--', temporary])
        report['finishedAt'] = dt.datetime.now(dt.timezone.utc).isoformat()
        output.write_text(json.dumps(report, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
