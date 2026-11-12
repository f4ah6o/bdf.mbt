// Local-only capture verification. Never fetches samples or approves baselines.
import { readFileSync, realpathSync, statSync } from 'node:fs';
import { resolve, dirname, relative, isAbsolute, sep } from 'node:path';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { PNG } from 'pngjs';
export const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const need = (ok, message) => { if (!ok) throw new Error(message); };
const nonempty = x => typeof x === 'string' && x.trim().length > 0;
const hash = x => typeof x === 'string' && /^[a-f0-9]{64}$/.test(x);
const positive = x => Number.isSafeInteger(x) && x > 0;
export function localPath(root, name) {
  need(nonempty(name) && !isAbsolute(name), 'file path must be relative');
  const file = realpathSync(resolve(root, name));
  const rel = relative(realpathSync(root), file);
  need(rel !== '..' && !rel.startsWith(`..${sep}`) && !isAbsolute(rel), 'file escapes artifact directory');
  need(statSync(file).size <= 64 * 1024 * 1024, 'file exceeds 64 MiB verification limit');
  return file;
}
function localFile(root, name) {
  return readFileSync(localPath(root, name));
}
function readCapture(file, role, documents) {
  const root = dirname(resolve(file));
  const capture = JSON.parse(readFileSync(file, 'utf8'));
  need(capture.schema === 1 && capture.role === role, `invalid ${role} capture schema/role`);
  for (const k of ['engine', 'version', 'createdAt', 'platform', 'fonts']) need(nonempty(capture[k]), `${role}: missing ${k}`);
  need(Number.isFinite(Date.parse(capture.createdAt)), `${role}: invalid createdAt`);
  need(positive(capture.dpi), `${role}: invalid dpi`);
  if (role === 'oracle') need(capture.engine === 'DocuWorks' || capture.engine === 'DocuWorks Viewer Light', 'oracle must identify genuine DocuWorks');
  else {
    need(capture.engine === 'bdf.mbt' && /^[a-f0-9]{40}$/.test(capture.commit), 'candidate requires bdf.mbt and full commit SHA');
    need(capture.status === 'CAPTURED', 'candidate capture status must be CAPTURED');
    need(typeof capture.dirty === 'boolean', 'candidate capture must record dirty as a boolean');
  }
  need(Array.isArray(capture.pages), `${role}: pages missing`);
  const pages = new Map();
  for (const p of capture.pages) {
    const doc = documents.get(p.document);
    need(doc && positive(p.page) && p.page <= doc.pages, `${role}: unexpected document/page`);
    const key = `${p.document}:${p.page}`;
    need(!pages.has(key), `${role}: duplicate ${key}`);
    need(p.inputSha256 === doc.sha256, `${role}: input hash mismatch ${key}`);
    need(hash(p.sha256), `${role}: invalid image hash ${key}`);
    need(positive(p.width) && positive(p.height) && p.width * p.height <= 20000000, `${role}: invalid image dimensions ${key}`);
    const bytes = localFile(root, p.image);
    need(sha256(bytes) === p.sha256, `${role}: image hash mismatch ${key}`);
    // Bound allocation before asking pngjs to decompress an untrusted PNG.
    need(bytes.length >= 33 && bytes.subarray(0, 8).equals(Buffer.from('89504e470d0a1a0a', 'hex')) && bytes.toString('ascii', 12, 16) === 'IHDR', `${role}: not a PNG ${key}`);
    let offset = 8;
    let headers = 0;
    let ended = false;
    while (offset < bytes.length) {
      need(offset + 12 <= bytes.length, `${role}: truncated PNG chunk ${key}`);
      const length = bytes.readUInt32BE(offset);
      const kind = bytes.toString('ascii', offset + 4, offset + 8);
      need(length <= bytes.length - offset - 12, `${role}: truncated PNG data ${key}`);
      if (kind === 'IHDR') {
        headers++;
        need(headers === 1 && offset === 8 && length === 13, `${role}: invalid/duplicate IHDR ${key}`);
        // pngjs's interlaced synchronous decoder does not bound inflate output.
        need(bytes[offset + 20] === 0, `${role}: interlaced PNG unsupported ${key}`);
      }
      if (kind === 'IEND') {
        need(length === 0 && offset + 12 === bytes.length, `${role}: invalid IEND/trailing PNG data ${key}`);
        ended = true;
      }
      offset += length + 12;
    }
    need(headers === 1 && ended, `${role}: incomplete PNG ${key}`);
    need(bytes.readUInt32BE(16) === p.width && bytes.readUInt32BE(20) === p.height, `${role}: PNG dimensions mismatch ${key}`);
    const image = PNG.sync.read(bytes);
    need(image.width === p.width && image.height === p.height && image.data.length === p.width * p.height * 4, `${role}: decoded PNG dimensions mismatch ${key}`);
    let visibleInk = false;
    for (let i = 0; i < image.data.length; i += 4) {
      // Detect empty captures after compositing on white, not transparent RGB garbage.
      const a = image.data[i + 3] / 255;
      if ([0, 1, 2].some(c => 255 - a * (255 - image.data[i + c]) < 245)) { visibleInk = true; break; }
    }
    need(visibleInk || doc.blankPages.includes(p.page), `${role}: unexpected blank ${key}`);
    need(Array.isArray(p.warnings) && p.warnings.length === 0, `${role}: warnings must be empty ${key}`);
    need(typeof p.text === 'string', `${role}: text must be explicit (empty for image-only) ${key}`);
    pages.set(key, { ...p, pixels: image.data });
  }
  for (const doc of documents.values()) for (let i = 1; i <= doc.pages; i++) need(pages.has(`${doc.id}:${i}`), `${role}: missing ${doc.id}:${i}`);
  return { ...capture, pages };
}
export function verify({ corpusFile, oracleFile, candidateFile }) {
  const corpus = JSON.parse(readFileSync(corpusFile, 'utf8'));
  need(corpus.schema === 1 && Array.isArray(corpus.documents) && corpus.documents.length > 0, 'corpus must contain at least one document');
  need(positive(corpus.expectedDocuments) && corpus.expectedDocuments === corpus.documents.length, 'corpus document count mismatch');
  need(positive(corpus.expectedPages), 'corpus expectedPages missing');
  const t = corpus.thresholds;
  need(t && Number.isFinite(t.maxChangedRatio) && t.maxChangedRatio >= 0 && t.maxChangedRatio < 1 && Number.isInteger(t.channelDelta) && t.channelDelta >= 0 && t.channelDelta < 255, 'invalid explicit pixel thresholds');
  need(nonempty(corpus.thresholdRationale), 'threshold rationale required');
  const docs = new Map();
  for (const d of corpus.documents) {
    need(typeof d.id === 'string' && /^[A-Za-z0-9_-]+$/.test(d.id) && !docs.has(d.id), 'invalid or duplicate document id');
    need(hash(d.sha256) && positive(d.pages), `${d.id}: invalid hash/pages`);
    need(d.access === 'public' && nonempty(d.source) && /^https:\/\//.test(d.source) && nonempty(d.licenseNotes), `${d.id}: public provenance/license notes required`);
    need(Array.isArray(d.blankPages) && new Set(d.blankPages).size === d.blankPages.length && d.blankPages.every(p => positive(p) && p <= d.pages), `${d.id}: invalid blank page declaration`);
    need(sha256(localFile(dirname(resolve(corpusFile)), d.file)) === d.sha256, `${d.id}: source hash mismatch`);
    docs.set(d.id, d);
  }
  need([...docs.values()].reduce((n, d) => n + d.pages, 0) === corpus.expectedPages, 'corpus page count mismatch');
  // Missing evidence is NOT RUN, never an empty successful comparison.
  if (!oracleFile || !candidateFile) return { status: 'NOT_RUN', reason: 'Both genuine DocuWorks and bdf.mbt capture manifests are required', documents: docs.size, expectedPages: corpus.expectedPages };
  const oracle = readCapture(oracleFile, 'oracle', docs);
  const candidate = readCapture(candidateFile, 'candidate', docs);
  need(oracle.dpi === candidate.dpi, 'capture dpi mismatch');
  const results = [];
  for (const [key, before] of oracle.pages) {
    const after = candidate.pages.get(key);
    need(before.width === after.width && before.height === after.height, `capture dimensions mismatch ${key}`);
    let changed = 0;
    for (let i = 0; i < before.pixels.length; i += 4) {
      const composite = (p, c) => 255 - p[i + 3] / 255 * (255 - p[i + c]);
      if ([0, 1, 2].some(c => Math.abs(composite(before.pixels, c) - composite(after.pixels, c)) > t.channelDelta)) changed++;
    }
    const ratio = changed / (before.width * before.height);
    const textEqual = before.text === after.text;
    results.push({ page: key, changedPixels: changed, ratio, textEqual, pass: ratio <= t.maxChangedRatio && textEqual });
  }
  return { status: results.every(p => p.pass) ? 'PASS' : 'FAIL', documents: docs.size, comparedPages: results.length, thresholds: t, thresholdRationale: corpus.thresholdRationale, oracle: { engine: oracle.engine, version: oracle.version, fonts: oracle.fonts, platform: oracle.platform }, candidate: { commit: candidate.commit, version: candidate.version, fonts: candidate.fonts, platform: candidate.platform, status: candidate.status, dirty: candidate.dirty }, results };
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const [corpusFile, oracleFile, candidateFile] = process.argv.slice(2);
  let report;
  try { need(corpusFile, 'usage: node compat/xdw/verify.mjs CORPUS.json [ORACLE.json CANDIDATE.json]'); report = verify({ corpusFile, oracleFile, candidateFile }); }
  catch (error) { report = { status: 'ERROR', reason: error.message }; }
  console.log(JSON.stringify(report, null, 2));
  process.exitCode = report.status === 'PASS' ? 0 : report.status === 'NOT_RUN' ? 2 : 1;
}
