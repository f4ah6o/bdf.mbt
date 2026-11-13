// Each invocation gets fresh generated expectations; only the oracle build is reusable.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { parseArgs } from 'node:util';
import { generate, validateGenerated } from './generate.mjs';
import { lock, lockSha, strictLockSha, sha } from './contract.mjs';
import { renderManifestSha, validateRenderIds } from './render-inventory.mjs';
import { validateVerifiers, verifierManifestSha } from './verifier-inventory.mjs';
import { readNoteDifferences } from './note-differences.mjs';

const { values, positionals } = parseArgs({ allowPositionals: true, options: { suite: { type: 'string' }, script: { type: 'string' } } });
if (Boolean(values.suite) === Boolean(values.script) || (values.suite && !['compat', 'visual', 'picture-visual'].includes(values.suite))) throw Error('Choose --suite compat|visual|picture-visual or --script <verifier>');
if (values.script && !/^compat\/(xlsx|ooxml)\/verify-[\w-]+\.mjs$/.test(values.script) && !['compat/xlsx/emission-test.mjs', 'compat/xlsx/tools/fixture-store-test.mjs', 'compat/xlsx/shard-test.mjs'].includes(values.script)) throw Error('Expected a repository XLSX/OOXML verifier or compatibility test');
if (values.suite && positionals.length) throw Error('Verifier arguments require --script');
const build = process.env.BDF_XLSX_ORACLE_BUILD, emulator = process.env.BDF_XLSX_ORACLE_EMULATOR;
if (!build) throw Error('BDF_XLSX_ORACLE_BUILD must name the pinned ARM64 oracle build; see compat/xlsx/oracle/README.md');
const tmp = await mkdtemp(path.join(tmpdir(), 'bdf-xlsx-run-')), output = path.join(tmp, 'output');
let success = false;
try {
  const start = performance.now();
  await validateVerifiers();
  const receipt = await generate(path.resolve(build), output, emulator ? path.resolve(emulator) : null);
  const generated = performance.now();
  const receiptSha = sha(await readFile(path.join(output, 'receipt.json')));
  const renderManifest = new URL('./render-ids.manifest', import.meta.url);
  const verifierManifest = new URL('./verifiers.manifest', import.meta.url);
  async function verifyRun() {
    assert.equal(sha(await readFile(path.join(output, 'receipt.json'))), receiptSha, 'run receipt changed');
    assert.equal(sha(await readFile(new URL('./lock.manifest', import.meta.url))), lockSha, 'oracle lock changed');
    assert.equal(sha(await readFile(new URL('./strict-lock.manifest', import.meta.url))), strictLockSha, 'strict lock changed');
    assert.equal(sha(await readFile(new URL('./inputs.data', import.meta.url))), lock.inputBundleSha256, 'input bundle changed');
    assert.equal(sha(await readFile(new URL('./notes.data', import.meta.url))), lock.noteBundleSha256, 'notes bundle changed');
    assert.equal(sha(await readFile(renderManifest)), renderManifestSha, 'render ID manifest changed');
    assert.equal(sha(await readFile(verifierManifest)), verifierManifestSha, 'verifier manifest changed');
    await validateVerifiers();
    assert.deepEqual(await validateGenerated(output), receipt.files, 'generated outputs changed');
    assert.deepEqual(await readNoteDifferences(output), receipt.noteReport, 'raw notes difference report changed');
  }
  await verifyRun();
  const env = { ...process.env, BDF_XLSX_FIXTURE_ROOT: output, BDF_XLSX_RUN_ID: receipt.runId, BDF_XLSX_RECEIPT_SHA: receiptSha };
  async function run(script, args = []) {
    const result = await new Promise((resolve, reject) => {
      const child = spawn(process.execPath, [script, ...args], { env, stdio: 'inherit' });
      child.once('error', reject); child.once('close', (code, signal) => resolve({ code, signal }));
    });
    if (result.code !== 0) throw Error(`${script} failed (code=${result.code}, signal=${result.signal})`);
  }
  if (values.suite === 'compat') {
    const ids = path.join(tmp, 'render.ids');
    await run('compat/xlsx/verify-render.mjs', ['--list', '--ids', ids]);
    console.log(`Verified ${validateRenderIds(await readFile(ids))} baseline render IDs and four-shard ownership`);
  }
  const scripts = values.script ? [values.script] : values.suite === 'compat'
    ? ['compat/xlsx/oracle/test.mjs', 'compat/xlsx/tools/fixture-store-test.mjs', 'compat/xlsx/emission-test.mjs', 'compat/xlsx/shard-test.mjs', 'compat/xlsx/verify-all.mjs']
    : values.suite === 'visual' ? ['compat/xlsx/visual-barrier-test.mjs', 'compat/xlsx/visual-compare.mjs']
    : ['compat/xlsx/picture-visual-compare.mjs'];
  for (const script of scripts) await run(script, values.script ? positionals : []);
  await verifyRun();
  success = true;
  console.log(`XLSX oracle run ${receipt.runId}: generated ${(generated - start).toFixed(0)} ms, verified ${(performance.now() - generated).toFixed(0)} ms`);
} finally {
  if (success && process.env.BDF_XLSX_ORACLE_KEEP !== '1') await rm(tmp, { recursive: true, force: true });
  else console.error(`XLSX run output retained: ${output}`);
}
