// Run `moon test`, `moon check` or `moon build` for the packages that remain in
// the maintained porting scope.
//
// PCB (Gerber/Excellon, KiCad), score (MIDI, MML, MusicXML) and EPUB were
// dropped from the scope. Their converters, compat harnesses and fixtures stay
// in the tree as dormant assets, so a bare `moon test`/`moon check`/`moon build`
// still covers them. CI requires this selection instead, and treats the dormant
// packages as unmaintained rather than as covered.
//
//   node compat/retained-test.mjs                     # test, js + wasm-gc + native
//   node compat/retained-test.mjs js                  # test, one target
//   node compat/retained-test.mjs --mode check js     # moon check
//   node compat/retained-test.mjs --mode build --release js
//   node compat/retained-test.mjs --list js           # print the selection
//
// `moon test` selects packages by name (`-p`), while `moon check` and
// `moon build` take package directory paths. Both forms are built here.
//
// Selection is not isolation: a retained package that imports a dormant one
// still compiles it. `dormantDependents()` reports those packages so the gap is
// visible instead of being mistaken for full exclusion.
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

/** The commands this selector can run. */
export const MODES = ["test", "check", "build"];

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

/** Retained package directories that build for `target`. */
export function retainedPaths(target) {
  return packages()
    .filter((path) => !DORMANT.includes(path))
    .filter((path) => target === undefined || supportedTargets(path).includes(target))
    .sort();
}

/** Retained packages that build for `target`, as `-p` package names. */
export function retainedPackages(target) {
  return retainedPaths(target).map((path) => "f4ah6o/bdf/" + path);
}

/**
 * The `moon` arguments for one mode and target. `test` selects by package name,
 * `check` and `build` by package directory path.
 */
export function moonArgs({ mode = "test", target, release = false } = {}) {
  if (!MODES.includes(mode)) throw new Error(`unknown mode: ${mode}`);
  if (!TARGETS.includes(target)) throw new Error(`unknown target: ${target}`);
  const args = [mode, "--target", target];
  if (release) args.push("--release");
  if (mode === "test") {
    for (const name of retainedPackages(target)) args.push("-p", name);
  } else {
    args.push(...retainedPaths(target));
  }
  return args;
}

/**
 * Retained packages that import a dormant one. Their compilation still covers
 * the dormant package, so the selection cannot hide a broken out-of-scope
 * feature that a retained package depends on.
 */
export function dormantDependents() {
  const dormant = new Set(DORMANT);
  const found = [];
  for (const path of retainedPaths()) {
    const text = readFileSync(join(root, path, "moon.pkg"), "utf8");
    const imports = [...text.matchAll(/"f4ah6o\/bdf\/([^"]+)"/g)]
      .map((match) => match[1])
      .filter((name) => dormant.has(name));
    if (imports.length > 0) found.push({ package: path, imports: [...new Set(imports)].sort() });
  }
  return found;
}

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
    for (const path of retainedPaths(target)) {
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

/** Parse the CLI arguments. Unknown flags are an error, not a silent default. */
export function parseArgs(argv) {
  const options = { mode: "test", release: false, list: false, targets: [] };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--list") {
      options.list = true;
    } else if (arg === "--release") {
      options.release = true;
    } else if (arg === "--mode") {
      index += 1;
      const mode = argv[index];
      if (!MODES.includes(mode)) throw new Error(`--mode must be one of ${MODES.join(", ")}`);
      options.mode = mode;
    } else if (arg.startsWith("--")) {
      throw new Error(`unknown option: ${arg}`);
    } else {
      if (!TARGETS.includes(arg)) throw new Error(`unknown target: ${arg}`);
      options.targets.push(arg);
    }
  }
  return options;
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  const selected = options.targets.length > 0 ? options.targets : TARGETS;
  const counts = verify();
  if (options.list) {
    for (const target of selected) {
      for (const path of retainedPaths(target)) console.log(`${target} f4ah6o/bdf/${path}`);
    }
    return;
  }
  console.log(`${counts.total} packages: ${counts.retained} retained, ${counts.dormant} dormant`);
  const dependents = dormantDependents();
  if (dependents.length > 0) {
    console.log(
      `note: ${dependents.length} retained package(s) import dormant packages and still compile them: ` +
        dependents.map((entry) => entry.package).join(", "),
    );
  }
  for (const target of selected) {
    const args = moonArgs({ mode: options.mode, target, release: options.release });
    const count = options.mode === "test" ? retainedPackages(target).length : retainedPaths(target).length;
    console.log(`moon ${args[0]} --target ${target} over ${count} retained packages`);
    const result = spawnSync("moon", args, { cwd: root, stdio: "inherit" });
    if (result.error) throw result.error;
    if (result.status !== 0) process.exit(result.status ?? 1);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
