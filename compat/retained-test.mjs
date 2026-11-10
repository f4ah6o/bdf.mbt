// Run `moon test` for the packages that remain in the maintained porting
// scope.
//
// PCB (Gerber/Excellon, KiCad), score (MIDI, MML, MusicXML) and EPUB were
// dropped from the scope. Their converters, compat harnesses and fixtures stay
// in the tree as dormant assets, so a bare `moon test` still builds and runs
// them. CI should require this selection instead, and treat the dormant
// packages as unmaintained rather than as covered.
//
//   node compat/retained-test.mjs            # js, wasm-gc and native
//   node compat/retained-test.mjs js         # one target
import { spawnSync } from "node:child_process";
import { lstatSync, readFileSync, readdirSync } from "node:fs";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const root = resolve(import.meta.dirname, "..");

/** Packages kept only as historical assets; they are not maintained. */
export const DORMANT = [
  "convert/epub",
  "convert/gerber",
  "convert/kicad",
  "convert/midi",
  "convert/mml",
  "convert/music",
  "convert/musicxml",
  "compat/midiinput",
  "compat/mml",
  "compat/musicnotation",
  "compat/musicxml",
  "compat/size/pdf_epub",
];

/** Every target this module builds for. */
export const TARGETS = ["js", "wasm-gc", "native"];

/** Directories that never hold a package of this module. */
const SKIP = new Set(["node_modules"]);

/**
 * Whether a directory entry is walked. Generated and ignored trees (`.git`,
 * `.moon-home`, `.mooncakes`, `.upstream`, `_build`, `_scratch`, ...) are
 * skipped by their leading dot or underscore, and symlinks are never followed,
 * so a link loop or a checkout outside the module cannot add packages.
 */
function walkable(entry) {
  return !SKIP.has(entry) && !entry.startsWith(".") && !entry.startsWith("_");
}

/** Every MoonBit package directory in this module, as a module-relative path. */
export function packages(dir = root, prefix = "") {
  const found = [];
  for (const entry of readdirSync(dir)) {
    if (!walkable(entry)) continue;
    const path = join(dir, entry);
    const stat = lstatSync(path);
    if (stat.isSymbolicLink() || !stat.isDirectory()) continue;
    const relative = prefix === "" ? entry : prefix + "/" + entry;
    if (readdirSync(path).includes("moon.pkg")) found.push(relative);
    found.push(...packages(path, relative));
  }
  return found;
}

/**
 * The targets a package declares in its `moon.pkg`. The value is a list of
 * `+name` additions and `-name` removals, where `all` stands for every target;
 * `+js+wasm-gc` and `js + native` are both accepted.
 */
export function supportedTargets(path) {
  const text = readFileSync(join(root, path, "moon.pkg"), "utf8");
  const match = text.match(/supported_targets\s*=\s*"([^"]*)"/);
  // No declaration means the module default, `+js+wasm-gc+native`.
  if (!match) return [...TARGETS];
  const set = new Set();
  for (const token of match[1].match(/[+-]?[A-Za-z0-9_-]+/g) ?? []) {
    const remove = token.startsWith("-");
    const name = token.replace(/^[+-]/, "");
    if (name === "all") {
      if (remove) set.clear();
      else for (const target of TARGETS) set.add(target);
    } else if (remove) {
      set.delete(name);
    } else {
      set.add(name);
    }
  }
  return [...set];
}

/** Retained packages that build for `target`. */
export function retainedPackages(target) {
  return packages()
    .filter((path) => !DORMANT.includes(path))
    .filter((path) => target === undefined || supportedTargets(path).includes(target))
    .sort()
    .map((path) => "f4ah6o/bdf/" + path);
}

const PREFIX = "f4ah6o/bdf/";

/**
 * Check that the selection is complete before anything runs: every package in
 * the module is either dormant or retained for at least one target, no dormant
 * package is selected, and every name in `DORMANT` still exists. Throws rather
 * than silently testing less than intended.
 */
export function verify(targets = TARGETS) {
  const all = packages().sort();
  const dormant = new Set(DORMANT);
  const retained = all.filter((path) => !dormant.has(path));
  const covered = new Set();
  for (const target of targets) {
    for (const name of retainedPackages(target)) {
      const path = name.slice(PREFIX.length);
      if (dormant.has(path)) throw new Error(`dormant package selected for ${target}: ${path}`);
      covered.add(path);
    }
  }
  const omitted = retained.filter((path) => !covered.has(path));
  if (omitted.length > 0) {
    throw new Error(`retained packages omitted from every target: ${omitted.join(", ")}`);
  }
  const unknown = DORMANT.filter((path) => !all.includes(path));
  if (unknown.length > 0) {
    throw new Error(`dormant packages that no longer exist: ${unknown.join(", ")}`);
  }
  return { total: all.length, dormant: DORMANT.length, retained: retained.length };
}

function main() {
  const args = process.argv.slice(2);
  const list = args.includes("--list");
  const targets = args.filter((arg) => !arg.startsWith("--"));
  const selected = targets.length > 0 ? targets : TARGETS;
  const counts = verify();
  if (list) {
    for (const target of selected) {
      for (const name of retainedPackages(target)) console.log(`${target} ${name}`);
    }
    return;
  }
  console.log(
    `${counts.total} packages: ${counts.retained} retained, ${counts.dormant} dormant`,
  );
  for (const target of selected) {
    const packages = retainedPackages(target);
    if (packages.length === 0) throw new Error(`no retained packages for ${target}`);
    const moonArgs = ["test", "--target", target];
    for (const name of packages) moonArgs.push("-p", name);
    console.log(`moon test --target ${target} over ${packages.length} retained packages`);
    const result = spawnSync("moon", moonArgs, { cwd: root, stdio: "inherit" });
    if (result.error) throw result.error;
    if (result.status !== 0) process.exit(result.status ?? 1);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
