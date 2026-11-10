// Guard the required visual aggregate against dropped-format checks.
//
// PCB/KiCad, musical score and EPUB are outside the porting scope. Their
// sources, tests and fixtures stay in the tree as dormant assets, but the
// required `test:visual` aggregate must not run them. Audio playback and the
// negative checks that prove dropped formats are not dispatched stay required.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../..');
const scripts = JSON.parse(readFileSync(path.join(root, 'package.json'), 'utf8')).scripts;

// Entry points that belong to the dropped score, PCB/KiCad and EPUB features.
const droppedPaths = [
  'compat/music/verify.mjs',
  'compat/music/player-test.mjs',
  'compat/music/piano-test.mjs',
  'compat/music/player-browser-test.mjs',
  'compat/continuous/viewer-music-test.mjs',
  'compat/midiinput/',
  'compat/mml/',
  'compat/musicxml/',
  'compat/musicnotation/',
  'compat/kicad/',
  'compat/gerber/',
  'compat/epub/',
];
const droppedScripts = [
  'test:music-compat',
  'test:midi-input',
  'test:midi-visual',
  'test:mml-input',
  'test:mml-document',
  'test:mml-visual',
  'test:musicxml-input',
  'test:music-notation',
  'test:phase10-musicxml',
];

// Expand `npm run <name>` references so a nested script cannot smuggle a
// dropped check into the aggregate.
function expand(name, seen = new Set()) {
  if (seen.has(name)) return [];
  seen.add(name);
  const command = scripts[name];
  if (command === undefined) return [];
  const out = [];
  for (const part of command.split('&&').map(step => step.trim()).filter(Boolean)) {
    const nested = part.match(/^npm run ([\w:-]+)$/);
    if (nested) out.push(...expand(nested[1], seen));
    else out.push(part);
  }
  return out;
}

const aggregate = expand('test:visual');
assert.ok(aggregate.length > 0, 'test:visual must expand to commands');

for (const command of aggregate) {
  for (const dropped of droppedPaths) {
    assert.ok(!command.includes(dropped), `test:visual still runs dropped check ${dropped}: ${command}`);
  }
  for (const dropped of droppedScripts) {
    assert.ok(!command.includes(dropped), `test:visual still runs dropped script ${dropped}: ${command}`);
  }
}

// Retained audio playback stays required.
assert.ok(
  aggregate.some(command => command.includes('compat/music/audio-test.mjs')),
  'test:visual must keep the retained audio playback test',
);

// The dropped individual scripts stay available for manual verification.
for (const name of droppedScripts) {
  assert.ok(scripts[name] !== undefined, `dropped-format script ${name} must not be deleted`);
}

// The visual comparison keeps retained audio and the negative dispatch guard,
// and no longer imports or calls the dropped score checks.
const compare = readFileSync(path.join(root, 'compat/visual/compare.mjs'), 'utf8');
assert.match(compare, /import \{ verifyAudioBrowser \} from '\.\.\/music\/audio-browser-test\.mjs';/);
assert.match(compare, /await verifyAudioBrowser\(browser,base\);/);
assert.match(compare, /import \{ verifyNativeConverter \} from '\.\.\/converter\/native-test\.mjs';/);
assert.match(compare, /await verifyNativeConverter\(browser,base\);/);
assert.match(compare, /import \{ verifyKind7Browser \} from '\.\.\/\.\.\/convert\/xdw\/kind7_browser_test\.mjs';/);
assert.match(compare, /await verifyKind7Browser\(browser,base\);/);
for (const dropped of ['verifyPiano', 'verifyMusicBrowser', 'verifyViewerMusic']) {
  assert.ok(!compare.includes(dropped), `compat/visual/compare.mjs still references ${dropped}`);
}
assert.ok(!compare.includes('piano-baseline.html'), 'compat/visual/compare.mjs still captures the piano fixture');
assert.ok(!compare.includes('piano-moon.html'), 'compat/visual/compare.mjs still captures the piano fixture');

// The negative guard must keep proving that dropped formats are not registered
// or dispatched.
const native = readFileSync(path.join(root, 'compat/converter/native-test.mjs'), 'utf8');
assert.match(native, /for \(const name of \['midi', 'mml', 'musicxml', 'epub', 'gerber', 'kicad'\]\)/);
assert.match(native, /dropped format is still registered/);
assert.match(native, /dropped format is still dispatched/);

console.log(`visual aggregate excludes dropped score/PCB/EPUB checks and keeps audio (${aggregate.length} commands)`);
