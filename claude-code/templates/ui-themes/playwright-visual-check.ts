/**
 * Playwright Visual Check for Dashboard UI
 *
 * Usage (recommended):
 *   npx tsx ~/.claude/templates/ui-themes/playwright-visual-check.ts
 *
 * Or as Playwright test:
 *   npx playwright test playwright-visual-check.ts
 *
 * Custom port:
 *   BASE_URL=http://localhost:5173 npx tsx playwright-visual-check.ts
 *
 * Prerequisites:
 *   npx playwright install chromium
 *
 * This script captures full-page screenshots at multiple viewports
 * for visual evaluation by Claude (multimodal).
 */

import { chromium, type Browser, type Page } from "playwright";

const SCREENSHOTS_DIR = "/tmp/ui-visual-check";
const BASE_URL = process.env.BASE_URL || "http://localhost:3000";

const PAGE_LOAD_TIMEOUT_MS = 15000;
const FONT_LOAD_WAIT_MS = 1000;

// Target pages to capture (customize per project)
const PAGES = [
  { name: "home", path: "/" },
  { name: "dashboard", path: "/dashboard" },
];

// Viewports to test
const VIEWPORTS = [
  { name: "desktop", width: 1440, height: 900 },
  { name: "laptop", width: 1280, height: 800 },
  { name: "tablet", width: 768, height: 1024 },
];

async function captureScreenshots() {
  const browser: Browser = await chromium.launch();

  for (const viewport of VIEWPORTS) {
    const page: Page = await browser.newPage({
      viewport: { width: viewport.width, height: viewport.height },
    });

    for (const target of PAGES) {
      const url = `${BASE_URL}${target.path}`;

      try {
        await page.goto(url, {
          waitUntil: "networkidle",
          timeout: PAGE_LOAD_TIMEOUT_MS,
        });
      } catch (error: unknown) {
        const message =
          error instanceof Error ? error.message : "Unknown error";
        console.log(`Skip: ${url} (${message})`);
        continue;
      }

      // Wait for fonts and images to load
      await page.waitForTimeout(FONT_LOAD_WAIT_MS);

      const filename = `${SCREENSHOTS_DIR}/${target.name}-${viewport.name}.png`;
      await page.screenshot({
        path: filename,
        fullPage: true,
      });

      console.log(`Captured: ${filename}`);
    }

    await page.close();
  }

  await browser.close();
  console.log(`\nAll screenshots saved to: ${SCREENSHOTS_DIR}/`);
  console.log("Use Claude's Read tool to evaluate the screenshots.");
}

captureScreenshots().catch((error: unknown) => {
  console.error(
    "Screenshot capture failed:",
    error instanceof Error ? error.message : error,
  );
  process.exit(1);
});
