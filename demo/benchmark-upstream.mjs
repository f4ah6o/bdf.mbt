import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import os from 'node:os';

const root = resolve(import.meta.dirname, '..');
const argumentsMap = new Map();
for (let index = 2; index < process.argv.length; index += 2) {
  const key = process.argv[index];
  const value = process.argv[index + 1];
  if (!key?.startsWith('--') || value === undefined) throw new Error('usage: node demo/benchmark-upstream.mjs --bdf /path/to/bdf [--revision commit] [--iterations 7] [--warmup 2]');
  argumentsMap.set(key.slice(2), value);
}
const binary = resolve(argumentsMap.get('bdf') ?? '/tmp/bdf-go');
const revision = argumentsMap.get('revision') ?? '';
const iterations = Number(argumentsMap.get('iterations') ?? 7);
const warmup = Number(argumentsMap.get('warmup') ?? 2);
if (!Number.isInteger(iterations) || iterations < 1 || !Number.isInteger(warmup) || warmup < 0) throw new Error('iterations and warmup must be integers');
const inputBdf = resolve(root, 'demo/samples/upstream-demo.bdf');
const inputPdf = resolve(root, 'demo/samples/upstream-demo.pdf');
const output = resolve(root, 'demo/benchmarks-upstream.json');
const work = mkdtempSync(join(tmpdir(), 'bdf-upstream-bench-'));
const pdfOut = join(work, 'upstream-demo.pdf');
const markdownOut = join(work, 'markdown');
const textOut = join(work, 'upstream-demo-text.json');
const bdfOut = join(work, 'upstream-demo-from-pdf.bdf');

const median = values => {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)];
};
const run = (command, args) => {
  execFileSync(binary, args, { stdio: 'ignore' });
};
const measure = (prepare, command, args) => {
  const one = () => {
    prepare();
    run(command, args);
  };
  for (let index = 0; index < warmup; index += 1) one();
  const times = [];
  for (let index = 0; index < iterations; index += 1) {
    const start = performance.now();
    one();
    times.push(performance.now() - start);
  }
  return median(times);
};
const remove = path => rmSync(path, { recursive: true, force: true });
const pdfMs = measure(() => remove(pdfOut), 'pdf', ['pdf', '-q', inputBdf, pdfOut]);
const markdownMs = measure(() => remove(markdownOut), 'markdown', ['markdown', '-q', inputBdf, markdownOut]);
const textMs = measure(() => remove(textOut), 'text', ['text', inputBdf, textOut]);
const bdfMs = measure(() => remove(bdfOut), 'generate', ['generate', '-q', inputPdf, bdfOut]);

let goVersion = 'unknown';
try {
  const version = execFileSync('go', ['version', '-m', binary], { encoding: 'utf8' });
  goVersion = version.match(/go\d+\.\d+\.\d+/)?.[0] ?? 'unknown';
} catch { /* report unknown rather than fail the measurement */ }

const payload = {
  schemaVersion: 1,
  measuredAt: new Date().toISOString(),
  environment: {
    go: goVersion,
    upstreamRevision: revision || null,
    cpu: os.cpus()[0]?.model ?? 'unknown',
    platform: os.platform(),
    arch: os.arch(),
    node: process.version,
    binary: binary,
  },
  methodology: {
    inputBdf: 'upstream-demo.bdf',
    inputPdf: 'upstream-demo.pdf',
    iterations,
    warmup,
    statistic: 'median',
    commands: ['bdf pdf', 'bdf markdown', 'bdf text', 'bdf generate'],
    processStartupIncluded: true,
    note: '上流 BDF (Go) の CLI を同じ20ページ BDF / PDF に対して実行。プロセス起動とファイル書き出しを含む。bdf.mbt の表はブラウザ内のウォーム済み関数で、メモリ内の結果。',
  },
  results: [
    { id: 'bdf-pdf', ms: pdfMs, bytes: statSync(pdfOut).size },
    { id: 'bdf-markdown', ms: markdownMs, bytes: statSync(join(markdownOut, 'upstream-demo.md')).size },
    { id: 'bdf-text', ms: textMs, bytes: statSync(textOut).size },
    { id: 'pdf-bdf', ms: bdfMs, bytes: statSync(bdfOut).size },
  ],
};
writeFileSync(output, JSON.stringify(payload, null, 2) + '\n');
console.log('Upstream BDF (Go): ' + payload.results.map(result => result.id + ' ' + Math.round(result.ms * 10) / 10 + ' ms').join(' / '));
console.log('Wrote ' + output);
rmSync(work, { recursive: true, force: true });
