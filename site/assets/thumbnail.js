// サムネイルのページ。bdf.mbt で BDF に変換し、1 ページ目を canvas に描いて、
// 切り出し・縮小した PNG を 4 つの大きさで作る。
import { bdf_create_native_converter, bdf_create_viewer } from "./browser.js";

const $ = (selector) => document.querySelector(selector);
const SAMPLES = [
  ["demo.pdf", "PDF"],
  ["basic.docx", "Word"],
  ["features.pptx", "PowerPoint"],
  ["features.xlsx", "Excel"],
  ["basic.csv", "CSV"],
  ["basic.md", "Markdown"],
  ["drawing.svg", "SVG"],
  ["stix.ttf", "フォント"],
];
const SIZES = [96, 160, 256, 480];

/** 上流 BDF の thumbnail パッケージと同じ規則: これらの形式は左上から正方形に切り出す。 */
const CROP = new Set([
  "docx", "html", "htm", "xhtml", "md", "markdown", "xlsx", "xlsm", "csv", "tsv", "tab", "parquet",
  "mml", "mid", "midi", "kar", "musicxml", "ttf", "otf", "woff", "woff2", "mp3", "m4a", "flac",
  "ogg", "opus", "wav", "aiff",
]);
const SHEET = new Set(["xlsx", "xlsm", "csv", "tsv", "tab", "parquet"]);

const status = $("#status");
const thumbs = $("#thumbs");
const file = $("#file");
const converter = bdf_create_native_converter(new URL("./native_converter_worker.js", import.meta.url).href);
let busy = false;

function say(message, error = false) {
  status.textContent = message;
  status.classList.toggle("error", error);
  if (error) status.setAttribute("data-error", "");
  else status.removeAttribute("data-error");
}

function extension(name) {
  return name.toLowerCase().replace(/^.*\./, "");
}

function modeFor(name) {
  const chosen = $("#mode").value;
  if (chosen !== "auto") return chosen;
  return CROP.has(extension(name)) ? "crop" : "fit";
}

/** BDF の 1 ページ目を描いた canvas を返す。 */
async function firstPageCanvas(bytes) {
  const host = document.createElement("div");
  // 画面の外に置く（visibility:hidden にすると canvas の中身が写らないことがある）
  host.style.cssText = "position:fixed;left:-10000px;top:0;width:1200px;height:1200px;pointer-events:none";
  document.body.append(host);
  const viewer = bdf_create_viewer(host, {
    workerUrl: new URL("./render_worker.js", import.meta.url).href,
    layout: "single",
    zoom: 1,
  });
  // 片付けるときに、間に合わなかった描画の失敗が届くことがある。表示には影響しない。
  viewer.addEventListener("error", (event) => {
    const message = String(event.detail?.message ?? event.detail ?? "");
    if (/terminated|cancel/i.test(message)) event.preventDefault();
  });
  try {
    await viewer.open({ kind: "buffer", buffer: bytes.slice().buffer });
    // 描き終わるまで待つ。ビューアを片付けると canvas の中身も消えるので、
    // そのつど写し取って、写したものに中身があるかで判断する。
    const deadline = performance.now() + 20000;
    for (;;) {
      const canvas = host.querySelector("canvas");
      if (canvas && canvas.width > 0 && canvas.height > 0) {
        const snapshot = document.createElement("canvas");
        snapshot.width = canvas.width;
        snapshot.height = canvas.height;
        snapshot.getContext("2d").drawImage(canvas, 0, 0);
        if (!isBlank(snapshot)) return { canvas: snapshot, width: snapshot.width, height: snapshot.height };
      }
      if (performance.now() > deadline) throw new Error("ページを描けませんでした");
      await new Promise((resolve) => requestAnimationFrame(resolve));
    }
  } finally {
    viewer.destroy();
    host.remove();
  }
}

/** まだ何も描かれていない canvas（真っ白）かどうか。 */
function isBlank(canvas) {
  try {
    // ページ全体を粗く見る（文字は上の方にあるとは限らない）
    const context = canvas.getContext("2d");
    const stepX = Math.max(1, Math.floor(canvas.width / 48));
    const stepY = Math.max(1, Math.floor(canvas.height / 48));
    const data = context.getImageData(0, 0, canvas.width, canvas.height).data;
    for (let y = 0; y < canvas.height; y += stepY) {
      for (let x = 0; x < canvas.width; x += stepX) {
        const at = (y * canvas.width + x) * 4;
        // まだ何も描いていない canvas は透明な黒なので、透明度で見分ける
        if (data[at + 3] <= 8) continue;
        if (data[at] < 245 || data[at + 1] < 245 || data[at + 2] < 245) return false;
      }
    }
    return true;
  } catch {
    return false;
  }
}

/** canvas の一部を target の大きさに写して PNG の Blob にする。 */
async function toPng(canvas, size, mode) {
  const target = document.createElement("canvas");
  if (mode === "crop") {
    // 上流の thumbnail と同じく、ページの幅を出力の幅に合わせてから左上の正方形を取る
    const scale = size / canvas.width;
    const sourceHeight = Math.min(canvas.height, size / scale);
    target.width = size;
    target.height = size;
    const context = target.getContext("2d");
    context.fillStyle = "#ffffff";
    context.fillRect(0, 0, size, size);
    context.drawImage(canvas, 0, 0, canvas.width, sourceHeight, 0, 0, size, sourceHeight * scale);
  } else {
    const scale = size / Math.max(canvas.width, canvas.height);
    target.width = Math.max(1, Math.round(canvas.width * scale));
    target.height = Math.max(1, Math.round(canvas.height * scale));
    const context = target.getContext("2d");
    context.fillStyle = "#ffffff";
    context.fillRect(0, 0, target.width, target.height);
    context.drawImage(canvas, 0, 0, target.width, target.height);
  }
  return new Promise((resolve, reject) => {
    target.toBlob((blob) => (blob ? resolve({ blob, width: target.width, height: target.height }) : reject(new Error("PNG にできませんでした"))), "image/png");
  });
}

async function run(name, bytes) {
  if (busy) return;
  busy = true;
  $("#open-file").disabled = true;
  for (const chip of document.querySelectorAll("#samples button")) {
    chip.disabled = true;
    chip.setAttribute("aria-disabled", "true");
  }
  thumbs.replaceChildren();
  say(name + " を変換しています…");
  try {
    let bdf = bytes;
    let summary = "";
    if (extension(name) !== "bdf") {
      await converter.ready;
      const result = await converter.convert(bytes, { name });
      bdf = result.bdf;
      summary = result.summary ? " · " + result.summary : "";
    }
    const page = await firstPageCanvas(bdf);
    const mode = modeFor(name);
    const chosen = Math.max(16, Math.min(1024, Number($("#size").value) || 256));
    const sizes = [...new Set([...SIZES, chosen])].sort((a, b) => a - b);
    for (const size of sizes) {
      const { blob, width, height } = await toPng(page.canvas, size, mode);
      const url = URL.createObjectURL(blob);
      const figure = document.createElement("figure");
      const image = document.createElement("img");
      image.src = url;
      image.width = width;
      image.height = height;
      image.alt = name + " の " + width + "×" + height + " px のサムネイル";
      const caption = document.createElement("figcaption");
      const title = document.createElement("strong");
      title.textContent = width + " × " + height + " px";
      const detail = document.createElement("span");
      detail.textContent = (mode === "crop" ? "切り出し" : "収める") + " · " + (blob.size / 1024).toFixed(1) + " KB";
      const link = document.createElement("a");
      link.href = url;
      link.download = name.replace(/\.[^.]+$/, "") + "-" + size + ".png";
      link.textContent = "PNG を保存";
      caption.append(title, detail, link);
      figure.append(image, caption);
      thumbs.append(figure);
      window.addEventListener("pagehide", () => URL.revokeObjectURL(url));
    }
    say(name + " のサムネイルを作りました" + summary + "（" + (mode === "crop" ? "切り出し" : "収める") + "）");
  } catch (error) {
    say(name + " のサムネイルを作れませんでした: " + (error.message ?? error), true);
  } finally {
    busy = false;
    $("#open-file").disabled = false;
    for (const chip of document.querySelectorAll("#samples button")) {
      chip.disabled = false;
      chip.setAttribute("aria-disabled", "false");
    }
  }
}

async function openSample(path, label) {
  try {
    const response = await fetch(new URL("./samples/" + path, import.meta.url), { cache: "no-cache" });
    if (!response.ok) throw new Error("HTTP " + response.status);
    say(label + " を読み込んでいます…");
    await run(path, new Uint8Array(await response.arrayBuffer()));
  } catch (error) {
    say(path + " を読み込めませんでした: " + (error.message ?? error), true);
  }
}

$("#samples").replaceChildren(
  ...SAMPLES.map(([path, label]) => {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = label;
    button.addEventListener("click", () => void openSample(path, path));
    return button;
  }),
);
$("#open-file").addEventListener("click", () => file.click());
file.addEventListener("change", async () => {
  const selected = file.files?.[0];
  file.value = "";
  if (selected) await run(selected.name, new Uint8Array(await selected.arrayBuffer()));
});
document.addEventListener("dragover", (event) => {
  if (![...event.dataTransfer.types].includes("Files")) return;
  event.preventDefault();
  document.body.classList.add("dragging");
});
document.addEventListener("dragleave", (event) => {
  if (event.relatedTarget) return;
  document.body.classList.remove("dragging");
});
document.addEventListener("drop", async (event) => {
  event.preventDefault();
  document.body.classList.remove("dragging");
  const dropped = event.dataTransfer.files?.[0];
  if (dropped) await run(dropped.name, new Uint8Array(await dropped.arrayBuffer()));
});
$("#mode").addEventListener("change", () => {
  if (thumbs.children.length === 0) return;
  say("作り方を変えました。もう一度ファイルを選ぶと作り直します。");
});

void openSample("basic.docx", "basic.docx");
