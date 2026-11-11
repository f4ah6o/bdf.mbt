// フォームのページ。上流 BDF の site/form/main.ts（MIT）を、bdf.mbt の
// form パッケージ（form_api.js）とビューア（browser.js）で書き直したもの。
//
// テンプレート（タグを書いた Excel・Word・PowerPoint、フォームの欄を持つ
// PDF、pdfme のテンプレート、タグを書いたテキスト、コンパイル済みの .bdft、
// 記入途中の .bdff）をブラウザの中で読み、タグからデータの JSON Schema を
// 作り、そのスキーマからフォームを作り、記入済みの BDF を描いて、.bdf・
// .bdff・.bdft・PDF で保存する。読む・作る・描くは form パッケージが行い、
// このページは Go のランタイムを使わない。
import { bdf_form_compile, bdf_form_describe, bdf_form_fill } from "./form_api.js";
import { bdf_create_viewer } from "./browser.js";
import { base64ToBytes, bytesToBase64, createWasm } from "./wasm-gc.js";

const $ = (id) => document.getElementById(id);
const url = (path) => new URL(path, import.meta.url).href;
const FORMS = url("./forms/");

const status = $("status");
const fieldsBox = $("fields");
const jsonBox = $("json");
const savePdf = $("savePdf");
const saveBdf = $("saveBdf");
const saveBdft = $("saveBdft");

function setStatus(text) {
  status.textContent = text;
  status.classList.toggle("error", text.startsWith("error"));
}

function failure(error) {
  const message = String(error?.message ?? error);
  return message.startsWith("error") ? message : "error: " + message;
}

const viewer = bdf_create_viewer($("preview"), {
  workerUrl: url("./render_worker.js"),
  layout: "single",
});

let template;
/** テンプレートに入れるデータと、その画像（データ URL）。 */
let data = {};
/** 別の人に残す名前（記入すると .bdff になる）。 */
const leaveOpen = new Set();
/** 記入済みの BDF。データが変わったら、記入し直すまで undefined。 */
let filled;
/** 記入した文書がシート表示（Excel）か、PDF にできるページがあるか。 */
let sheetView = false;
let pdfPages = 0;
let bdfURL = "";
/** テンプレートを開くたびに増える。前に開いたものの結果は捨てる。 */
let opening = 0;
/** 記入するたびに増える。データが変わったら、前の記入の結果は捨てる。 */
let filling = 0;
/** フォームを作り直すたびに増える。前のフォームのコントロールの結果は捨てる。 */
let formGeneration = 0;
/** データを置き換えるたびに増える。前のデータへの書き込みは捨てる。 */
let dataGeneration = 0;
/** JSON がデータでない間は、記入しない（refuseJson）。 */
let blocked = false;
let currentPage = 0;
let wasmPromise = null;

/** 保存できるものを消す: データが変わったか、記入に失敗した。
 *
 *  記入し直すまで、.bdf・.bdff・.bdft・PDF は出さない。前のデータの
 *  文書を、今のデータの文書として保存させないため。 */
function invalidate() {
  filling += 1;
  filled = undefined;
  if (bdfURL) URL.revokeObjectURL(bdfURL);
  bdfURL = "";
  saveBdf.removeAttribute("href");
  saveBdf.hidden = true;
  savePdf.disabled = true;
  saveBdft.disabled = true;
  $("pdfNote").hidden = true;
}

// --- データと、そのスキーマから作るフォーム ---

const types = (s) => (Array.isArray(s.type) ? s.type : s.type ? [s.type] : []);
const isList = (s) => types(s).includes("array");
const isObject = (s) => types(s).includes("object") && !!s.properties;
const isPicture = (s) => s["x-bdf"]?.kind === "image" && !s["x-bdf"]?.code;

/** まだ何も入っていないデータ: スキーマの名前すべて、表は 1 行。 */
function blank(s) {
  if (isList(s)) {
    const items = s.items ?? {};
    return isObject(items) ? [blank(items)] : [];
  }
  if (isObject(s)) return Object.fromEntries(Object.entries(s.properties).map(([name, p]) => [name, blank(p)]));
  if (s.default !== undefined && s.default !== null && typeof s.default !== "object") return s.default;
  const t = types(s);
  if (t.length === 1 && t[0] === "boolean") return false;
  if (t.length === 1 && t[0] === "number") return null;
  return "";
}

/** 打ち込んだ値を、テキストか数値にする（007 はテキストのまま）。 */
const typed = (text) => (/^-?(0|[1-9]\d*)(\.\d+)?$/.test(text) && text.length < 16 ? Number(text) : text);

const shown = (v) => (v === null || v === undefined || typeof v === "object" ? "" : String(v));

/** テンプレートのどこに名前があるか（ラベルの説明に使う）。 */
function where(s) {
  const info = s["x-bdf"];
  const at = info?.at?.length ? `${info.at.join(", ")} に` : "";
  const format = info?.format ? `${info.format} で表示` : "";
  return [s.description, at, format].filter(Boolean).join("; ");
}

/** リストが何か（名前のあとに添える）。 */
function listHint(s) {
  const info = s["x-bdf"];
  if (info?.mode === "slots") return `1 ページに ${s.maxItems ?? info.slots} 件まで`;
  if (info?.mode === "pages") return "1 件が 1 ページ";
  if (info?.mode === "rows") return "1 件が 1 行";
  return "";
}

let nextId = 0;
/** フォームを作り直したあとに焦点を当てるコントロールの id。 */
let focusNext = "";

/** リストでもオブジェクトでもない値のコントロール。 */
function control(s, value, set, inTable) {
  const t = types(s);
  const only = (name) => t.length === 1 && t[0] === name;
  if (only("boolean")) {
    const box = document.createElement("input");
    box.type = "checkbox";
    box.checked = value === true;
    box.onchange = () => set(box.checked);
    return box;
  }
  if (isPicture(s)) return pictureControl(value, set);
  if (s.enum?.length) {
    const choice = document.createElement("select");
    const labels = s["x-bdf"]?.labels ?? [];
    const options = s.enum.map((v, i) => new Option(labels[i] ?? shown(v), shown(v)));
    const now = shown(value);
    if (now !== "" && !s.enum.some((v) => shown(v) === now)) options.push(new Option(now, now));
    choice.append(new Option("", ""), ...options);
    choice.value = now;
    choice.onchange = () => set(choice.value);
    return choice;
  }
  const input = document.createElement("input");
  if (only("number")) {
    input.type = "number";
    input.step = "any";
    input.value = typeof value === "number" ? String(value) : "";
    input.oninput = () => set(input.value === "" || Number.isNaN(input.valueAsNumber) ? null : input.valueAsNumber);
    return input;
  }
  const text = shown(value);
  if (s.format === "date" && /^(\d{4}-\d{2}-\d{2})?$/.test(text)) {
    input.type = "date";
  } else if (s.format === "date-time" && /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?)?$/.test(text)) {
    input.type = "datetime-local";
  } else if (!inTable) {
    const area = document.createElement("textarea");
    area.rows = Math.min(6, text.split("\n").length);
    area.value = text;
    if (s.maxLength) area.maxLength = s.maxLength;
    area.oninput = () => {
      area.rows = Math.min(6, area.value.split("\n").length);
      set(t.includes("number") ? typed(area.value) : area.value);
    };
    if (s["x-bdf"]?.code) area.inputMode = /^(ean|upc|itf|jan)/.test(s["x-bdf"].code) ? "numeric" : "text";
    return area;
  }
  input.value = text;
  if (s.maxLength) input.maxLength = s.maxLength;
  input.oninput = () => set(t.includes("number") && input.type === "text" ? typed(input.value) : input.value);
  return input;
}

/** 画像の値: ファイル名かデータ URL。bdf.mbt は Office のテンプレートに
 *  画像を埋め込まないので、pdfme のテンプレートでだけ絵になる。
 *
 *  読むのは PNG・JPEG・SVG だけ（form/pdfme が読む形）。GIF や WebP は
 *  選ばせない: 読めない画像を、読めたように見せない。 */
const PICTURES = ["image/png", "image/jpeg", "image/svg+xml"];

function pictureControl(value, set) {
  const box = document.createElement("span");
  box.className = "picture";
  const name = document.createElement("input");
  name.value = shown(value);
  name.placeholder = "画像なし";
  // 打ち込んだ値が、待っている画像の読みに上書きされないようにする
  let request = 0;
  name.oninput = () => {
    request += 1;
    set(name.value);
  };
  const pick = document.createElement("input");
  pick.type = "file";
  pick.accept = PICTURES.join(",");
  pick.hidden = true;
  // 読んでいる間にテンプレート・データ・フォームが変わったら、この結果は捨てる
  const at = opening;
  const form = formGeneration;
  const dataAt = dataGeneration;
  const current = (mine) =>
    mine === request && at === opening && form === formGeneration && dataAt === dataGeneration && !blocked && box.isConnected;
  pick.onchange = async () => {
    const file = pick.files?.[0];
    pick.value = "";
    if (!file) return;
    if (!PICTURES.includes(file.type)) {
      setStatus(`error: ${file.name} は読めません。画像は PNG・JPEG・SVG のどれかです`);
      return;
    }
    const mine = ++request;
    let bytes;
    try {
      bytes = new Uint8Array(await file.arrayBuffer());
    } catch (e) {
      if (current(mine)) setStatus(failure(e));
      return;
    }
    if (!current(mine)) return;
    name.value = `data:${file.type};base64,${bytesToBase64(bytes)}`;
    set(name.value);
  };
  const button = document.createElement("button");
  button.type = "button";
  button.textContent = "画像を選ぶ…";
  button.title = "PNG・JPEG・SVG";
  button.onclick = () => pick.click();
  box.append(name, button, pick);
  return box;
}

/** オブジェクトの名前のコントロール。 */
function field(name, s, value, set) {
  const title = s.title ?? name;
  if (isList(s)) return list(title, s, Array.isArray(value) ? value : [], set);
  if (isObject(s)) {
    const group = document.createElement("fieldset");
    const legend = document.createElement("legend");
    legend.textContent = title;
    group.append(legend, properties(s, value, set));
    return group;
  }
  const label = document.createElement("label");
  const c = control(s, value, set, false);
  const text = document.createElement("span");
  text.textContent = title;
  text.title = where(s);
  const code = s["x-bdf"]?.code;
  if (code) {
    const hint = document.createElement("small");
    hint.textContent = code === "qr" ? "QR コード" : `バーコード: ${code}`;
    text.append(" ", hint);
  }
  const input = s["x-bdf"]?.input;
  if (input === "signature" || input === "seal") {
    const hint = document.createElement("small");
    hint.textContent = input === "seal" ? "印影の画像" : "署名の画像";
    hint.title = "上流の署名パッドと印影の白抜きは移植していません。画像を選ぶか、データ URL を入れてください。";
    text.append(" ", hint);
  }
  if (c instanceof HTMLInputElement && c.type === "checkbox") {
    label.className = "check";
    label.append(c, text);
  } else {
    label.className = "field";
    label.append(text, c);
  }
  return label;
}

/** オブジェクトの名前のコントロール一式。 */
function properties(s, value, set) {
  const obj = value !== null && typeof value === "object" && !Array.isArray(value) ? value : {};
  const box = document.createElement("div");
  box.className = "props";
  // リストは値のあとに置く: 行の多い表が、テンプレートの前後を分けないように
  const all = Object.entries(s.properties ?? {});
  for (const [name, p] of [...all.filter(([, p]) => !isList(p)), ...all.filter(([, p]) => isList(p))]) {
    box.append(field(name, p, obj[name], (v) => {
      obj[name] = v;
      set(obj);
    }));
  }
  return box;
}

/** リストの項目: 値かオブジェクトの表、そうでなければ 1 件ずつのまとまり。 */
function list(title, s, items, set) {
  const item = s.items ?? {};
  const group = document.createElement("fieldset");
  group.className = "list";
  const legend = document.createElement("legend");
  legend.textContent = title;
  legend.title = where(s);
  const hint = listHint(s);
  if (hint) {
    const small = document.createElement("small");
    small.textContent = hint;
    legend.append(" ", small);
  }
  group.append(legend);
  const full = s.maxItems !== undefined && items.length >= s.maxItems;
  const remake = (focus) => {
    focusNext = focus;
    set(items);
    buildForm();
  };
  const addId = `add${nextId++}`;
  const remove = (i, label) => {
    const b = document.createElement("button");
    b.type = "button";
    b.className = "remove";
    b.textContent = "×";
    b.title = b.ariaLabel = `${label} を削除`;
    b.onclick = () => {
      items.splice(i, 1);
      remake(addId);
    };
    return b;
  };
  const props = isObject(item) ? Object.entries(item.properties ?? {}) : undefined;
  const flat = !props || props.every(([, p]) => !isList(p) && !isObject(p));
  if (flat) {
    const table = document.createElement("table");
    if (props) {
      const head = table.createTHead().insertRow();
      for (const [name, p] of props) {
        const th = document.createElement("th");
        th.scope = "col";
        th.textContent = p.title ?? name;
        th.title = where(p);
        head.append(th);
      }
      head.append(document.createElement("td"));
    }
    const body = table.createTBody();
    items.forEach((it, i) => {
      const row = body.insertRow();
      const cell = (p, value, put, label) => {
        const c = control(p, value, put, true);
        (c.querySelector("input") ?? c).setAttribute("aria-label", label);
        row.insertCell().append(c);
      };
      if (props) {
        const obj = it !== null && typeof it === "object" && !Array.isArray(it) ? it : (items[i] = {});
        for (const [name, p] of props) {
          cell(p, obj[name], (v) => {
            obj[name] = v;
            set(items);
          }, `${p.title ?? name}（${title} ${i + 1}）`);
        }
      } else {
        cell(item, it, (v) => {
          items[i] = v;
          set(items);
        }, `${title} ${i + 1}`);
      }
      row.insertCell().append(remove(i, `${title} ${i + 1}`));
    });
    const wrap = document.createElement("div");
    wrap.className = "rows";
    wrap.append(table);
    group.append(wrap);
  } else {
    items.forEach((it, i) => {
      const one = document.createElement("fieldset");
      one.className = "item";
      const l = document.createElement("legend");
      l.append(`${title} ${i + 1} `, remove(i, `${title} ${i + 1}`));
      one.append(l, properties(item, it, (v) => {
        items[i] = v;
        set(items);
      }));
      group.append(one);
    });
  }
  const add = document.createElement("button");
  add.type = "button";
  add.id = addId;
  add.className = "add";
  add.textContent = flat ? "行を足す" : `${title} を足す`;
  add.disabled = full;
  if (full) add.title = `${title} は ${s.maxItems} 件までです`;
  add.onclick = () => {
    items.push(isObject(item) ? blank(item) : "");
    remake(addId);
  };
  group.append(add);
  return group;
}

/** 別の人に残せる名前: 値と、オブジェクトのリスト（リストはまとめて）。 */
function names(s, prefix = "") {
  return Object.entries(s.properties ?? {}).flatMap(([name, p]) => {
    const path = prefix ? `${prefix}.${name}` : name;
    if (isObject(p) && !isList(p)) return names(p, path);
    return [{ name: path, title: path.split(".").length > 1 ? `${p.title ?? name}（${path}）` : p.title ?? name }];
  });
}

/** 別の人に残す名前を除いたデータ。 */
function withoutOpen(d) {
  if (!leaveOpen.size) return d;
  const out = structuredClone(d);
  for (const path of leaveOpen) {
    const parts = path.split(".");
    let at = out;
    for (const p of parts.slice(0, -1)) at = at !== null && typeof at === "object" && !Array.isArray(at) ? at[p] : undefined;
    if (at !== null && typeof at === "object" && !Array.isArray(at)) delete at[parts[parts.length - 1]];
  }
  return out;
}

/** 別の人に残す名前の選択。 */
function handOn() {
  const group = document.createElement("fieldset");
  group.className = "handon";
  const legend = document.createElement("legend");
  legend.textContent = "別の人に残す";
  const note = document.createElement("p");
  note.className = "note";
  note.textContent = "ここに印を付けた名前は空のまま残ります。そのときの文書は記入途中の帳票（.bdff）になり、別の人がこのページで開いて残りを記入します。";
  group.append(legend, note);
  for (const n of names(template.schema)) {
    const label = document.createElement("label");
    label.className = "check";
    const box = document.createElement("input");
    box.type = "checkbox";
    box.checked = leaveOpen.has(n.name);
    box.ariaLabel = `${n.title} を別の人に残す`;
    box.onchange = () => {
      if (box.checked) leaveOpen.add(n.name);
      else leaveOpen.delete(n.name);
      if (template) how(template);
      // 残す名前が変わると、記入済みの文書も変わる
      invalidate();
      schedule();
    };
    const text = document.createElement("span");
    text.textContent = n.title;
    label.append(box, text);
    group.append(label);
  }
  return group;
}

/** テンプレートのスキーマからフォームを作る。 */
function buildForm() {
  if (!template) return;
  formGeneration += 1;
  nextId = 0;
  const all = Object.keys(template.schema.properties ?? {});
  if (!all.length) {
    const p = document.createElement("p");
    p.className = "note";
    p.textContent = "このテンプレートにはタグがありません。データを求めていません。値を入れるところに {{name}} と書いてください。";
    fieldsBox.replaceChildren(p);
    return;
  }
  const parts = [];
  if (template.open?.length) {
    const p = document.createElement("p");
    p.className = "note partial";
    p.textContent = `記入途中の帳票です。${template.held} 個の値が入っています。残りを記入してください: ${template.open.join(", ")}。`;
    parts.push(p);
  }
  parts.push(properties(template.schema, data, (v) => {
    data = v;
    changed();
  }), handOn());
  fieldsBox.replaceChildren(...parts);
  if (focusNext) document.getElementById(focusNext)?.focus();
  focusNext = "";
}

/** フォーム（または JSON）でデータが変わった: もう一度記入する。
 *
 *  記入し直すまでは、前のデータの文書を保存させない（invalidate）。 */
function changed(from) {
  // データが読めたので、記入を止めていたのを解く
  blocked = false;
  invalidate();
  if (from !== "json") showJson();
  schedule();
}

function showJson() {
  jsonBox.value = JSON.stringify(data, null, 2);
  jsonBox.removeAttribute("aria-invalid");
}

/** データのファイルは保存するとき（とテンプレートを開いたとき）に作る。 */
function jsonFile() {
  if (saveJson.href) URL.revokeObjectURL(saveJson.href);
  saveJson.href = URL.createObjectURL(new Blob([jsonBox.value + "\n"], { type: "application/json" }));
}

const saveJson = $("saveJson");
saveJson.onclick = jsonFile;

/** JSON がデータでない: 記入を止め、待っている記入も取り消す。
 *
 *  前のデータの文書を、今のデータの文書として出さない。 */
function refuseJson(message) {
  jsonBox.setAttribute("aria-invalid", "true");
  blocked = true;
  // 待っている画像の読みも、この時点で捨てる（呼び出し元でも増やす）
  dataGeneration += 1;
  clearTimeout(timer);
  invalidate();
  setStatus(message);
}

jsonBox.oninput = () => {
  // 打ち込んだ時点で、待っている画像の読みは捨てる（JSON が読めなくても）
  dataGeneration += 1;
  let v;
  try {
    v = JSON.parse(jsonBox.value);
  } catch (e) {
    refuseJson(`error: データが JSON ではありません: ${e.message}`);
    return;
  }
  if (v === null || typeof v !== "object" || Array.isArray(v)) {
    refuseJson("error: データは JSON のオブジェクトです");
    return;
  }
  jsonBox.removeAttribute("aria-invalid");
  data = v;
  changed("json");
};

// --- 作業のタブと、データの中のタブ ---

function tabGroup(ids, onSelect) {
  const tabs = ids.map((id) => $(id));
  const select = (tab) => {
    if (tab.hasAttribute("disabled")) return;
    for (const t of tabs) {
      const on = t === tab;
      t.setAttribute("aria-selected", String(on));
      t.tabIndex = on ? 0 : -1;
      $(t.getAttribute("aria-controls")).hidden = !on;
    }
    onSelect(tab);
  };
  for (const tab of tabs) {
    tab.onclick = () => select(tab);
    tab.onkeydown = (e) => {
      const enabled = tabs.filter((t) => !t.hasAttribute("disabled"));
      const step = e.key === "ArrowRight" ? 1 : e.key === "ArrowLeft" ? -1 : 0;
      const to = e.key === "Home" ? enabled[0] : e.key === "End" ? enabled.at(-1)
        : step ? enabled[(enabled.indexOf(tab) + step + enabled.length) % enabled.length] : undefined;
      if (!to) return;
      e.preventDefault();
      select(to);
      to.focus();
    };
  }
  return { tabs, select };
}

const dataTabs = tabGroup(["tabForm", "tabJson", "tabSchema"], (tab) => {
  // JSON がデータを変えていることがある。
  if (tab.id === "tabForm") buildForm();
});
const workspaceTabs = tabGroup(["tabTemplate", "tabData", "tabPreview"], () => {});

// --- 記入する ---

let timer = 0;
let busy = false;
let again = false;

/** 打ち込みが止まってから記入する。 */
function schedule() {
  clearTimeout(timer);
  // JSON がデータでない間と、テンプレートを開いている間は、記入しない
  if (blocked || !template) return;
  timer = window.setTimeout(() => { fillNow().catch((e) => setStatus(failure(e))); }, 250);
}

async function fillNow() {
  if (blocked) return;
  if (busy) {
    again = true;
    return;
  }
  busy = true;
  try {
    do {
      again = false;
      await fillOnce();
    } while (again);
  } finally {
    busy = false;
  }
}

async function fillOnce() {
  const t = template;
  if (!t || blocked) return;
  const token = opening;
  const serial = ++filling;
  const started = performance.now();
  const given = withoutOpen(data);
  let res;
  try {
    res = JSON.parse(bdf_form_fill(t.bytes, JSON.stringify(given), JSON.stringify([...leaveOpen]), false));
  } catch (e) {
    if (token === opening && serial === filling) {
      invalidate();
      setStatus(failure(e));
    }
    return;
  }
  // データが変わったか、テンプレートを開き直した: この結果は捨てる
  if (token !== opening || serial !== filling) return;
  if (!res.ok) {
    invalidate();
    setStatus(failure(res.error));
    return;
  }
  filled = base64ToBytes(res.bdf);
  const took = performance.now() - started;
  const views = Array.isArray(res.views) ? res.views : [];
  const pages = typeof res.pages === "number" ? res.pages : 0;
  sheetView = views.some((v) => v.kind === "sheet");
  pdfPages = pages;
  if (bdfURL) URL.revokeObjectURL(bdfURL);
  bdfURL = URL.createObjectURL(new Blob([filled], { type: "application/octet-stream" }));
  saveBdf.href = bdfURL;
  const partly = res.partial;
  saveBdf.download = `${t.base}.${partly ? "bdff" : "bdf"}`;
  saveBdf.textContent = partly ? ".bdff" : ".bdf";
  saveBdf.title = partly ? `記入途中の帳票: ${res.open.join(", ")} を残しています` : "記入済みの帳票（BDF）";
  saveBdf.hidden = false;
  // シート表示の帳票は PDF にできるページを持たない: 押させない
  const noPdf = sheetView || pages === 0;
  savePdf.disabled = noPdf;
  saveBdft.disabled = false;
  const note = $("pdfNote");
  note.hidden = !noPdf;
  note.textContent = sheetView
    ? "Excel のシート表示の帳票です。プレビューと BDF の保存はできますが、PDF への書き出しはまだできません。"
    : "この帳票には PDF にできるページがありません。BDF で保存してください。";
  setWarnings(res.warnings);
  await draw(filled);
  if (token !== opening || serial !== filling) return;
  const sheets = views.filter((v) => v.kind === "sheet");
  const titles = sheets.map((v) => v.title).filter(Boolean);
  const what = sheetView
    ? `シート ${sheets.length} 枚${titles.length ? `（${titles.join("、")}）` : ""}`
    : `${pages} ページ`;
  setStatus(`${t.name} を ${took.toFixed(0)} ms で記入しました: ${what}、${kb(filled.length)} の${partly ? `記入途中の帳票（${res.open.join(", ")} を残す）` : " BDF"}`);
}

function kb(bytes) {
  return bytes < 1024 ? `${bytes} B` : bytes < 1024 * 1024 ? `${(bytes / 1024).toFixed(1)} KB` : `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

function setWarnings(list) {
  const box = $("warnings");
  box.hidden = list.length === 0;
  box.querySelector("summary").textContent = `${list.length} 件の注意`;
  box.querySelector("ul").replaceChildren(...list.map((w) => {
    const li = document.createElement("li");
    li.textContent = w;
    return li;
  }));
}

// --- 記入済みの帳票を描く ---

async function draw(bytes) {
  await viewer.open({ kind: "buffer", buffer: bytes.slice().buffer });
  viewer.stage.scrollTop = 0;
  viewer.stage.scrollLeft = 0;
  currentPage = 0;
  updatePage();
}

function pageCount() {
  return viewer.view?.pages?.length ?? 0;
}

function updatePage() {
  const count = pageCount();
  currentPage = Math.max(0, Math.min(currentPage, Math.max(0, count - 1)));
  // シート表示に「0 ページ」と言わせない: ページではなくシートを描いている
  $("page-number").textContent = sheetView ? "シート" : count ? `${currentPage + 1} / ${count}` : "–";
  $("previous").disabled = count === 0 || currentPage === 0;
  $("next").disabled = count === 0 || currentPage + 1 >= count;
}

$("previous").onclick = () => {
  currentPage -= 1;
  updatePage();
  viewer.scrollToPage(currentPage);
};
$("next").onclick = () => {
  currentPage += 1;
  updatePage();
  viewer.scrollToPage(currentPage);
};
viewer.stage.addEventListener("scroll", () => {
  requestAnimationFrame(() => {
    const top = viewer.stage.getBoundingClientRect().top;
    const visible = [...viewer.stage.querySelectorAll("[data-bdf-page]")].find((frame) => frame.getBoundingClientRect().bottom > top + 2);
    if (visible) {
      currentPage = Number(visible.dataset.bdfPage);
      updatePage();
    }
  });
});
viewer.addEventListener("error", (event) => {
  event.preventDefault();
  setStatus("error: 描けませんでした: " + (event.detail?.message ?? event.detail));
});

// --- 保存する ---

// PDF の文字を描くフォント。テキストのテンプレートは升目に置くので等幅の
// M PLUS 1 Code、Office と pdfme は字幅の自由な M PLUS 1p を使う。
const FONT_FILES = { text: "MPLUS1Code-Regular.ttf", other: "MPLUS1p-Regular.ttf" };
const fontPromises = new Map();

function formFont(format) {
  const name = FONT_FILES[format] ?? FONT_FILES.other;
  if (!fontPromises.has(name)) {
    fontPromises.set(
      name,
      fetchBytes("fonts/" + name).catch((error) => {
        fontPromises.delete(name);
        throw error;
      }),
    );
  }
  return fontPromises.get(name);
}

function getWasm() {
  if (!wasmPromise) {
    wasmPromise = createWasm(url("./wasm-gc.wasm")).catch((error) => {
      wasmPromise = null;
      throw error;
    });
  }
  return wasmPromise;
}

savePdf.onclick = async () => {
  const t = template;
  const doc = filled;
  if (!t || !doc) return;
  const serial = filling;
  savePdf.disabled = true;
  const label = savePdf.textContent;
  savePdf.textContent = "PDF を書いています…";
  try {
    // シート表示と 0 ページの帳票は、PDF にできるページを持たない: 書き出さない
    if (sheetView || pdfPages === 0) throw new Error("PDF にできるページがありません（シート表示の帳票は PDF に書き出せません）");
    const started = performance.now();
    const wasm = await getWasm();
    const font = await formFont(t.format);
    // 待っている間にデータが変わったら、前の文書は書き出さない
    if (serial !== filling || filled !== doc) return;
    const res = wasm.exportPdfWithFont(
      bytesToBase64(doc),
      false,
      bytesToBase64(font),
    );
    if (!res.ok) throw new Error(res.error ?? "PDF を書き出せませんでした");
    // 0 ページの PDF は、書けたように見えるだけの空のファイル: 出さない
    if (!res.pages) throw new Error("PDF にできるページがありません（シート表示の帳票は PDF に書き出せません）");
    const pdf = base64ToBytes(res.pdf);
    const a = document.createElement("a");
    a.href = URL.createObjectURL(new Blob([pdf], { type: "application/pdf" }));
    a.download = `${t.base}.pdf`;
    a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 60_000);
    const notes = res.warnings?.length ? `; ${res.warnings.length} 件の注意: ${res.warnings.join("; ")}` : "";
    setStatus(`${t.base}.pdf を ${(performance.now() - started).toFixed(0)} ms で書き出しました: ${res.pages} ページ、${res.fonts} フォント、${kb(pdf.length)}${notes}`);
  } catch (e) {
    setStatus(failure(e));
  } finally {
    savePdf.textContent = label;
    // 記入し直していれば、その結果に合わせてボタンを戻す
    savePdf.disabled = !filled || sheetView || pdfPages === 0;
  }
};

saveBdft.onclick = () => {
  const t = template;
  if (!t) return;
  const res = JSON.parse(bdf_form_compile(t.bytes, t.name, JSON.stringify(data)));
  if (!res.ok) {
    setStatus(failure(res.error));
    return;
  }
  const bytes = base64ToBytes(res.bdft);
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob([bytes], { type: "application/octet-stream" }));
  a.download = `${t.base}.bdft`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 60_000);
  const notes = res.warnings.length ? `; ${res.warnings.length} 件の注意` : "";
  setStatus(`${t.base}.bdft を書き出しました: ${kb(bytes.length)}${notes}`);
};

// --- テンプレートを開く ---

/** テンプレートを開いている間は、前のテンプレートを使わない。
 *
 *  前のテンプレートの記入を待たせたままにすると、新しいテンプレートを
 *  読んでいる間に前の文書ができて、保存できるように見えてしまう。
 *  開くのに失敗したら、そのまま（前のテンプレートには戻さない）。 */
function suspend() {
  clearTimeout(timer);
  again = false;
  template = undefined;
  data = {};
  dataGeneration += 1;
  sheetView = false;
  pdfPages = 0;
  leaveOpen.clear();
  invalidate();
  fieldsBox.replaceChildren();
  jsonBox.value = "";
  if (saveJson.href) URL.revokeObjectURL(saveJson.href);
  saveJson.removeAttribute("href");
  $("schema").textContent = "";
  $("how").hidden = true;
  setWarnings([]);
  $("document-name").textContent = "–";
  $("document-meta").textContent = "";
  document.title = "フォーム – BDF.mbt";
}

/** テンプレートを開く: タグを読み、フォームを作り、サンプル（か空）で記入する。 */
async function openTemplate(name, bytes, sample) {
  const token = ++opening;
  const base = name.replace(/\.[^.]*$/, "");
  // 前のテンプレートの文書は、もう出さない
  suspend();
  setStatus(`${name} を読んでいます…`);
  let res;
  try {
    res = JSON.parse(bdf_form_describe(bytes, sample ? JSON.stringify(sample) : ""));
  } catch (e) {
    if (token === opening) setStatus(failure(e));
    return;
  }
  if (token !== opening) return;
  if (!res.ok) {
    setStatus(failure(res.error));
    return;
  }
  const schema = JSON.parse(res.schema);
  template = { name, base, bytes, format: res.format, schema, schemaText: res.schema, open: res.open, held: res.held };
  leaveOpen.clear();
  // 新しいテンプレートのデータは、このページが作る: 前の JSON の誤りは解く
  blocked = false;
  const given = sample ?? res.sample ?? undefined;
  data = given ? structuredClone(given) : blank(schema);
  dataGeneration += 1;
  setWarnings([]);
  $("schema").textContent = res.schema;
  const a = $("saveSchema");
  if (a.href) URL.revokeObjectURL(a.href);
  a.href = URL.createObjectURL(new Blob([res.schema], { type: "application/schema+json" }));
  a.download = `${base}.schema.json`;
  saveJson.download = `${base}.json`;
  for (const tab of workspaceTabs.tabs) tab.removeAttribute("disabled");
  dataTabs.select($("tabForm"));
  workspaceTabs.select($("tabData"));
  $("tabData").focus({ preventScroll: true });
  showJson();
  jsonFile();
  how(template);
  $("document-name").textContent = name;
  $("document-meta").textContent = res.format;
  document.title = `${name} – フォーム – BDF.mbt`;
  setStatus(`${name} を記入しています…`);
  await fillNow();
}

/** データが持つ値の数（オブジェクトでないもの）。 */
function countValues(v) {
  if (v !== null && typeof v === "object" && !Array.isArray(v)) return Object.values(v).reduce((n, e) => n + countValues(e), 0);
  return 1;
}

/** 同じことをコードから行うときの呼び方。 */
function how(t) {
  const open = [...leaveOpen];
  const fill = open.length
    ? `// 名前を残す: 記入途中の帳票（.bdff）になる
let part = @form.fill(template, @form.Options::new(data=data, open=[${open.map((n) => JSON.stringify(n)).join(", ")}]))
// 別の人が残りを記入する
let done = @form.fill(part.bdf, @form.Options::new(data=rest))`
    : `let result = @form.fill(template, @form.Options::new(data=data))`;
  $("api").textContent = `// タグからデータの JSON Schema を作る
let schema = @form.schema_of(template, Some(data))
${fill}
// コンパイルする（.bdft）
let compiled = @form.compile(template, ${JSON.stringify(t.name)}, @form.Options::new(data=data))
// 記入済みの BDF を PDF にする（wasm-gc の bdf_wasm_export_pdf）
`;
  $("how").hidden = false;
}

async function fetchBytes(path) {
  const r = await fetch(FORMS + path);
  if (!r.ok) throw new Error(`${path}: HTTP ${r.status}`);
  return new Uint8Array(await r.arrayBuffer());
}

/** サンプルを開く: テンプレートと、その形のデータ。
 *
 *  取ってくる前に世代を進める。遅い前の選択が、新しい選択を上書きしない
 *  ように、取ってきたものは開く直前に確かめる。 */
async function openPreset(p, name) {
  const token = ++opening;
  suspend();
  setStatus(`${name} を取っています…`);
  let bytes;
  let sample;
  try {
    [bytes, sample] = await Promise.all([
      fetchBytes(name),
      fetchBytes(p.data).then((b) => JSON.parse(new TextDecoder().decode(b))),
    ]);
  } catch (e) {
    if (token === opening) setStatus(failure(e));
    return;
  }
  if (token !== opening) return;
  await openTemplate(name, bytes, sample);
}

function renderPresets(presets, style) {
  const body = $("presets").querySelector("tbody");
  body.replaceChildren();
  for (const p of presets) {
    const templates = p.templates.filter((t) => !t.style || t.style === style);
    if (!templates.length) continue;
    const row = body.insertRow();
    const th = document.createElement("th");
    th.scope = "row";
    th.textContent = p.label;
    const about = row.insertCell();
    about.textContent = p.about;
    if (p.note) {
      const note = document.createElement("small");
      note.className = "note";
      note.textContent = p.note;
      about.append(document.createElement("br"), note);
    }
    const cell = row.insertCell();
    cell.className = "samples";
    for (const t of templates) {
      const entry = document.createElement("span");
      entry.className = "sample-template";
      const b = document.createElement("button");
      b.type = "button";
      b.textContent = t.label;
      b.title = t.name;
      b.ariaLabel = `${p.label}、${t.style ?? ""} ${t.label}`;
      b.onclick = () => openPreset(p, t.name);
      const source = document.createElement("a");
      source.href = FORMS + t.name;
      source.download = t.name;
      source.textContent = `元の .${t.name.split(".").pop()} をダウンロード`;
      source.title = `元のテンプレート: ${t.name}`;
      source.ariaLabel = `${p.label}、${t.style ?? ""} ${t.label}: 元のテンプレートをダウンロード`;
      entry.append(b, source);
      cell.append(entry);
    }
    row.prepend(th);
  }
  $("sampleStyleNote").textContent = style === "modern"
    ? "余白を広く、紺の見出しと細い横罫線で組みます。"
    : "白黒で、題名を中央に、表は格子で囲みます。";
}

async function listPresets() {
  const res = await fetch(FORMS + "index.json");
  if (!res.ok) return;
  const presets = await res.json();
  // "?template=form-rows.docx" でそのサンプルを開く
  const want = new URLSearchParams(location.search).get("template");
  const preset = presets.find((p) => p.templates.some((t) => t.name === want));
  const picker = $("sampleStyle");
  picker.value = preset?.templates.find((t) => t.name === want)?.style ?? "standard";
  picker.onchange = () => renderPresets(presets, picker.value);
  renderPresets(presets, picker.value);
  $("sampleStyleControls").hidden = !presets.some((p) => p.templates.some((t) => t.style));
  $("presets").hidden = false;
  if (preset && want) await openPreset(preset, want);
}

/** 手元のファイルを開く。読む前に世代を進める（openPreset と同じ）。 */
async function openLocal(file) {
  const token = ++opening;
  suspend();
  setStatus(`${file.name} を読んでいます…`);
  let bytes;
  try {
    bytes = new Uint8Array(await file.arrayBuffer());
  } catch (e) {
    if (token === opening) setStatus(failure(e));
    return;
  }
  if (token !== opening) return;
  await openTemplate(file.name, bytes);
}

const picker = $("file");
picker.onchange = () => {
  const file = picker.files?.[0];
  picker.value = "";
  if (file) openLocal(file);
};
$("choose").onclick = () => picker.click();

// ページのどこかにドロップされたテンプレート
const carriesFiles = (e) => e.dataTransfer?.types.includes("Files") ?? false;
let depth = 0; // dragenter と dragleave は通る要素ごとに起きる
const dragging = (on) => document.body.classList.toggle("dragging", on);
window.addEventListener("dragenter", (e) => { if (carriesFiles(e)) dragging(++depth > 0); });
window.addEventListener("dragleave", (e) => { if (carriesFiles(e)) dragging(--depth > 0); });
window.addEventListener("dragover", (e) => {
  if (!carriesFiles(e)) return;
  e.preventDefault();
  e.dataTransfer.dropEffect = "copy";
});
window.addEventListener("drop", (e) => {
  if (!carriesFiles(e)) return;
  e.preventDefault();
  depth = 0;
  dragging(false);
  const file = e.dataTransfer.files[0];
  if (file) openLocal(file);
});

fieldsBox.onsubmit = (e) => e.preventDefault();
window.addEventListener("pagehide", (event) => {
  if (!event.persisted) {
    viewer.destroy();
    if (bdfURL) URL.revokeObjectURL(bdfURL);
  }
});
listPresets().catch((e) => console.error("bdf:", e));
