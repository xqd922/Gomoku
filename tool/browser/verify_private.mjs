import assert from 'node:assert/strict';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { chromium } from 'playwright';

const origin = process.env.GOMOKU_WEB_URL || 'https://gomoku.xqd.pp.ua';
assert.equal(new URL(origin).protocol, 'https:');
assert.ok(process.env.GOMOKU_ACCOUNTS_FILE, 'Set the private account file path.');
const accounts = JSON.parse(await readFile(process.env.GOMOKU_ACCOUNTS_FILE, 'utf8'));
assert.equal(accounts.length, 2);
const output = resolve(import.meta.dirname, '../../artifacts/production/browser');
await mkdir(output, { recursive: true });
const chrome = process.env.GOMOKU_CHROME_PATH ||
  (process.platform === 'win32' ? 'C:/Program Files/Google/Chrome/Application/chrome.exe' : undefined);
const browser = await chromium.launch({ headless: true,
  ...(chrome && existsSync(chrome) ? { executablePath: chrome } : {}) });
const pages = [], passed = [], errors = [];
const network = [];
let stage = 'public configuration';
const report = { startedAt: new Date().toISOString(), origin, passed, status: 'running' };
async function until(check, reason, timeout = 40000) {
  const end = Date.now() + timeout;
  while (!await check()) {
    if (Date.now() > end) throw new Error(reason);
    await new Promise(resolve => setTimeout(resolve, 100));
  }
}
async function navigate(page, path) {
  await page.goto(origin + path, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('flutter-view');
  const placeholder = page.locator('flt-semantics-placeholder');
  if (await placeholder.count()) await placeholder.evaluate(element => element.click());
  await until(() => page.locator('flt-semantics-host').evaluate(e => e.childElementCount > 0), 'semantics');
}
async function boot(context, path = '/') {
  const page = await context.newPage();
  page.setDefaultTimeout(20000);
  page.on('pageerror', error => errors.push(error.name));
  const index = pages.length;
  page.on('response', response => {
    const path = new URL(response.url()).pathname;
    if (path.startsWith('/auth/')) {
      network.push({ at: new Date().toISOString(), page: index, path, status: response.status() });
    }
  });
  page.on('websocket', socket => socket.on('close', () => {
    network.push({ at: new Date().toISOString(), page: index, event: 'websocket_closed' });
  }));
  pages.push(page);
  await navigate(page, path);
  return page;
}
async function click(page, label) {
  const button = page.getByRole('button', { name: label, exact: true }).last();
  await until(() => button.isEnabled().catch(() => false), 'button unavailable');
  await button.click();
}
async function fill(page, label, value) {
  await page.getByRole('textbox', { name: label, exact: true }).click();
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  await page.waitForFunction(() => document.activeElement instanceof HTMLInputElement && !document.activeElement.readOnly);
  await page.keyboard.press('ControlOrMeta+A');
  await page.keyboard.type(value, { delay: 10 });
  await page.keyboard.press('Tab');
}
async function signIn(page, account) {
  await click(page, '登录');
  await page.waitForURL(url => url.pathname === '/account');
  assert.equal(await page.getByText('注册', { exact: true }).count(), 0);
  assert.equal(await page.getByText('忘记密码', { exact: true }).count(), 0);
  const shortLogin = await page.getByRole('textbox', { name: '账号', exact: true }).count();
  await fill(page, shortLogin ? '账号' : '邮箱地址', shortLogin ? account.login ?? account.email : account.email);
  await fill(page, '密码', account.password);
  await click(page, '登录');
}
async function snapshot(page) { return page.locator('body').ariaSnapshot(); }
async function move(page, point, other, color) {
  await page.getByRole('button', { name: point + '，空位', exact: true }).click();
  await click(page, '确认落子');
  await until(async () => (await snapshot(other)).includes(point + '，' + color), 'move broadcast');
}
async function capture(page, name) {
  await page.mouse.move(0, 0);
  await page.waitForTimeout(450);
  await page.screenshot({ path: resolve(output, name) });
}
function done(name) { passed.push(name); console.log('PASS: ' + name); }

try {
  const config = await fetch(origin + '/app-config');
  assert.equal(config.status, 200);
  assert.deepEqual(await config.json(), { authMode: 'private', guestOnline: false, registration: false, passwordReset: false });
  const health = await fetch(origin + '/health').then(r => r.json());
  assert.equal(health.status, 'ok');
  report.commit = health.commit;
  const wasm = await fetch(origin + '/sqlite3.wasm', { method: 'HEAD' });
  assert.match(wasm.headers.get('content-type'), /application\/wasm/);
  assert.equal(wasm.headers.get('cross-origin-embedder-policy'), 'require-corp');
  const links = await fetch(origin + '/.well-known/assetlinks.json').then(r => r.json());
  assert.equal(links[0].target.package_name, 'com.xqd922.gomoku');
  assert.ok(links[0].target.sha256_cert_fingerprints.includes('C5:BB:B8:80:6B:70:34:DB:C4:AB:65:65:2C:3F:89:83:9F:05:7D:78:2D:F3:1E:CE:4E:81:25:F5:79:2E:53:33'));
  const rejected = await fetch(origin + '/auth/login', { method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Gomoku-Client': 'web', 'Origin': 'https://example.invalid' }, body: '{}' });
  assert.equal(rejected.status, 403);
  const wrongPassword = await fetch(origin + '/auth/login', { method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Gomoku-Client': 'native' },
    body: JSON.stringify({ email: accounts[0].email, password: 'intentionally-wrong-password' }) });
  assert.equal(wrongPassword.status, 401);
  done('Public HTTPS, private capabilities, Wasm headers, App Links certificate and origin checks');

  stage = 'private login and invitation';
  const desktop = await browser.newContext({ viewport: { width: 1440, height: 1000 }, locale: 'zh-CN' });
  const phone = await browser.newContext({ viewport: { width: 390, height: 844 }, locale: 'zh-CN', hasTouch: true, isMobile: true });
  const a = await boot(desktop, '/lobby');
  assert.equal(await a.evaluate(() => crossOriginIsolated), true);
  await signIn(a, accounts[0]);
  await a.waitForURL(url => url.pathname === '/lobby');
  await click(a, '创建房间');
  await a.waitForURL(url => url.pathname.startsWith('/room/'));
  report.roomId = new URL(a.url()).pathname.split('/').pop();
  await until(async () => (await snapshot(a)).includes('六位房间码:'), 'room code');
  const code = (await snapshot(a)).match(/六位房间码: ([A-Z2-9 ]+)/)?.[1].replaceAll(' ', '');
  assert.ok(code);
  const b = await boot(phone, '/join/' + code);
  await signIn(b, accounts[1]);
  await b.waitForURL(url => url.pathname === '/join/' + code);
  await b.getByRole('textbox', { name: '六位房间码', exact: true }).waitFor();
  await click(b, '加入');
  await b.waitForURL(url => url.pathname.startsWith('/room/'));
  const cookie = (await desktop.cookies()).find(c => c.name === '__Host-gomoku_session');
  assert.ok(cookie?.httpOnly && cookie.secure && cookie.sameSite === 'Lax');
  assert.equal(await a.evaluate(() => document.cookie.includes('gomoku_session')), false);
  await click(a, '准备好了');
  await click(b, '准备好了');
  await a.getByRole('group', { name: '五子棋棋盘', exact: true }).waitFor();
  done('Two private accounts, secure HttpOnly session, invitation retained through sign-in, explicit join');

  stage = 'moves and undo';
  await move(a, 'H8', b, '黑棋');
  await move(b, 'H9', a, '白棋');
  await move(a, 'I8', b, '黑棋');
  await click(a, '申请悔棋');
  await click(b, '同意');
  await a.getByRole('button', { name: 'I8，空位', exact: true }).waitFor();
  await move(a, 'I8', b, '黑棋');
  await move(b, 'I9', a, '白棋');
  await capture(a, 'online-desktop.png');
  await capture(b, 'online-phone.png');
  done('Cross-client moves and consented undo');

  if (process.env.GOMOKU_RESTART_SSH_KEY) {
    stage = 'server restart';
    assert.ok(process.env.GOMOKU_KNOWN_HOSTS);
    await promisify(execFile)('ssh', ['-i', process.env.GOMOKU_RESTART_SSH_KEY,
      '-o', 'IdentitiesOnly=yes', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
      '-o', 'UserKnownHostsFile=' + process.env.GOMOKU_KNOWN_HOSTS,
      'root@103.49.61.222', 'systemctl', 'restart', 'gomoku'], { timeout: 45000 });
    await until(async () => {
      try { return (await fetch(origin + '/health')).ok; } catch { return false; }
    }, 'health after restart');
    await until(async () => (await snapshot(a)).includes('轮到你了') &&
      !(await snapshot(a)).includes('棋局已暂停') &&
      await a.getByRole('button', { name: '申请悔棋', exact: true }).isEnabled(), 'restart recovery');
    assert.ok((await snapshot(b)).includes('I8，黑棋') && (await snapshot(b)).includes('I9，白棋'));
    done('Production service restart preserves session, seats and board; browsers reconnect');
  }

  stage = 'network reconnection';
  await phone.setOffline(true);
  await until(async () => (await snapshot(a)).includes('棋局已暂停'), 'pause after disconnect');
  await phone.setOffline(false);
  await until(async () => (await snapshot(a)).includes('轮到你了') &&
    !(await snapshot(a)).includes('棋局已暂停') &&
    await a.getByRole('button', { name: '申请悔棋', exact: true }).isEnabled(), 'reconnect');
  done('Public-network disconnection pauses play and restores authoritative state');

  stage = 'finish, replay and rematch';
  for (const col of ['J', 'K']) {
    await move(a, col + '8', b, '黑棋');
    await move(b, col + '9', a, '白棋');
  }
  await move(a, 'L8', b, '黑棋');
  await until(async () => (await snapshot(b)).includes('黑棋获胜'), 'finished game');
  await capture(b, 'result-phone.png');
  const roomPath = new URL(a.url()).pathname;
  await click(b, '复盘');
  await until(async () => (await snapshot(b)).includes('第 9 / 9 手'), 'replay');
  report.recordId = new URL(b.url()).pathname.split('/').pop();
  await capture(b, 'replay-phone.png');
  await navigate(b, roomPath);
  await click(a, '再来一局');
  await click(b, '再来一局');
  await until(async () => (await snapshot(b)).includes('轮到你了'), 'color exchange');
  await click(a, '对局选项');
  await a.getByRole('menuitem', { name: '离开房间', exact: true }).click();
  await click(a, '离开房间');
  await a.waitForURL(origin + '/');
  done('Completed online record, replay, color exchange and explicit leave');

  stage = 'offline and multi-tab';
  const localContext = await browser.newContext({ viewport: { width: 900, height: 1200 }, locale: 'zh-CN', hasTouch: true });
  const local = await boot(localContext, '/local');
  await move(local, 'H8', local, '黑棋');
  const second = await boot(localContext, '/local');
  await until(async () => (await snapshot(second)).includes('H8，黑棋'), 'multi-tab database');
  await until(() => local.evaluate(() => !!navigator.serviceWorker.controller), 'offline worker', 60000);
  await localContext.setOffline(true);
  await navigate(local, '/local');
  await until(async () => (await snapshot(local)).includes('H8，黑棋'), 'offline game');
  await localContext.setOffline(false);
  done('Production Web multi-tab database and offline local game');
  assert.deepEqual(errors, []);
  report.status = 'passed';
} catch (error) {
  report.status = 'failed';
  report.failedStage = stage;
  report.errorType = error.name;
  // Do not log Playwright call arguments: they can contain a typed password.
  console.error('Private browser check failed during ' + stage + ' (' + error.name + ').');
  for (let i = 0; i < pages.length; i++) {
    await pages[i].screenshot({ path: resolve(output, `failure-${i}.png`) }).catch(() => {});
    // Flutter exposes the password value in its accessibility tree even when
    // the text field is visually obscured. Never persist that value in reports.
    let tree = await snapshot(pages[i]).catch(() => 'Page closed');
    for (const account of accounts) tree = tree.replaceAll(account.password, '[REDACTED]');
    await writeFile(resolve(output, `failure-${i}.txt`), tree);
  }
  process.exitCode = 1;
} finally {
  report.finishedAt = new Date().toISOString();
  report.network = network;
  await writeFile(resolve(output, 'results.json'), JSON.stringify(report, null, 2));
  await browser.close();
}
