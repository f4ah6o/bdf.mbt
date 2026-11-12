// Migration-stage runner: fresh outputs, authenticated build, explicit dependencies.
import { readdir, readFile, writeFile, mkdir, cp } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { spawn } from 'node:child_process';
import { parseArgs } from 'node:util';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { loadFixture } from '../fixtures.mjs';
const { values } = parseArgs({ options: { build: { type: 'string' }, output: { type: 'string' }, emulator: { type: 'string' } } });
if (!values.build || !values.output) throw new Error('--build <oracle-directory> --output <new-directory> required');
const build = path.resolve(values.build), output = path.resolve(values.output);
const identity = JSON.parse(await readFile(path.join(build, 'identity.json'), 'utf8'));
const fixtureDir = fileURLToPath(new URL('../', import.meta.url));
const sha = data => createHash('sha256').update(data).digest('hex');
if (identity.version !== 1 || identity.upstream !== 'a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22' || identity.go !== 'go1.27.0') throw new Error('Unexpected oracle identity');
const binary = path.join(build, 'xlsx-oracle.test');
if (sha(await readFile(binary)) !== identity.binarySha256) throw new Error('Oracle binary integrity failure');
const seeds = new Set(['formula-previously-unsupported-inputs.json']);
const tests = [];
for (const [name, hash] of Object.entries(identity.adapters)) {
  if (path.basename(name) !== name) throw new Error('Invalid adapter path');
  const source = await readFile(path.join(fixtureDir, name));
  if (sha(source) !== hash) throw new Error(`Adapter changed: ${name}; rebuild oracle`);
  const text = source.toString();
  if (text.includes('BDF_SOURCE_ROOT')) for (const m of text.matchAll(/"(?:compat\/xlsx\/)?([\w-]+\.json)"/g)) seeds.add(m[1]);
  // These two generate MoonBit source, not JSON fixtures. Never run on a checkout.
  for (const m of text.matchAll(/func (Test\w+)\(/g)) if (!['TestCodexXLSXDuplicateKeys', 'TestCodexXLSXLowercaseTable'].includes(m[1])) tests.push(m[1]);
}
const actualAdapters = [];
for (const name of await readdir(fixtureDir)) if (/^generate.*\.go$/.test(name) && /^package xlsx\s*$/m.test(await readFile(path.join(fixtureDir, name), 'utf8'))) actualAdapters.push(name);
if (actualAdapters.sort().join('\n') !== Object.keys(identity.adapters).sort().join('\n')) throw new Error('Adapter inventory mismatch; rebuild oracle');
for (const [name, hash] of Object.entries(identity.seeds)) {
  if (!name.startsWith('runtime/') || name.split('/').includes('..')) throw new Error('Invalid seed path');
  if (sha(await readFile(path.join(build, name))) !== hash) throw new Error(`Seed integrity failure: ${name}`);
}
await mkdir(output); // No stale outputs or fallback to a previous generation.
await mkdir(path.join(output, 'compat/xlsx'), { recursive: true });
await mkdir(path.join(output, 'seed/compat/xlsx'), { recursive: true });
const inputSeeds = {};
for (const name of seeds) {
  const content = JSON.stringify(await loadFixture(`./${name}`));
  inputSeeds[name] = sha(content);
  await writeFile(path.join(output, 'seed/compat/xlsx', name), content);
}
await cp(path.join(output, 'seed/compat/xlsx/formula-previously-unsupported-inputs.json'), path.join(output, 'compat/xlsx/formula-previously-unsupported-inputs.json'));
async function run(selected) {
  const args = ['-test.run', `^(${selected.join('|')})$`, '-test.count=1', '-test.timeout=20m'];
  const command = values.emulator || binary;
  if (values.emulator) args.unshift(binary);
  const status = await new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd: path.join(build, 'runtime/xlsx'), stdio: 'inherit', env: { ...process.env, GOMAXPROCS: '2', GODEBUG: '', TZ: 'UTC', LC_ALL: 'C', BDF_FIXTURE_ROOT: output, BDF_SOURCE_ROOT: path.join(output, 'seed') } });
    child.once('error', reject); child.once('close', resolve);
  });
  if (status !== 0) throw new Error(`Oracle generation failed (${status}); output retained: ${output}`);
}
// store-sheet consumes the generated table-values JSON.
await run(tests.filter(name => name !== 'TestCodexXLSXStoreSheet'));
await run(['TestCodexXLSXStoreSheet']);
await writeFile(path.join(output, 'identity.json'), JSON.stringify({ ...identity, generatedAt: new Date().toISOString(), inputSeeds, tests }, null, 2) + '\n');
console.log(`Generated ${tests.length} adapters into ${output}; static migration comparison remains mandatory.`);
