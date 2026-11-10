// ビューアのページ。bdf.mbt のビューアと変換 Worker をつなぎ、
// 開いた BDF を wasm-gc の書き出し（PDF・Markdown・検索テキスト）に渡す。
import { bdf_create_native_converter, bdf_create_viewer } from "./browser.js";
import { createExportUI } from "./export-ui.js";
import { createLocalFontsUI } from "./local-fonts.js";

const $ = (selector) => document.querySelector(selector);
const SAMPLES = [
  ["demo.pdf", "PDF（20 ページ）"],
  ["reportlab-master.pdf", "ReportLab"],
  ["chrome-doc.pdf", "Chrome 文書"],
  ["chrome-slides.pdf", "Chrome スライド"],
  ["chrome-masks.pdf", "マスク"],
  ["cjk-cmaps.pdf", "CJK の CMap"],
  ["weasyprint-webfonts.pdf", "Web フォント"],
  ["images-jpx-jbig2.pdf", "JPX・JBIG2"],
  ["cairo-cff.pdf", "CFF"],
  ["cairo-type1.pdf", "Type1"],
  ["pdf-encrypted.pdf", "暗号化 PDF（demo）"],
  ["basic.docx", "Word"],
  ["basic.pptx", "PowerPoint"],
  ["features.pptx", "PowerPoint（機能）"],
  ["basic.xlsx", "Excel"],
  ["features.xlsx", "Excel（機能）"],
  ["basic.csv", "CSV"],
  ["basic.parquet", "Parquet"],
  ["nested.parquet", "Parquet（入れ子）"],
  ["basic.md", "Markdown"],
  ["drawing.svg", "SVG"],
  ["labels.drawio", "draw.io"],
  ["demo.xdw", "DocuWorks"],
  ["aws.drawio", "draw.io（AWS）"],
  ["multipage.drawio", "draw.io（複数ページ）"],
  ["shapes.dxf", "DXF"],
  ["layout.dxf", "DXF（レイアウト）"],
  ["hpgl1.plt", "HP-GL/2"],
  ["old.jww", "Jw_cad"],
  ["shapes.sfc", "SXF"],
  ["shapes.cgm", "CGM"],
  ["synced.mp3", "音声（同期歌詞つき MP3）"],
  ["stix.ttf", "フォント"],
];

const file = $("#file");
const status = $("#status");
const view = $("#view");
const pageNumber = $("#page-number");
const download = $("#download");
const pdfPassword = $("#pdf-password");
const pdfRetry = $("#pdf-retry");
const pdfUnlockStatus = $("#pdf-unlock-status");
const converter = bdf_create_native_converter(
  new URL("./native_converter_worker.js", import.meta.url).href,
);
const viewer = bdf_create_viewer($("#preview"), {
  workerUrl: new URL("./render_worker.js", import.meta.url).href,
  layout: "single",
});
// ローカルフォントは、利用者が選んだときだけ読む。選択が無ければ
// これまでどおり options.fonts も fontFiles も付けない。
// 古い HTML がキャッシュされていて置き場所が無いときも、変換は止めない。
const localFontsRoot = $("#local-fonts");
const localFonts = localFontsRoot
  ? createLocalFontsUI({ root: localFontsRoot })
  : { getFontFiles: () => null, clear: () => {} };
const localFontsAnchor = document.createComment("local-fonts");
localFontsRoot?.parentNode?.insertBefore(localFontsAnchor, localFontsRoot);
let firstChoiceDone = false;
let firstChoice = null;

// 最初の「自分のファイル」を表示する前に一度だけ聞く。組み込みのデモや
// 同じページでの 2 回目以降は聞かない。queryLocalFonts はこの中の
// ボタン（直接の操作）からしか呼ばない。
function askFirstFontChoice() {
  if (!localFontsRoot || firstChoiceDone) return Promise.resolve(true);
  // 開いている間の選択は同じ Promise を待つ。完了は閉じたときだけ。
  if (firstChoice) return firstChoice;
  firstChoice = new Promise((resolve) => {
    let settled = false;
    const dialog = document.createElement("dialog");
    dialog.className = "first-font-choice";
    dialog.setAttribute("aria-labelledby", "first-font-choice-title");
    const title = document.createElement("h2");
    title.id = "first-font-choice-title";
    title.textContent = "最初の表示にローカルフォントを使いますか？";
    const note = document.createElement("p");
    note.className = "note";
    note.textContent = "この端末の書体を選べます。選ばなくても、これまでどおり変換できます。";
    const host = document.createElement("div");
    host.className = "first-font-choice-picker";
    host.append(localFontsRoot);
    const actions = document.createElement("div");
    actions.className = "first-font-choice-actions";
    const skip = document.createElement("button");
    skip.type = "button";
    skip.className = "button";
    skip.textContent = "フォントなしで続ける";
    const use = document.createElement("button");
    use.type = "button";
    use.className = "button primary";
    use.textContent = "この設定で続ける";
    actions.append(skip, use);
    dialog.append(title, note, host, actions);
    document.body.append(dialog);
    const finish = (withFonts) => {
      if (settled) return;
      settled = true;
      dialog.close();
      dialog.remove();
      if (localFontsAnchor.parentNode) {
        localFontsAnchor.parentNode.insertBefore(localFontsRoot, localFontsAnchor.nextSibling);
      }
      firstChoiceDone = true;
      resolve(withFonts);
    };
    skip.addEventListener("click", () => finish(false));
    use.addEventListener("click", () => finish(true));
    dialog.addEventListener("cancel", (event) => {
      event.preventDefault();
      finish(false);
    });
    // close() がボタン以外（Escape の既定動作や外からの close）でも必ず解決する。
    dialog.addEventListener("close", () => finish(false));
    try {
      dialog.showModal();
    } catch {
      // モーダルを開けない環境でも、選択済みの書体で変換を続ける。
      dialog.remove();
      if (localFontsAnchor.parentNode) {
        localFontsAnchor.parentNode.insertBefore(localFontsRoot, localFontsAnchor.nextSibling);
      }
      firstChoiceDone = true;
      resolve(true);
      return;
    }
    localFontsRoot.querySelector("button")?.focus();
  });
  return firstChoice;
}

let currentPage = 0;
let downloadUrl = null;
let busy = false;
let selection = 0;
let scrollFrame = 0;
let lastOpen = null;
let openDocument = null;

function say(message, error = false) {
  status.textContent = message;
  status.classList.toggle("error", error);
}

function setBusy(value) {
  busy = value;
  file.disabled = value;
  $("#open-file").disabled = value;
  if (pdfPassword) pdfPassword.disabled = value;
  if (pdfRetry) pdfRetry.disabled = value || !lastOpen;
  for (const chip of document.querySelectorAll("#samples button")) {
    chip.disabled = value;
    chip.setAttribute("aria-disabled", String(value));
  }
  view.disabled = value || !viewer.document;
}

function pageCount() {
  return viewer.view?.pages?.length ?? 0;
}

function updatePage() {
  const count = pageCount();
  currentPage = Math.max(0, Math.min(currentPage, Math.max(0, count - 1)));
  pageNumber.textContent = count ? currentPage + 1 + " / " + count : "–";
  $("#previous").disabled = busy || count === 0 || currentPage === 0;
  $("#next").disabled = busy || count === 0 || currentPage + 1 >= count;
}

function setDownload(bytes, name) {
  if (downloadUrl) URL.revokeObjectURL(downloadUrl);
  downloadUrl = URL.createObjectURL(new Blob([bytes], { type: "application/octet-stream" }));
  download.href = downloadUrl;
  download.download = name.replace(/\.[^.]+$/, "") + ".bdf";
  download.hidden = false;
}

function showViews(manifest) {
  view.replaceChildren(
    ...manifest.views.map((item) => {
      const option = document.createElement("option");
      option.value = item.id;
      option.textContent = item.title || item.id;
      return option;
    }),
  );
  view.value = viewer.view?.id ?? manifest.views[0]?.id ?? "";
  currentPage = 0;
  updatePage();
}

// 選択した書体を使えない拡張子には fontFiles を送らない。直接 API は
// 明示的に渡された fontFiles を検証するが、ビューアはファイル名で判断できる。
const FONT_FREE_EXTENSIONS = [".pdf", ".docx", ".docm", ".dotx", ".dotm"];
function sendsSelectedFonts(name) {
  const lower = name.toLowerCase();
  return !FONT_FREE_EXTENSIONS.some((extension) => lower.endsWith(extension));
}

async function openBytes(name, input, retry = false, useFonts = true) {
  if (busy) return;
  if (!retry) {
    lastOpen = null;
    if (pdfRetry) pdfRetry.disabled = true;
    if (pdfUnlockStatus) {
      const typed = pdfPassword?.value ?? "";
      pdfUnlockStatus.textContent = typed
        ? "パスワード " + typed + " を使って変換します。"
        : "暗号化 PDF はここに入力してください。サンプルのパスワードは demo です。";
      pdfUnlockStatus.classList.remove("error");
    }
  }
  setBusy(true);
  updatePage();
  say(name + " を開いています…");
  const isPdf = name.toLowerCase().endsWith(".pdf");
  let usedFonts = null;
  try {
    let bytes = input;
    let summary = "";
    let warnings = [];
    if (!name.toLowerCase().endsWith(".bdf")) {
      await converter.ready;
      const options = { name };
      const password = isPdf && pdfPassword ? pdfPassword.value : "";
      if (password) options.params = { password };
      // 選択した書体だけを渡す。options.fonts（URL）とは併用しない。
      const fontFiles = useFonts && sendsSelectedFonts(name) ? localFonts.getFontFiles() : null;
      if (fontFiles) {
        options.fontFiles = fontFiles;
        usedFonts = fontFiles;
      }
      const result = await converter.convert(input, options);
      bytes = result.bdf;
      summary = result.summary ?? "";
      warnings = result.warnings ?? [];
    }
    const manifest = await viewer.open({ kind: "buffer", buffer: bytes.slice().buffer });
    viewer.stage.scrollTop = 0;
    viewer.stage.scrollLeft = 0;
    $("#document-name").textContent = name;
    $("#document-meta").textContent = summary;
    $("#search").value = "";
    $("#search-status").textContent = "";
    showViews(manifest);
    setDownload(bytes, name);
    openDocument = { name, bytes: bytes.slice() };
    document.dispatchEvent(new CustomEvent("bdf:document", { detail: { name } }));
    say(
      (warnings.length ? "表示しました（警告: " + warnings.join(" · ") + "）" : name + " を表示しています。") +
        (usedFonts
          ? " 選択したローカルフォント " + usedFonts.length + " 書体を変換に渡しました。書き出した PDF などに埋め込まれることがあります。"
          : ""),
    );
    if (isPdf) {
      lastOpen = null;
      if (pdfRetry) pdfRetry.disabled = true;
      if (pdfPassword) pdfPassword.value = "";
      if (pdfUnlockStatus) {
        pdfUnlockStatus.textContent = "PDF を開きました。";
        pdfUnlockStatus.classList.remove("error");
      }
    }
  } catch (error) {
    const message = String(error.message ?? error);
    if (isPdf && /password|encrypted/i.test(message)) {
      lastOpen = { name, input, useFonts };
      if (pdfRetry) pdfRetry.disabled = false;
      if (pdfPassword) pdfPassword.focus();
      if (pdfUnlockStatus) {
        pdfUnlockStatus.textContent = retry && /incorrect|wrong/i.test(message)
          ? "パスワードが正しくありません。確認して再変換してください。"
          : "この PDF は暗号化されています。パスワードを入力して再変換してください。";
        pdfUnlockStatus.classList.add("error");
      }
      say(pdfUnlockStatus?.textContent ?? "PDF のパスワードを入力してください。", true);
    } else {
      say(name + " を開けませんでした: " + message, true);
    }
  } finally {
    setBusy(false);
    updatePage();
  }
}

async function openSample(path, name, password = "") {
  const token = ++selection;
  // 開いている途中のクリックは捨てずに、終わるまで待ってから開く
  for (let waited = 0; busy && waited < 600; waited += 1) {
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  try {
    const response = await fetch(new URL("./samples/" + path, import.meta.url), { cache: "no-cache" });
    if (!response.ok) throw new Error("HTTP " + response.status);
    const bytes = new Uint8Array(await response.arrayBuffer());
    const samplePassword = password || (path === "pdf-encrypted.pdf" ? "demo" : "");
    if (pdfPassword) pdfPassword.value = samplePassword;
    if (pdfUnlockStatus && samplePassword) {
      pdfUnlockStatus.textContent = "このサンプルは暗号化されています。パスワード " + samplePassword + " を使います。";
      pdfUnlockStatus.classList.remove("error");
    }
    if (token === selection) await openBytes(name, bytes);
  } catch (error) {
    if (token === selection) say("サンプルを読み込めませんでした: " + (error.message ?? error), true);
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
async function openLocal(selected) {
  if (!selected || busy) return;
  const token = ++selection;
  try {
    const bytes = new Uint8Array(await selected.arrayBuffer());
    if (token !== selection) return;
    const withFonts = await askFirstFontChoice();
    // 待っている間に別のファイルが選ばれたら、この選択では変換しない。
    if (token !== selection || busy) return;
    await openBytes(selected.name, bytes, false, withFonts);
  } catch (error) {
    if (token === selection) say(selected.name + " を読み込めませんでした: " + (error.message ?? error), true);
  }
}

const drop = $("#drop");
document.addEventListener("dragover", (event) => {
  if (![...event.dataTransfer.types].includes("Files")) return;
  event.preventDefault();
  document.body.classList.add("dragging");
});
document.addEventListener("dragleave", (event) => {
  if (event.relatedTarget) return;
  document.body.classList.remove("dragging");
});
document.addEventListener("drop", (event) => {
  event.preventDefault();
  document.body.classList.remove("dragging");
  void openLocal(event.dataTransfer.files[0]);
});
drop.addEventListener("click", (event) => {
  if (event.target === drop) file.click();
});
file.addEventListener("change", async () => {
  const selected = file.files?.[0];
  file.value = "";
  await openLocal(selected);
});

$("#pdf-unlock").addEventListener("submit", (event) => {
  event.preventDefault();
  if (lastOpen && !busy) void openBytes(lastOpen.name, lastOpen.input, true, lastOpen.useFonts);
});
view.addEventListener("change", () => {
  $("#search-status").textContent = "";
  viewer.setView(view.value);
  viewer.stage.scrollTop = 0;
  viewer.stage.scrollLeft = 0;
  currentPage = 0;
  updatePage();
});
$("#layout").addEventListener("change", (event) => {
  viewer.setLayout(event.target.value);
  viewer.scrollToPage(currentPage);
  updatePage();
});
$("#zoom").addEventListener("change", (event) => {
  viewer.setZoom(Number(event.target.value));
  viewer.scrollToPage(currentPage);
});
$("#previous").addEventListener("click", () => {
  currentPage -= 1;
  updatePage();
  viewer.scrollToPage(currentPage);
});
$("#next").addEventListener("click", () => {
  currentPage += 1;
  updatePage();
  viewer.scrollToPage(currentPage);
});
$("#search-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  try {
    const result = await viewer.find($("#search").value);
    $("#search-status").textContent = result.total
      ? result.index + 1 + " / " + result.total + (result.more ? "+" : "")
      : "0 件";
  } catch (error) {
    say("検索できませんでした: " + (error.message ?? error), true);
  }
});
viewer.stage.addEventListener("scroll", () => {
  if (scrollFrame || !pageCount()) return;
  scrollFrame = requestAnimationFrame(() => {
    scrollFrame = 0;
    const top = viewer.stage.getBoundingClientRect().top;
    const visible = [...viewer.stage.querySelectorAll("[data-bdf-page]")].find(
      (frame) => frame.getBoundingClientRect().bottom > top + 2,
    );
    if (visible) {
      currentPage = Number(visible.dataset.bdfPage);
      updatePage();
    }
  });
});
viewer.addEventListener("error", (event) => {
  event.preventDefault();
  say("表示できませんでした: " + (event.detail?.message ?? event.detail), true);
});

createExportUI({
  root: $("#exports"),
  getDocument: () => openDocument,
  getViewer: () => viewer,
  loadApi: async () => {
    const bridge = await import("./export.js");
    return {
      exportPdf: (base64, tagged) => JSON.parse(bridge.bdf_wasm_export_pdf(base64, tagged ? 1 : 0)),
      markdown: (base64, images) => JSON.parse(bridge.bdf_wasm_markdown(base64, images)),
      searchText: (base64) => JSON.parse(bridge.bdf_wasm_search_text(base64)),
    };
  },
});

const params = new URL(location.href).searchParams;
const requested = params.get("file") ?? params.get("src");
// 上流のビューアが URL の layout で受け取る名前を、このビューアの 3 つに直す。
const LAYOUTS = { pages: "single", single: "single", spread: "spread", "spread-rtl": "spread", scroll: "continuous" };
const initialLayout = LAYOUTS[params.get("layout") ?? ""];
if (initialLayout) {
  $("#layout").value = initialLayout;
  viewer.setLayout(initialLayout);
}
// range は上流のビューアが受け取るパラメーター。bdf.mbt のビューアはまだ
// 開く範囲を絞れないので、いまは全ページを開く。
if (requested) {
  const name = requested.split("/").pop();
  void openSample(name, name);
} else {
  void openSample("demo.pdf", "demo.pdf");
}

window.addEventListener("pagehide", (event) => {
  if (event.persisted) return;
  localFonts.clear({ announce: false });
  viewer.destroy();
  converter.terminate();
  if (downloadUrl) URL.revokeObjectURL(downloadUrl);
});
