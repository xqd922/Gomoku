import assert from "node:assert/strict";
import { mkdir, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { resolve } from "node:path";
import { chromium } from "playwright";

const base = process.env.GOMOKU_WEB_URL || "http://localhost:4280";
const output = resolve(import.meta.dirname, "../../artifacts/browser");
await mkdir(output, { recursive: true });
const chrome = process.env.GOMOKU_CHROME_PATH ||
  (process.platform === "win32" ? "C:/Program Files/Google/Chrome/Application/chrome.exe" : undefined);
const browser = await chromium.launch({
  headless: true,
  ...(chrome && existsSync(chrome) ? { executablePath: chrome } : {}),
});
const pages = [];
const errors = [];
const results = [];
function passed(description) {
  results.push(description);
  console.log("PASS: " + description);
}
async function until(check, reason = "Condition timed out", timeout = 20000) {
  const end = Date.now() + timeout;
  while (!await check()) {
    if (Date.now() > end) throw new Error(reason);
    await new Promise(resolve => setTimeout(resolve, 100));
  }
}
async function boot(context, route = "/") {
  const page = await context.newPage();
  page.setDefaultTimeout(15000);
  page.on("pageerror", error => errors.push(error.message));
  pages.push(page);
  await navigate(page, route);
  return page;
}
async function navigate(page, route) {
  await page.goto(base + route, { waitUntil: "domcontentloaded" });
  await page.waitForSelector("flutter-view");
  const placeholder = page.locator("flt-semantics-placeholder");
  if (await placeholder.count()) await placeholder.evaluate(element => element.click());
  await until(() => page.locator("flt-semantics-host").evaluate(e => e.childElementCount > 0),
    "Flutter semantics did not initialize");
}
async function enabled(page, label) {
  const button = page.getByRole("button", { name: label, exact: true });
  await until(() => button.isEnabled().catch(() => false), label + " did not become enabled");
  return button;
}
async function stone(page, point, expected) {
  await until(async () => (await page.locator("body").ariaSnapshot()).includes(point + "，" + expected),
    "Board did not update at " + point);
}
async function move(page, point, other, color) {
  await page.mouse.move(400, 300);
  await page.mouse.wheel(0, -2000);
  await page.getByRole("button", { name: point + "，空位", exact: true }).click();
  await (await enabled(page, "确认落子")).click();
  await stone(other, point, color);
}
async function emailCode(email) {
  let code;
  await until(async () => {
    const search = await fetch("http://127.0.0.1:8025/api/v1/search?query=" + encodeURIComponent("to:" + email)).then(r => r.json());
    if (!search.messages?.length) return false;
    const message = await fetch("http://127.0.0.1:8025/api/v1/message/" + search.messages[0].ID).then(r => r.json());
    code = message.Text.match(/code:\s+([A-Za-z0-9]+)/)?.[1];
    return !!code;
  }, "Mailpit verification mail did not arrive");
  return code;
}

async function enterPassword(page, password) {
  await page.getByRole("textbox", { name: "密码", exact: true }).click();
  await page.locator('input[type="password"]').fill(password);
  await page.locator('input[type="password"]').press("Tab");
}

async function fillText(page, label, value) {
  const field = page.getByRole("textbox", { name: label, exact: true });
  await field.click();
  await field.fill(value);
  await field.press("Tab");
}

async function clickReplayControl(page, label) {
  // Flutter's transparent semantics overlays do not follow DOM hit testing.
  // Send a real pointer event to the visible control and assert the game below.
  const button = await enabled(page, label);
  const bounds = await button.boundingBox();
  assert.ok(bounds && bounds.width > 0 && bounds.height > 0);
  await page.mouse.click(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2);
}

try {
  await until(async () => {
    try { return (await fetch(base + "/health")).ok; } catch { return false; }
  }, "The application server is not ready", 90000);
  const desktop = await browser.newContext({ viewport: { width: 1440, height: 1000 }, locale: "zh-CN" });
  const a = await boot(desktop);
  assert.equal(await a.evaluate(() => crossOriginIsolated), true);
  await a.getByRole("button", { name: /^与朋友对弈 / }).waitFor();
  await a.screenshot({ path: output + "/home-desktop.png" });
  await a.getByRole("button", { name: /^与朋友对弈 / }).click();
  await fillText(a, "怎么称呼你", "小紫");
  await a.getByRole("button", { name: "创建房间", exact: true }).click();
  await a.waitForURL("**/room/**");
  await enabled(a, "准备好了");
  const body = await a.locator("body").ariaSnapshot();
  const code = body.match(/第 1 局 · ([A-Z2-9]{6})/)?.[1];
  assert.ok(code, "Room code must be displayed");
  const cookies = await desktop.cookies();
  const session = cookies.find(c => c.name === "gomoku_session");
  assert.ok(session?.httpOnly);
  assert.equal(session.sameSite, "Lax");
  assert.equal(await a.evaluate(() => document.cookie.includes("gomoku_session")), false);
  passed("Web HttpOnly authentication and same-origin streaming");

  const phone = await browser.newContext({ viewport: { width: 390, height: 844 }, locale: "zh-CN", hasTouch: true, isMobile: true });
  const b = await boot(phone, "/join/" + code);
  await fillText(b, "怎么称呼你", "小白");
  await b.getByRole("button", { name: "加入", exact: true }).click();
  await b.waitForURL("**/room/**");
  await enabled(b, "准备好了");
  await until(async () => (await a.locator("body").ariaSnapshot()).includes("小白"), "Guest seat was not broadcast");
  await (await enabled(a, "准备好了")).click();
  await (await enabled(b, "准备好了")).click();
  await a.getByRole("group", { name: "五子棋棋盘", exact: true }).waitFor();
  await b.getByRole("group", { name: "五子棋棋盘", exact: true }).waitFor();
  await move(a, "H8", b, "黑棋");
  await move(b, "H9", a, "白棋");
  await move(a, "I8", b, "黑棋");
  await (await enabled(a, "申请悔棋")).click();
  await (await enabled(b, "同意")).click();
  await a.getByRole("button", { name: "I8，空位", exact: true }).waitFor();
  await move(a, "I8", b, "黑棋");
  await move(b, "I9", a, "白棋");
  await a.screenshot({ path: output + "/game-desktop.png" });
  await b.mouse.wheel(0, -2000);
  await b.screenshot({ path: output + "/game-phone.png" });
  await move(a, "J8", b, "黑棋");
  await move(b, "J9", a, "白棋");
  await move(a, "K8", b, "黑棋");
  await move(b, "K9", a, "白棋");
  await move(a, "L8", b, "黑棋");
  await until(async () => (await b.locator("body").ariaSnapshot()).includes("黑棋获胜"), "Win not broadcast");
  passed("Desktop and touch-phone complete game, consented undo, winning line");
  await navigate(a, "/history");
  await a.getByRole("button", { name: /黑棋获胜/ }).first().waitFor();
  await a.getByRole("button", { name: /黑棋获胜/ }).first().click();
  await clickReplayControl(a, "回到开局");
  await until(async () => (await a.locator("body").ariaSnapshot()).includes("第 0 / 9 手"), "Replay did not return to the initial position");
  await clickReplayControl(a, "下一步");
  await until(async () => (await a.locator("body").ariaSnapshot()).includes("第 1 / 9 手"), "Replay did not advance one move");
  await stone(a, "H8", "黑棋");
  passed("Persisted online game and step-by-step replay");

  await navigate(a, "/account");
  await a.getByRole("checkbox", { name: "注册账户", exact: true }).click();
  const email = "browser-" + Date.now() + "@example.test";
  const password = "Browser-Test!937";
  await fillText(a, "邮箱地址", email);
  await a.getByRole("button", { name: "发送验证码", exact: true }).click();
  await fillText(a, "邮件验证码", await emailCode(email));
  await enterPassword(a, password);
  await fillText(a, "怎么称呼你", "星紫");
  await a.getByRole("button", { name: "完成注册", exact: true }).click();
  await a.getByRole("button", { name: "退出登录", exact: true }).waitFor();
  const otherDevice = await browser.newContext({ viewport: { width: 1024, height: 900 }, locale: "zh-CN" });
  const cloud = await boot(otherDevice, "/account");
  await fillText(cloud, "邮箱地址", email);
  await enterPassword(cloud, password);
  await cloud.getByRole("button", { name: "登录", exact: true }).last().click();
  await cloud.getByRole("button", { name: "退出登录", exact: true }).waitFor();
  await cloud.getByRole("button", { name: "星紫", exact: true }).waitFor();
  await navigate(cloud, "/history");
  await cloud.getByRole("button", { name: /黑棋获胜/ }).first().waitFor();
  passed("Mailpit registration, guest claim, login on a second device, cloud history");

  const localContext = await browser.newContext({ viewport: { width: 900, height: 1100 }, locale: "en-US" });
  const localA = await boot(localContext, "/local");
  await localA.getByRole("group", { name: "Gomoku board", exact: true }).waitFor();
  const localB = await boot(localContext, "/local");
  await localB.getByRole("group", { name: "Gomoku board", exact: true }).waitFor();
  await localA.getByRole("button", { name: "H8, Empty", exact: true }).click();
  await (await enabled(localA, "Place stone")).click();
  await until(async () => (await localB.locator("body").ariaSnapshot()).includes("H8, Black"), "Multi-tab database did not deliver the saved move");
  await localB.getByRole("button", { name: "I8, Empty", exact: true }).click();
  await (await enabled(localB, "Place stone")).click();
  await until(async () => (await localA.locator("body").ariaSnapshot()).includes("I8, White"), "Second tab overwrote the position");
  await until(() => localA.evaluate(() => !!navigator.serviceWorker.controller), "Offline cache is not installed", 60000);
  await localContext.setOffline(true);
  await navigate(localA, "/local");
  await until(async () => (await localA.locator("body").ariaSnapshot()).includes("I8, White"), "Offline reload lost the game");
  await localContext.setOffline(false);
  passed("Drift multi-tab updates and offline reload with preserved game");

  await navigate(cloud, "/settings");
  await cloud.getByRole("checkbox", { name: "深色", exact: true }).click();
  await cloud.screenshot({ path: output + "/settings-dark.png" });
  await cloud.getByRole("checkbox", { name: "English", exact: true }).click();
  await until(async () => (await cloud.locator("body").ariaSnapshot()).includes("Make yourself at home."), "English setting did not apply");
  await cloud.setViewportSize({ width: 844, height: 390 });
  await cloud.screenshot({ path: output + "/settings-landscape.png" });
  passed("Dark theme, English locale, tablet and landscape adaptation");
  assert.deepEqual(errors, [], "Unexpected browser runtime exceptions");
  await writeFile(output + "/results.json", JSON.stringify({ passed: results, runtimeErrors: errors, recordedAt: new Date().toISOString() }, null, 2));
  console.log("All browser scenarios passed without runtime exceptions.");
} catch (error) {
  for (let i = 0; i < pages.length; i++) {
    if (pages[i].isClosed()) continue;
    await pages[i].screenshot({ path: output + "/failure-" + i + ".png" }).catch(() => {});
    await writeFile(output + "/failure-" + i + ".txt", await pages[i].locator("body").ariaSnapshot().catch(() => "Page closed")).catch(() => {});
  }
  console.error(error);
  console.error("Runtime exceptions:", errors);
  process.exitCode = 1;
} finally {
  await browser.close();
}
