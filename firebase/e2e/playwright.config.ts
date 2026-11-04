import { defineConfig, devices } from "@playwright/test";

// Tests the landing page in ../site. By default it serves the folder locally; with BASE_URL it tests a deployed
// site instead (`npm run smoke` points at production). Uses the system Chrome, not a bundled browser.
const baseURL = process.env.BASE_URL ?? "http://localhost:4317";
const chrome = { ...devices["Desktop Chrome"], channel: "chrome" };

export default defineConfig({
  testDir: "tests",
  timeout: 30_000,
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? "github" : "list",
  use: { baseURL, locale: "es-ES", timezoneId: "Europe/Madrid", trace: "retain-on-failure" },
  webServer: process.env.BASE_URL
    ? undefined
    : { command: "python3 -m http.server 4317 --directory ../site", url: baseURL, reuseExistingServer: !process.env.CI },
  projects: [
    { name: "desktop", use: { ...chrome, viewport: { width: 1440, height: 900 } } },
    { name: "laptop", use: { ...chrome, viewport: { width: 1024, height: 640 } } },
    { name: "mobile", use: { ...chrome, viewport: { width: 375, height: 812 }, isMobile: true, hasTouch: true, deviceScaleFactor: 3 } },
    { name: "dark", use: { ...chrome, viewport: { width: 1440, height: 900 }, colorScheme: "dark" } },
  ],
});
