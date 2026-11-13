// ローカルフォント（Local Font Access API）の選択 UI。
//
// ページを開いた時点では何も列挙しない。利用者がボタンを押したときだけ
// queryLocalFonts() を呼び、一覧から選ばれた書体のバイト列だけを読む。
// 書体の名前もバイト列もこのページのメモリの中だけに置き、保存も送信もしない。
// 変換に渡すときは getFontFiles() が複製を返すので、Worker 側が
// バッファーを移しても選択そのものは壊れない。

const MAX_FACES = 1000;

// Worker が受け取れる上限。読む前に数と大きさを確かめる。
const DEFAULT_LIMITS = {
  maxFiles: 64,
  maxFileBytes: 32 * 1024 * 1024,
  maxTotalBytes: 64 * 1024 * 1024,
};

const EXTENSIONS = {
  "font/ttf": ".ttf",
  "font/otf": ".otf",
  "font/woff": ".woff",
  "font/woff2": ".woff2",
  "font/collection": ".ttc",
  "application/font-sfnt": ".ttf",
  "application/font-woff": ".woff",
};

/** この環境でローカルフォントを問い合わせられるか。呼び出しの前に確かめる。 */
export function localFontsSupport(scope = globalThis) {
  if (!scope?.isSecureContext) return { ok: false, reason: "insecure" };
  if (typeof scope.queryLocalFonts !== "function") return { ok: false, reason: "unsupported" };
  return { ok: true, reason: "" };
}

/** 一覧に出す名前。FontData のメタデータだけを使う。 */
export function faceLabel(face) {
  const full = typeof face?.fullName === "string" ? face.fullName.trim() : "";
  if (full) return full;
  const family = typeof face?.family === "string" ? face.family.trim() : "";
  const style = typeof face?.style === "string" ? face.style.trim() : "";
  const joined = [family, style].filter(Boolean).join(" ");
  if (joined) return joined;
  return faceName(face);
}

/** 変換に渡すファイル名。拡張子は blob の種類から決める。 */
export function faceName(face) {
  const postscript = typeof face?.postscriptName === "string" ? face.postscriptName.trim() : "";
  return postscript || "font";
}

function postscriptNameOf(face) {
  const value = typeof face?.postscriptName === "string" ? face.postscriptName : "";
  return value.trim() === "" ? null : value;
}

function fileStem(face) {
  const stem = faceName(face).replace(/[\\/:*?"<>|\u0000-\u001f\u007f-\u009f]+/g, "_");
  return stem === "" ? "font" : stem;
}

/** 内部ファイル名だけを作る（セレクターの検証とは別）。 */
export function sanitizeFileName(value, type = "font/ttf") {
  const stem = String(value ?? "").replace(/[\\/:*?"<>|\u0000-\u001f\u007f-\u009f]+/g, "_");
  return fitName(stem === "" ? "font" : stem, "", extension(type));
}

function extension(type) {
  return EXTENSIONS[type] ?? ".ttf";
}

/** 255 UTF-16 単位に収める。サロゲートペアは割らない。 */
function fitName(base, suffix, ext) {
  const room = Math.max(0, 255 - suffix.length - ext.length);
  let stem = base.slice(0, room);
  if (/[\uD800-\uDBFF]$/.test(stem)) stem = stem.slice(0, -1);
  return (stem || "font") + suffix + ext;
}

/** 同じ名前に潰れた書体でも、内部名が重ならないようにする。 */
function uniqueName(base, ext, used) {
  for (let index = 1; ; index += 1) {
    const name = fitName(base, index === 1 ? "" : "-" + index, ext);
    if (!used.has(name)) {
      used.add(name);
      return name;
    }
  }
}

function formatBytes(bytes) {
  return bytes >= 1024 * 1024 ? Math.round(bytes / (1024 * 1024)) + " MiB" : bytes + " バイト";
}

function errorMessage(error) {
  return String(error?.message ?? error ?? "");
}

function describeQueryError(error) {
  const name = error?.name ?? "";
  if (name === "NotAllowedError" || name === "SecurityError") {
    return "ローカルフォントへのアクセスが許可されませんでした。ブラウザの設定でこのサイトに許可するか、フォントファイルを選べます。";
  }
  if (name === "AbortError") {
    return "ローカルフォントの選択が取り消されました。フォントファイルを選ぶか、フォントなしで変換できます。";
  }
  return "ローカルフォントを取得できませんでした: " + errorMessage(error);
}

/**
 * ローカルフォントの選択 UI を作る。
 *
 * @param {object} options
 * @param {HTMLElement} options.root 見出しと説明を置いたコンテナ。操作はここに足す。
 * @param {object} [options.scope] queryLocalFonts と isSecureContext を持つ環境。
 * @param {(files: Array<{name: string, bytes: Uint8Array}> | null) => void} [options.onChange]
 */
export function createLocalFontsUI({ root, scope = globalThis, onChange = () => {}, limits = {} }) {
  const caps = { ...DEFAULT_LIMITS, ...limits };
  if (!root) throw new Error("local fonts: root is required");
  const doc = root.ownerDocument ?? document;
  const prefix = root.id || "local-fonts";

  const controls = doc.createElement("div");
  controls.className = "local-font-controls";

  const queryButton = doc.createElement("button");
  queryButton.type = "button";
  queryButton.className = "button";
  queryButton.textContent = "ローカルフォントを選ぶ";
  const note = doc.getElementById("local-fonts-note");
  if (note) queryButton.setAttribute("aria-describedby", note.id);

  const fileButton = doc.createElement("button");
  fileButton.type = "button";
  fileButton.className = "button";
  fileButton.textContent = "フォントファイルを選ぶ";
  const fileInput = doc.createElement("input");
  fileInput.type = "file";
  fileInput.accept = ".ttf,.otf,.ttc,.otc";
  fileInput.multiple = true;
  fileInput.hidden = true;
  fileInput.setAttribute("aria-label", "フォントファイル");

  const status = doc.createElement("p");
  status.className = "status";
  status.setAttribute("role", "status");
  status.setAttribute("aria-live", "polite");

  const list = doc.createElement("fieldset");
  list.className = "local-font-list";
  list.hidden = true;
  const legend = doc.createElement("legend");
  legend.textContent = "使う書体";
  const searchLabel = doc.createElement("label");
  searchLabel.className = "local-font-search";
  searchLabel.textContent = "書体を検索 ";
  const searchInput = doc.createElement("input");
  searchInput.type = "search";
  searchInput.placeholder = "書体名・ファミリー・スタイル";
  searchLabel.append(searchInput);
  const selectionCount = doc.createElement("p");
  selectionCount.className = "note local-font-count";
  selectionCount.setAttribute("aria-live", "polite");
  const faces = doc.createElement("div");
  faces.className = "faces";
  list.append(legend, searchLabel, selectionCount, faces);

  const actions = doc.createElement("div");
  actions.className = "local-font-actions";
  const applyButton = doc.createElement("button");
  applyButton.type = "button";
  applyButton.className = "button primary";
  applyButton.textContent = "選択した書体を使う";
  applyButton.disabled = true;
  const clearButton = doc.createElement("button");
  clearButton.type = "button";
  clearButton.className = "button";
  clearButton.textContent = "選択を解除";
  clearButton.disabled = true;
  actions.append(applyButton, clearButton);

  const summary = doc.createElement("p");
  summary.className = "note local-font-summary";
  summary.id = prefix + "-summary";
  summary.hidden = true;

  controls.append(queryButton, fileButton, fileInput, status, list, actions, summary);
  root.append(controls);

  let available = [];
  let checked = new Set();
  let selected = null;
  let generation = 0;
  let busy = false;

  function say(message, error = false) {
    status.textContent = message;
    status.classList.toggle("error", error);
  }

  function setBusy(value) {
    busy = value;
    root.setAttribute("aria-busy", String(value));
    queryButton.disabled = value;
    fileButton.disabled = value;
    searchInput.disabled = value;
    applyButton.disabled = value || !hasChecked();
    clearButton.disabled = value || (!selected && available.length === 0);
    for (const input of faces.querySelectorAll('input[type="checkbox"]')) input.disabled = value;
    root.dispatchEvent(new Event("localfontsbusychange"));
  }

  function hasChecked() {
    return checked.size > 0;
  }

  function renderFaces() {
    faces.replaceChildren();
    list.hidden = available.length === 0;
    const term = searchInput.value.trim().toLocaleLowerCase();
    const matching = available.map((face, index) => ({ face, index })).filter(({ face }) =>
      [faceLabel(face), face.family, face.style, face.postscriptName].some((value) =>
        typeof value === "string" && value.toLocaleLowerCase().includes(term)));
    const shown = matching.slice(0, MAX_FACES);
    selectionCount.textContent = checked.size + " 書体を選択中";
    shown.forEach(({ face, index }) => {
      const row = doc.createElement("div");
      row.className = "local-font-face";
      const input = doc.createElement("input");
      input.type = "checkbox";
      input.id = prefix + "-face-" + index;
      input.value = String(index);
      input.checked = checked.has(index);
      const label = doc.createElement("label");
      label.htmlFor = input.id;
      const name = doc.createElement("span");
      name.className = "name";
      name.textContent = faceLabel(face);
      label.append(name);
      const postscript = faceName(face);
      if (postscript && postscript !== faceLabel(face)) {
        const detail = doc.createElement("span");
        detail.className = "note";
        detail.textContent = postscript;
        label.append(" ", detail);
      }
      row.append(input, label);
      faces.append(row);
    });
    if (matching.length > shown.length) {
      const more = doc.createElement("p");
      more.className = "note";
      more.textContent = "先頭 " + shown.length + " 書体だけを表示しています。";
      faces.append(more);
    }
    if (shown.length === 0 && term) {
      const empty = doc.createElement("p");
      empty.className = "note";
      empty.textContent = "一致する書体がありません。";
      faces.append(empty);
    }
    applyButton.disabled = busy || !hasChecked();
    clearButton.disabled = busy || (!selected && available.length === 0);
  }

  function showSummary() {
    if (!selected || selected.length === 0) {
      summary.hidden = true;
      summary.textContent = "";
      return;
    }
    summary.hidden = false;
    summary.textContent = "変換に使う書体: " + selected.map((item) => item.displayName).join("、");
  }

  function publish() {
    onChange(getFontFiles());
  }

  async function query() {
    if (busy) return;
    const support = localFontsSupport(scope);
    if (!support.ok) {
      queryButton.disabled = true;
      say(
        support.reason === "insecure"
          ? "このページは安全な接続（HTTPS か localhost）ではないため、ローカルフォントを一覧できません。フォントファイルを選べます。"
          : "このブラウザはローカルフォントの一覧に対応していません。フォントファイルを選べます。",
        true,
      );
      return;
    }
    const token = ++generation;
    setBusy(true);
    say("ローカルフォントの一覧を問い合わせています…");
    try {
      const result = await scope.queryLocalFonts();
      if (token !== generation) return;
      available = Array.isArray(result)
        ? result.filter((face) => face && typeof face === "object")
        : [];
      checked = new Set();
      searchInput.value = "";
      renderFaces();
      say(
        available.length
          ? available.length + " 書体が見つかりました。使うものを選んでください。"
          : "ローカルフォントが見つかりませんでした。フォントファイルを選べます。",
        available.length === 0,
      );
    } catch (error) {
      if (token !== generation) return;
      available = [];
      checked = new Set();
      renderFaces();
      say(describeQueryError(error), true);
    } finally {
      if (token === generation) setBusy(false);
    }
  }

  async function apply() {
    if (busy) return;
    const chosen = [...checked].sort((a, b) => a - b)
      .map((index) => available[index])
      .filter(Boolean);
    if (chosen.length === 0) {
      say("書体が選ばれていません。一覧から使う書体を選んでください。", true);
      return;
    }
    const keep = () => (selected ? "前の選択をそのまま使います。" : "書体は選ばれていません。");
    if (chosen.length > caps.maxFiles) {
      say("選べる書体は " + caps.maxFiles + " までです（" + chosen.length + " 書体が選ばれています）。" + keep(), true);
      return;
    }
    const postscriptNames = [];
    const seenNames = new Set();
    for (const face of chosen) {
      const postscriptName = postscriptNameOf(face);
      if (
        !postscriptName ||
        postscriptName !== postscriptName.trim() ||
        postscriptName.length > 255 ||
        /[\u0000-\u001f\u007f]/.test(postscriptName) ||
        seenNames.has(postscriptName)
      ) {
        say("選んだ書体の PostScript 名を確認できないため読み込めません。" + keep(), true);
        return;
      }
      seenNames.add(postscriptName);
      postscriptNames.push(postscriptName);
    }
    const token = ++generation;
    setBusy(true);
    say("選んだ書体を読み込んでいます…");
    const loaded = [];
    try {
      // まず blob の大きさだけを見る。上限を超えるなら配列を作らない。
      const blobs = [];
      for (const face of chosen) {
        const blob = await face.blob();
        if (token !== generation) return;
        if (blob.size === 0) {
          say("「" + faceLabel(face) + "」のデータが空のため読み込めません。" + keep(), true);
          return;
        }
        if (blob.size > caps.maxFileBytes) {
          say("「" + faceLabel(face) + "」は 1 書体 " + formatBytes(caps.maxFileBytes) + " を超えるため読み込めません。" + keep(), true);
          return;
        }
        blobs.push({ face, blob });
      }
      const declared = blobs.reduce((sum, item) => sum + item.blob.size, 0);
      if (declared > caps.maxTotalBytes) {
        say("選んだ書体の合計が " + formatBytes(caps.maxTotalBytes) + " を超えるため読み込めません。" + keep(), true);
        return;
      }
      const used = new Set();
      let actual = 0;
      for (let index = 0; index < blobs.length; index += 1) {
        const { face, blob } = blobs[index];
        const bytes = new Uint8Array(await blob.arrayBuffer());
        if (token !== generation) return;
        if (bytes.byteLength === 0) {
          say("「" + faceLabel(face) + "」のデータが空のため読み込めません。" + keep(), true);
          return;
        }
        if (bytes.byteLength > caps.maxFileBytes) {
          say("「" + faceLabel(face) + "」の実体が 1 書体 " + formatBytes(caps.maxFileBytes) + " を超えるため読み込めません。" + keep(), true);
          return;
        }
        actual += bytes.byteLength;
        if (actual > caps.maxTotalBytes) {
          say("選んだ書体の実体の合計が " + formatBytes(caps.maxTotalBytes) + " を超えるため読み込めません。" + keep(), true);
          return;
        }
        loaded.push({
          name: uniqueName(fileStem(face), extension(blob.type), used),
          postscriptName: postscriptNames[index],
          displayName: faceLabel(face),
          bytes,
        });
      }
      selected = loaded;
      showSummary();
      say(loaded.length + " 書体を読み込みました。次の変換でこの書体を使います。");
      publish();
    } catch (error) {
      if (token !== generation) return;
      // 途中で失敗したら何も採用しない（前の選択はそのまま残す）。
      say("選んだ書体を読み込めませんでした: " + errorMessage(error), true);
    } finally {
      if (token === generation) setBusy(false);
    }
  }

  async function selectFiles(files) {
    if (busy || files.length === 0) return;
    const keep = () => (selected ? "前の選択をそのまま使います。" : "書体は選ばれていません。");
    if (files.length > caps.maxFiles) {
      say("選べるファイルは " + caps.maxFiles + " までです。" + keep(), true);
      return;
    }
    if (files.some((file) => !file.size || file.size > caps.maxFileBytes) ||
        files.reduce((sum, file) => sum + file.size, 0) > caps.maxTotalBytes) {
      say("フォントファイルが空か、サイズ上限を超えています。" + keep(), true);
      return;
    }
    const token = ++generation;
    setBusy(true);
    say("選んだフォントファイルを読み込んでいます…");
    try {
      const used = new Set();
      const loaded = [];
      let total = 0;
      for (const file of files) {
        const bytes = new Uint8Array(await file.arrayBuffer());
        if (token !== generation) return;
        total += bytes.byteLength;
        if (!bytes.byteLength || bytes.byteLength > caps.maxFileBytes || total > caps.maxTotalBytes) {
          say("フォントファイルが空か、サイズ上限を超えています。" + keep(), true);
          return;
        }
        const match = /\.(ttf|otf|ttc|otc)$/i.exec(file.name);
        const ext = match ? match[0].toLowerCase() : ".ttf";
        const base = (match ? file.name.slice(0, -ext.length) : file.name)
          .replace(/[\\/:*?"<>|\u0000-\u001f\u007f-\u009f]+/g, "_") || "font";
        loaded.push({ name: uniqueName(base, ext, used), displayName: file.name || "font", bytes });
      }
      selected = loaded;
      available = [];
      checked = new Set();
      searchInput.value = "";
      renderFaces();
      showSummary();
      say(loaded.length + " ファイルを読み込みました。次の変換でこの書体を使います。");
      publish();
    } catch (error) {
      if (token === generation) say("フォントファイルを読み込めませんでした: " + errorMessage(error) + "。" + keep(), true);
    } finally {
      if (token === generation) setBusy(false);
    }
  }

  function clear({ announce = true } = {}) {
    generation += 1;
    available = [];
    checked = new Set();
    searchInput.value = "";
    fileInput.value = "";
    selected = null;
    renderFaces();
    showSummary();
    setBusy(false);
    if (announce) say("選択を解除しました。フォントなしで変換できます。");
    else {
      status.textContent = "";
      status.classList.remove("error");
    }
    publish();
  }

  /** 変換に渡す配列。選択が無ければ null。呼ぶたびに複製を返す。 */
  function getFontFiles() {
    if (!selected || selected.length === 0) return null;
    return selected.map((item) => ({
      name: item.name,
      ...(item.postscriptName ? { postscriptName: item.postscriptName } : {}),
      bytes: item.bytes.slice(),
    }));
  }

  queryButton.addEventListener("click", () => void query());
  fileButton.addEventListener("click", () => fileInput.click());
  fileInput.addEventListener("change", () => {
    const files = [...fileInput.files];
    fileInput.value = "";
    void selectFiles(files);
  });
  searchInput.addEventListener("input", renderFaces);
  applyButton.addEventListener("click", () => void apply());
  clearButton.addEventListener("click", () => clear());
  faces.addEventListener("change", (event) => {
    const input = event.target;
    if (input.matches('input[type="checkbox"]')) {
      const index = Number(input.value);
      if (input.checked) checked.add(index);
      else checked.delete(index);
    }
    selectionCount.textContent = checked.size + " 書体を選択中";
    applyButton.disabled = busy || !hasChecked();
  });

  return {
    query,
    apply,
    clear,
    getFontFiles,
    elements: { queryButton, fileButton, fileInput, searchInput, selectionCount, applyButton, clearButton, status, list, faces, summary },
  };
}
