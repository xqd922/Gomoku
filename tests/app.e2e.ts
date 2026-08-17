import AxeBuilder from '@axe-core/playwright'
import { expect, test, type Page } from '@playwright/test'

const viewports = [
  { name: 'windows', width: 1_050, height: 760 },
  { name: 'android-portrait', width: 360, height: 800 },
  { name: 'android-portrait-short', width: 360, height: 640 },
  { name: 'android-landscape', width: 640, height: 360 },
  { name: 'android-landscape-wide', width: 800, height: 360 },
]

async function cellPoint(page: Page, row: number, col: number) {
  const box = await page.locator('#board').boundingBox()
  if (!box) throw new Error('board has no layout box')
  const padding = Math.max(18, Math.min(36, box.width * 0.075))
  const cell = (box.width - padding * 2) / 14
  return {
    x: box.x + padding + col * cell,
    y: box.y + padding + row * cell,
  }
}

async function clickCell(page: Page, row: number, col: number) {
  const point = await cellPoint(page, row, col)
  await page.mouse.click(point.x, point.y)
}

async function confirmNewGame(page: Page) {
  await page.locator('#reset').click()
  await page.locator('#confirm-new-game').click()
}

test.describe('responsive application shell', () => {
  for (const viewport of viewports) {
    test(`${viewport.name} fits and exposes a nonblank board`, async ({ page }) => {
      await page.setViewportSize({ width: viewport.width, height: viewport.height })
      await page.goto('/')
      await expect(page.locator('#board')).toBeVisible()

      const metrics = await page.evaluate(() => {
        const canvas = document.querySelector<HTMLCanvasElement>('#board')!
        const pixels = canvas.getContext('2d')!.getImageData(0, 0, canvas.width, canvas.height).data
        let nonTransparent = 0
        for (let index = 0; index < pixels.length; index += 4) {
          if (pixels[index] || pixels[index + 1] || pixels[index + 2]) nonTransparent++
        }
        return {
          innerWidth,
          innerHeight,
          scrollWidth: document.documentElement.scrollWidth,
          scrollHeight: document.documentElement.scrollHeight,
          contentTop: document.querySelector<HTMLElement>('.game-layout')!.getBoundingClientRect().top,
          contentBottom: document.querySelector<HTMLElement>('.game-layout')!.getBoundingClientRect().bottom,
          canvasWidth: canvas.width,
          canvasHeight: canvas.height,
          nonTransparent,
        }
      })

      expect(metrics.scrollWidth).toBeLessThanOrEqual(metrics.innerWidth)
      expect(metrics.scrollHeight).toBeLessThanOrEqual(metrics.innerHeight)
      expect(metrics.canvasWidth).toBeGreaterThan(100)
      expect(metrics.canvasHeight).toBe(metrics.canvasWidth)
      expect(metrics.nonTransparent).toBeGreaterThan(metrics.canvasWidth * metrics.canvasHeight * 0.5)
      if (viewport.name.startsWith('android-landscape')) {
        expect(metrics.contentTop).toBeGreaterThanOrEqual(24)
        expect(metrics.contentBottom).toBeLessThanOrEqual(metrics.innerHeight - 24)
      }

      const accessibility = await new AxeBuilder({ page }).analyze()
      expect(accessibility.violations).toEqual([])
    })
  }
})

test.describe('local match workflow', () => {
  test('plays, undoes, redoes, wins, and starts a confirmed new game', async ({ page }) => {
    await page.setViewportSize({ width: 1_050, height: 760 })
    await page.goto('/')

    await clickCell(page, 7, 7)
    await expect(page.locator('#status')).toHaveText('轮到白方')
    await expect(page.locator('#last-move-label')).toHaveText('最后一手：H8')
    await expect(page.locator('#undo')).toBeEnabled()

    await page.locator('#local-mode').click()
    await expect(page.locator('#last-move-label')).toHaveText('最后一手：H8')
    await expect(page.locator('#move-count')).toHaveText('第 1 手')

    await page.locator('#undo').click()
    await expect(page.locator('#status')).toHaveText('轮到黑方')
    await expect(page.locator('#redo')).toBeEnabled()
    await page.locator('#redo').click()
    await expect(page.locator('#last-move-label')).toHaveText('最后一手：H8')

    await page.locator('#board').focus()
    await page.keyboard.press('Enter')
    await expect(page.locator('#status')).toHaveText('这个位置已有棋子')
    await confirmNewGame(page)
    await expect(page.locator('#status')).toHaveText('轮到黑方')
    await expect(page.locator('#move-count')).toHaveText('尚未落子')
    await expect(page.locator('#new-game-dialog')).not.toBeVisible()

    const black = [0, 1, 2, 3, 4]
    const white = [0, 1, 2, 3]
    for (let index = 0; index < 4; index++) {
      await clickCell(page, 7, black[index])
      await clickCell(page, 6, white[index])
    }
    await clickCell(page, 7, black[4])
    await expect(page.locator('#status')).toHaveText('黑方获胜')
    await expect(page.locator('#last-move-label')).toHaveText('最后一手：E8')
    await expect(page.locator('#undo')).toBeEnabled()

    await page.locator('#undo').click()
    await expect(page.locator('#status')).toHaveText('轮到黑方')
    await page.locator('#redo').click()
    await expect(page.locator('#status')).toHaveText('黑方获胜')
  })

  test('supports keyboard navigation', async ({ page }) => {
    await page.setViewportSize({ width: 360, height: 800 })
    await page.goto('/')
    const board = page.locator('#board')
    await board.focus()
    await page.keyboard.press('Enter')
    await expect(page.locator('#last-move-label')).toHaveText('最后一手：H8')
    await page.keyboard.press('ArrowRight')
    await page.keyboard.press('Enter')
    await expect(page.locator('#last-move-label')).toHaveText('最后一手：I8')
  })
})

test.describe('touch input', () => {
  test.use({ hasTouch: true })

  test('places stones without showing the keyboard focus treatment', async ({ page }) => {
    await page.setViewportSize({ width: 360, height: 800 })
    await page.goto('/')
    const board = page.locator('#board')

    const first = await cellPoint(page, 7, 7)
    const second = await cellPoint(page, 7, 8)
    await page.touchscreen.tap(first.x, first.y)
    await page.touchscreen.tap(second.x, second.y)

    await expect(page.locator('#last-move-label')).toHaveText('最后一手：I8')
    expect(await board.evaluate(element => element.matches(':focus-visible'))).toBe(false)
  })
})

test.describe('Android defaults', () => {
  test.use({ userAgent: 'Mozilla/5.0 (Linux; Android 16; Gomoku Test) AppleWebKit/537.36 Chrome/140 Mobile' })

  test('uses the emulator host alias for the local room server', async ({ page }) => {
    await page.goto('/')
    await page.locator('#online-mode').click()
    await expect(page.locator('#server-url')).toHaveValue('ws://10.0.2.2:8787')
  })
})

test.describe('online match workflow', () => {
  test('synchronizes two players and rejects an early move', async ({ page, context }) => {
    const secondPage = await context.newPage()
    const room = `E2E${Date.now().toString(36).slice(-8).toUpperCase()}`
    await page.setViewportSize({ width: 1_050, height: 760 })
    await page.goto('/')
    await page.locator('#online-mode').click()
    await page.locator('#room-code').fill(room)
    await page.locator('#connect').click()
    await expect(page.locator('#identity')).toHaveText('你执黑方')
    const connectionMark = page.locator('.connection-mark')
    await expect(connectionMark).toHaveClass(/connected/)
    await expect(connectionMark).toHaveClass(/waiting/)
    await expect(connectionMark).toHaveCSS('background-color', 'rgb(181, 110, 36)')

    await secondPage.setViewportSize({ width: 1_050, height: 760 })
    await secondPage.goto('/')
    await secondPage.locator('#online-mode').click()
    await secondPage.locator('#room-code').fill(room)
    await secondPage.locator('#connect').click()
    await expect(secondPage.locator('#identity')).toHaveText('你执白方')
    await expect(connectionMark).not.toHaveClass(/waiting/)
    await expect(connectionMark).toHaveCSS('background-color', 'rgb(47, 125, 87)')
    await clickCell(page, 7, 7)
    await expect(page.locator('#last-move-label')).toHaveText('最后一手：H8')
    await expect(secondPage.locator('#last-move-label')).toHaveText('最后一手：H8')
    await expect(secondPage.locator('#status')).toHaveText('轮到白方')

    await page.locator('#online-mode').click()
    await expect(page.locator('#identity')).toHaveText('你执黑方')
    await expect(page.locator('#last-move-label')).toHaveText('最后一手：H8')
    await page.locator('#room-code').press('Enter')
    await expect(page.locator('#identity')).toHaveText('你执黑方')
    await expect(page.locator('#connect')).toBeDisabled()

    await clickCell(secondPage, 7, 8)
    await expect(page.locator('#last-move-label')).toHaveText('最后一手：I8')
    await expect(page.locator('#status')).toHaveText('轮到黑方')
    await clickCell(secondPage, 7, 9)
    await expect(page.locator('#move-count')).toHaveText('第 2 手')
    await expect(secondPage.locator('#status')).toHaveText('现在是对方回合')

    const thirdPage = await context.newPage()
    await thirdPage.setViewportSize({ width: 1_050, height: 760 })
    await thirdPage.goto('/')
    await thirdPage.locator('#online-mode').click()
    await thirdPage.locator('#room-code').fill(room)
    await thirdPage.locator('#connect').click()
    await expect(thirdPage.locator('#status')).toHaveText('房间已满')
    await expect(thirdPage.locator('#connect')).toBeEnabled()
    await thirdPage.close()

    await page.locator('#disconnect').click()
    await expect(page.locator('#identity')).toHaveText('未连接房间')
    await secondPage.locator('#disconnect').click()
    await secondPage.close()
  })
})
