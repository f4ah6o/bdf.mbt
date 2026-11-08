// トップページのスクリプト。demo.bdf を bdf.mbt のビューアで開き、
// 下の「BDF から元に戻す」を wasm-gc の書き出しにつなぐ。
import { bdf_create_viewer } from "./browser.js";
import { createExportUI } from "./export-ui.js";

const $ = (selector) => document.querySelector(selector);
const host = $("#demo");
const viewer = bdf_create_viewer(host, {
  workerUrl: new URL("./render_worker.js", import.meta.url).href,
  layout: "single",
});
let bytes = null;
let name = "demo.bdf";
let current = 0;

const pageNum = $("#pageNum");
const hits = $("#hits");

function count() {
  return viewer.view?.pages?.length ?? 0;
}

function showPage() {
  const total = count();
  current = Math.max(0, Math.min(current, Math.max(0, total - 1)));
  pageNum.textContent = total ? current + 1 + " / " + total : "–";
  $("#prevPage").disabled = total === 0 || current === 0;
  $("#nextPage").disabled = total === 0 || current + 1 >= total;
}

async function open(source, label) {
  const response = await fetch(source, { cache: "no-cache" });
  if (!response.ok) throw new Error("HTTP " + response.status);
  bytes = new Uint8Array(await response.arrayBuffer());
  name = label;
  const manifest = await viewer.open({ kind: "buffer", buffer: bytes.slice().buffer });
  current = 0;
  showPage();
  viewer.stage.scrollTop = 0;
  document.dispatchEvent(new CustomEvent("bdf:document", { detail: { name } }));
  return manifest;
}

function step(delta) {
  current += delta;
  showPage();
  viewer.scrollToPage(current);
}

$("#prevPage").addEventListener("click", () => step(-1));
$("#nextPage").addEventListener("click", () => step(1));
$("#layout").addEventListener("change", (event) => {
  viewer.setLayout(event.target.value);
  viewer.scrollToPage(current);
});
let zoom = 1;
$("#zoomIn").addEventListener("click", () => {
  zoom = Math.min(3, Math.round((zoom + 0.25) * 100) / 100);
  viewer.setZoom(zoom);
  viewer.scrollToPage(current);
});
$("#zoomOut").addEventListener("click", () => {
  zoom = Math.max(0.5, Math.round((zoom - 0.25) * 100) / 100);
  viewer.setZoom(zoom);
  viewer.scrollToPage(current);
});

async function find(delta) {
  const query = $("#q").value.trim();
  if (!query) return;
  const result = await viewer.find(query, delta);
  hits.textContent = result.total ? (result.index + 1) + " / " + result.total + (result.more ? "+" : "") : "0 件";
}
$("#q").addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    event.preventDefault();
    void find(1);
  }
});
$("#prev").addEventListener("click", () => void find(-1));
$("#next").addEventListener("click", () => void find(1));

let frame = 0;
viewer.stage.addEventListener("scroll", () => {
  if (frame) return;
  frame = requestAnimationFrame(() => {
    frame = 0;
    const top = viewer.stage.getBoundingClientRect().top;
    const page = [...viewer.stage.querySelectorAll("[data-bdf-page]")].find(
      (node) => node.getBoundingClientRect().bottom > top + 2,
    );
    if (page) {
      current = Number(page.dataset.bdfPage);
      showPage();
    }
  });
});

viewer.addEventListener("error", (event) => {
  event.preventDefault();
  hits.textContent = "表示できませんでした: " + (event.detail?.message ?? event.detail);
});

const back = $(".back");
if (back) {
  createExportUI({
    root: back,
    getDocument: () => (bytes ? { name, bytes } : null),
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
}

open("./samples/demo.bdf", "demo.bdf").catch((error) => {
  hits.textContent = "サンプルを開けませんでした: " + (error.message ?? error);
});

window.addEventListener("pagehide", (event) => {
  if (!event.persisted) viewer.destroy();
});
