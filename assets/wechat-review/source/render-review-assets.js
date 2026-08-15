const path = require("path");
const { pathToFileURL } = require("url");
const playwrightRoot = process.env.REVIEW_NODE_MODULES;
if (!playwrightRoot) {
  throw new Error("Set REVIEW_NODE_MODULES to the bundled node_modules path.");
}
const { chromium } = require(path.join(playwrightRoot, "playwright"));

const sourceDir = __dirname;
const outputDir = path.resolve(sourceDir, "..");
const browserExecutable = process.env.BROWSER_EXECUTABLE ||
  "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe";

const files = [
  "focus-flow-app-operation-flow",
  "focus-flow-wechat-login-flow",
];

(async () => {
  const browser = await chromium.launch({
    headless: true,
    executablePath: browserExecutable,
    args: ["--disable-gpu", "--disable-software-rasterizer"],
  });

  try {
    for (const name of files) {
      const page = await browser.newPage({
        viewport: { width: 1600, height: 1200 },
        deviceScaleFactor: 1,
      });
      await page.goto(pathToFileURL(path.join(sourceDir, `${name}.html`)).href);
      await page.screenshot({
        path: path.join(outputDir, `${name}.png`),
        fullPage: false,
      });
      await page.close();
    }
  } finally {
    await browser.close();
  }
})();
