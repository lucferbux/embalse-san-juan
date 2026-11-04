import { expect, test, type Page } from "@playwright/test";
import { readFileSync } from "node:fs";

// The same fixture the backend, Swift and Kotlin tests use, served as the Firestore document the page reads.
const fixture = JSON.parse(readFileSync(new URL("../../../contract/fixtures/snapshot.json", import.meta.url), "utf8"));
const FIRESTORE = "https://firestore.googleapis.com/**";

async function serveFixture(page: Page, snapshot = fixture) {
  await page.route(FIRESTORE, (route) =>
    route.fulfill({ json: { fields: { payload: { stringValue: JSON.stringify(snapshot) } } } }),
  );
}

/** Scrolls the whole page in steps, so lazy images load and every reveal and counter runs. */
async function scrollThrough(page: Page) {
  await page.evaluate(async () => {
    document.documentElement.style.scrollBehavior = "auto";
    for (let y = 0; y < document.body.scrollHeight; y += innerHeight / 2) {
      scrollTo(0, y);
      await new Promise((resolve) => setTimeout(resolve, 60));
    }
    scrollTo(0, document.body.scrollHeight);
  });
}

/** Records page errors, console errors and failed requests to the site itself. */
function watchForProblems(page: Page) {
  const problems: string[] = [];
  page.on("pageerror", (error) => problems.push(`page error: ${error.message}`));
  page.on("console", (message) => { if (message.type() === "error") problems.push(`console: ${message.text()}`); });
  page.on("response", (response) => {
    const sameSite = new URL(response.url()).origin === new URL(page.url() || response.url()).origin;
    if (sameSite && response.status() >= 400) problems.push(`${response.status()} ${response.url()}`);
  });
  page.on("requestfailed", (request) => {
    if (!request.url().startsWith("https://firestore.googleapis.com")) problems.push(`failed: ${request.url()}`);
  });
  return problems;
}

test.describe("landing page", () => {
  test.beforeEach(async ({ page }) => serveFixture(page));

  test("loads without errors or broken requests", async ({ page }) => {
    const problems = watchForProblems(page);
    await page.goto("/");
    await expect(page).toHaveTitle("Embalse San Juan");
    await scrollThrough(page);
    await page.waitForLoadState("networkidle");
    expect(problems).toEqual([]);
  });

  test("every image loads", async ({ page }) => {
    await page.goto("/");
    await scrollThrough(page);
    await page.waitForLoadState("networkidle");
    const broken = await page.$$eval("img", (images) =>
      images.filter((image) => image.complete && image.naturalWidth === 0).map((image) => image.getAttribute("src")),
    );
    const pending = await page.$$eval("img", (images) =>
      images.filter((image) => !image.complete && image.offsetParent !== null).map((image) => image.getAttribute("src")),
    );
    expect(broken).toEqual([]);
    expect(pending).toEqual([]);
  });

  // The bug this guards against: a screenshot that ran past its phone's frame because it was positioned
  // with percentages of the frame's height. Measures layout boxes (offset*), which ignore the hero phone's
  // tilt and the tour's zoom transitions.
  test("device screens sit inside their frames, with a bezel on every side", async ({ page }) => {
    await page.goto("/");
    await scrollThrough(page);
    const frames = await page.$$eval(".iphone, .tablet, .watch, .android", (elements) =>
      elements
        .filter((frame) => frame.getClientRects().length > 0)
        .map((frame) => {
          // A box in the frame's own coordinates, whichever element positions it.
          const within = (element: HTMLElement) => {
            let left = 0, top = 0, node: HTMLElement | null = element;
            while (node && node !== frame) { left += node.offsetLeft; top += node.offsetTop; node = node.offsetParent as HTMLElement | null; }
            return { left, top, right: left + element.offsetWidth, bottom: top + element.offsetHeight };
          };
          const outer = frame as HTMLElement;
          // Frames must contain their screens' positioning, or a screenshot can escape them.
          if (getComputedStyle(frame).position === "static") return { name: `${frame.className}: not positioned`, bezel: [-1, -1, -1, -1], screen: within(outer), images: [] };
          const screen = within(frame.querySelector(".screen") as HTMLElement);
          return {
            name: `${frame.className} ${frame.querySelector("img")?.getAttribute("src")}`,
            bezel: [screen.left, screen.top, outer.offsetWidth - screen.right, outer.offsetHeight - screen.bottom],
            screen,
            images: [...frame.querySelectorAll(".screen img")].map((image) => within(image as HTMLElement)),
          };
        }),
    );
    expect(frames.length).toBeGreaterThan(3);
    for (const frame of frames) {
      for (const side of frame.bezel) expect(side, `${frame.name}: bezel ${frame.bezel.join(", ")}`).toBeGreaterThan(2);
      for (const image of frame.images) {
        expect(image.left, frame.name).toBeGreaterThanOrEqual(frame.screen.left);
        expect(image.top, frame.name).toBeGreaterThanOrEqual(frame.screen.top);
        expect(image.right, frame.name).toBeLessThanOrEqual(frame.screen.right);
        expect(image.bottom, frame.name).toBeLessThanOrEqual(frame.screen.bottom);
      }
    }
  });

  test("screenshots and widgets keep their proportions", async ({ page }) => {
    await page.goto("/");
    await scrollThrough(page);
    await page.waitForLoadState("networkidle");
    const distorted = await page.$$eval(".screen, .widget", (elements) =>
      elements
        .filter((element) => element.getClientRects().length > 0)
        .map((element) => {
          const image = (element.tagName === "IMG" ? element : element.querySelector("img")) as HTMLImageElement;
          const box = element as HTMLElement;
          return { src: image.getAttribute("src"), shown: box.offsetWidth / box.offsetHeight, natural: image.naturalWidth / image.naturalHeight };
        })
        .filter(({ shown, natural }) => Math.abs(shown / natural - 1) > 0.03),
    );
    expect(distorted).toEqual([]);
  });

  test("shows the live figures from Firestore", async ({ page }) => {
    await page.goto("/");
    await expect(page.locator("html")).toHaveAttribute("data-live", "ok");
    await expect(page.locator("#percent")).toHaveText("48,7");
    await expect(page.locator("#volume")).toHaveText("67,0 hm³ de 138 hm³");
    await expect(page.locator("#trend")).toHaveText("Subiendo");
    await expect(page.locator("#trend-detail")).toHaveText("+0,12 hm³ en 24 h");
    await expect(page.locator("#updated")).toContainText("SAIH Tajo, 30 oct");

    await page.locator("#bars").scrollIntoViewIfNeeded();
    await expect(page.locator('[data-label="volumeHm3"]')).toHaveText("70 hm³");
    await expect(page.locator('[data-label="lastYearHm3"]')).toHaveText("75 hm³");
    await expect(page.locator('[data-label="tenYearAvgHm3"]')).toHaveText("57,5 hm³");
    await expect(page.locator(".fill.now")).toHaveCSS("width", /^[1-9]/);
  });

  test("the hero's water follows the reservoir's level", async ({ page }) => {
    await serveFixture(page, { ...fixture, live: { ...fixture.live, percent: 90 } });
    await page.goto("/");
    await expect(page.locator("html")).toHaveAttribute("data-live", "ok");
    await expect(page.locator("#water")).toHaveAttribute("style", /height: 37%/);
  });

  test("keeps working when Firestore is down", async ({ page }) => {
    await page.unroute(FIRESTORE);
    await page.route(FIRESTORE, (route) => route.abort());
    const problems = watchForProblems(page);
    await page.goto("/");
    await expect(page.locator("html")).toHaveAttribute("data-live", "fallback");
    await expect(page.locator("#percent")).toHaveText("48,5");
    // The browser logs the blocked request itself; anything else is a problem.
    expect(problems.filter((problem) => !problem.includes("firestore") && !problem.includes("net::ERR_FAILED"))).toEqual([]);
  });

  test("never scrolls sideways", async ({ page }) => {
    await page.goto("/");
    await scrollThrough(page);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - innerWidth);
    expect(overflow).toBeLessThanOrEqual(0);
  });

  test("the tour swaps the phone's screen as the steps scroll past", async ({ page }, testInfo) => {
    test.skip(testInfo.project.name === "mobile", "Narrow screens show one phone per step instead.");
    await page.goto("/");
    await page.evaluate(() => { document.documentElement.style.scrollBehavior = "auto"; });
    for (const step of ["0", "1", "2", "3"]) {
      await page.locator(`.step[data-step="${step}"] h2`).evaluate((heading) => heading.scrollIntoView({ block: "center" }));
      await expect(page.locator(".story")).toHaveAttribute("data-active", step);
      await expect(page.locator(`.shot[data-step="${step}"]`)).toHaveClass(/active/);
      await expect(page.locator(".shot.active")).toHaveCount(1);
    }
  });

  test("on narrow screens each step brings its own phone", async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== "mobile", "Only narrow screens.");
    await page.goto("/");
    await expect(page.locator(".story-visual")).toBeHidden();
    for (const phone of await page.locator(".step-phone").all()) await expect(phone).toBeAttached();
    await page.locator(".step-phone").first().scrollIntoViewIfNeeded();
    await expect(page.locator(".step-phone").first()).toBeVisible();
  });

  test("with reduced motion, everything is visible without scrolling", async ({ page }) => {
    await page.emulateMedia({ reducedMotion: "reduce" });
    await page.goto("/");
    const hidden = await page.$$eval(".reveal", (elements) => elements.filter((element) => getComputedStyle(element).opacity !== "1").length);
    expect(hidden).toBe(0);
  });

  test("links lead somewhere real", async ({ page, request }) => {
    await page.goto("/");
    await expect(page.locator('a[data-store="apple"]').first()).toHaveAttribute("href", "https://apps.apple.com/es/app/embalse-san-juan/id6828988892");
    for (const href of ["privacy.html", "support.html"]) {
      const response = await request.get(href);
      expect(response.status(), href).toBe(200);
    }
    const anchors = await page.$$eval('a[href^="#"]', (links) => links.map((link) => link.getAttribute("href")!).filter((href) => href.length > 1));
    for (const anchor of anchors) await expect(page.locator(anchor), anchor).toHaveCount(1);
  });
});

test.describe("other pages", () => {
  for (const path of ["privacy.html", "support.html"]) {
    test(`${path} loads`, async ({ page }) => {
      const problems = watchForProblems(page);
      await page.goto(path);
      await expect(page.locator("h1")).toBeVisible();
      expect(problems).toEqual([]);
    });
  }
});

// Only against a deployed site: the real Firestore document, unmocked.
test("live: the deployed page shows today's figure", async ({ page }, testInfo) => {
  test.skip(!process.env.BASE_URL || testInfo.project.name !== "desktop", "Runs once, with BASE_URL.");
  await page.goto("/");
  await expect(page.locator("html")).toHaveAttribute("data-live", "ok", { timeout: 15_000 });
  await expect(page.locator("#updated")).toContainText("SAIH Tajo,");
  await expect.poll(async () => Number((await page.locator("#percent").textContent())!.replace(",", "."))).toBeGreaterThan(0);
  const percent = Number((await page.locator("#percent").textContent())!.replace(",", "."));
  expect(percent).toBeLessThanOrEqual(100);
});

// Only against a deployed site. The page and its CSS and JS must be revalidated on every visit: with Firebase's
// default hour of caching, a returning visitor got the new HTML with the old stylesheet right after a deploy.
test("live: pages, styles and scripts are never served stale", async ({ request }, testInfo) => {
  test.skip(!process.env.BASE_URL || testInfo.project.name !== "desktop", "Runs once, with BASE_URL.");
  for (const path of ["/", "/landing.css", "/landing.js", "/privacy.html"]) {
    const response = await request.get(path);
    expect(response.headers()["cache-control"], path).toBe("no-cache");
  }
});
