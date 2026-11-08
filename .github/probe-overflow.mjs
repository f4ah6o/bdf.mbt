// 375px 幅で、文書の横スクロールを起こす要素を一覧する。
//
//   node .github/probe-overflow.mjs <url>...
//
// vlmkit の page-overflow は原因の要素を絞り切らないので、CI の失敗を
// 誰でも読める幅にするための補助。
import { chromium } from "playwright";

const base = process.argv[2] ?? "http://127.0.0.1:8771/";
const paths = process.argv.slice(3).length ? process.argv.slice(3) : ["", "viewer/", "thumbnail/", "text/", "wasm-gc.html", "docs/index.html"];
const browser = await chromium.launch({ headless: true });
let failures = 0;
try {
  const page = await browser.newPage({ viewport: { width: 375, height: 812 } });
  for (const path of paths) {
    await page.goto(base + path, { waitUntil: "domcontentloaded" });
    await page.waitForTimeout(1500);
    const report = await page.evaluate(() => {
      const widest = document.documentElement.scrollWidth;
      const offenders = [];
      for (const element of document.querySelectorAll("*")) {
        const box = element.getBoundingClientRect();
        if (box.right > 376 && box.width > 0) {
          const style = getComputedStyle(element);
          offenders.push({
            selector: element.tagName.toLowerCase() +
              (element.id ? "#" + element.id : "") +
              (element.className && typeof element.className === "string" ? "." + element.className.trim().split(/\s+/).join(".") : ""),
            right: Math.round(box.right),
            width: Math.round(box.width),
            position: style.position,
            overflowX: style.overflowX,
          });
        }
      }
      offenders.sort((left, right) => right.right - left.right);
      return { scrollWidth: widest, clientWidth: document.documentElement.clientWidth, offenders: offenders.slice(0, 8) };
    });
    const overflow = report.scrollWidth - report.clientWidth;
    console.log((path || "/") + " : " + (overflow > 0 ? "OVERFLOW +" + overflow + "px (scrollWidth " + report.scrollWidth + ")" : "clean"));
    for (const offender of report.offenders) {
      console.log("  " + JSON.stringify(offender));
    }
    if (overflow > 0) failures += 1;
  }
} finally {
  await browser.close();
}
process.exit(failures ? 1 : 0);
