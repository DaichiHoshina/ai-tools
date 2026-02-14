/**
 * Playwright Visual Check for shadcn Dashboard UI
 *
 * Usage:
 *   npx playwright test playwright-visual-check.ts
 *
 * Or run directly:
 *   npx tsx playwright-visual-check.ts
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

// Target pages to capture (customize per project)
const PAGES = [
  { name: "dashboard", path: "/" },
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
        await page.goto(url, { waitUntil: "networkidle", timeout: 15000 });
      } catch {
        console.log(`Skip: ${url} (not reachable)`);
        continue;
      }

      // Wait for fonts and images to load
      await page.waitForTimeout(1000);

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

captureScreenshots().catch(console.error);
