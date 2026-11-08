// 検索用テキストのページ。bdf.mbt で BDF にし、wasm-gc の検索テキストを取り出す。
import { bdf_create_native_converter } from "./browser.js";

const $ = (selector) => document.querySelector(selector);
const SAMPLES = [
  ["demo.pdf", "PDF（20 ページ）"],
  ["basic.docx", "Word"],
  ["features.pptx", "PowerPoint"],
  ["features.xlsx", "Excel"],
  ["basic.md", "Markdown"],
];
const status = $("#status");
const output = $("#output");
const links = $("#links");
const file = $("#file");
const converter = bdf_create_native_converter(new URL("./native_converter_worker.js", import.meta.url).href);
let text = null;
let textUrl = null;

function say(message, error = false) {
  status.textContent = message;
  status.classList.toggle("error", error);
}

async function run(name, bytes) {
  say(name + " を変換しています…");
  try {
    let bdf = bytes;
    if (!name.toLowerCase().endsWith(".bdf")) {
      await converter.ready;
      const result = await converter.convert(bytes, { name });
      bdf = result.bdf;
    }
    const bridge = await import("./export.js");
    const base64 = bytesToBase64(bdf);
    const result = JSON.parse(bridge.bdf_wasm_search_text(base64));
    if (result.error) throw new Error(result.error);
    // 実際のレコードは JSON 文字列として text に入っている
    text = typeof result.text === "string" ? JSON.parse(result.text) : result;
    show();
    say(name + " のテキストを取り出しました");
  } catch (error) {
    say(name + " のテキストを取り出せませんでした: " + (error.message ?? error), true);
  }
}

function bytesToBase64(bytes) {
  let out = "";
  const chunk = 0x8000;
  for (let index = 0; index < bytes.length; index += chunk) {
    out += String.fromCharCode(...bytes.subarray(index, index + chunk));
  }
  return btoa(out);
}

function show() {
  if (!text) return;
  const shape = $("#shape").value;
  let body;
  let type;
  if (shape === "plain") {
    body = (text.views ?? [])
      .map((view) =>
        (view.pages ?? [])
          .map((page) => "--- p. " + (page.page ?? 1) + " ---\n" + (page.text ?? ""))
          .join("\n\n"),
      )
      .join("\n\n");
    type = "text/plain";
  } else {
    body = JSON.stringify(text, null, 2);
    type = "application/json";
  }
  output.value = body;
  if (textUrl) URL.revokeObjectURL(textUrl);
  textUrl = URL.createObjectURL(new Blob([body], { type }));
  links.hidden = false;
  $("#save").href = textUrl;
  $("#save").download = "search-text." + (shape === "plain" ? "txt" : "json");
}

$("#samples").replaceChildren(
  ...SAMPLES.map(([path, label]) => {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = label;
    button.addEventListener("click", async () => {
      try {
        const response = await fetch(new URL("./samples/" + path, import.meta.url), { cache: "no-cache" });
        if (!response.ok) throw new Error("HTTP " + response.status);
        await run(path, new Uint8Array(await response.arrayBuffer()));
      } catch (error) {
        say(path + " を読み込めませんでした: " + (error.message ?? error), true);
      }
    });
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
$("#shape").addEventListener("change", show);
$("#copy").addEventListener("click", async () => {
  try {
    await navigator.clipboard.writeText(output.value);
    say("コピーしました");
  } catch (error) {
    say("コピーできませんでした: " + (error.message ?? error), true);
  }
});

void (async () => {
  try {
    const response = await fetch(new URL("./samples/demo.pdf", import.meta.url), { cache: "no-cache" });
    if (response.ok) await run("demo.pdf", new Uint8Array(await response.arrayBuffer()));
  } catch (error) {
    say("サンプルを読み込めませんでした: " + (error.message ?? error), true);
  }
})();
