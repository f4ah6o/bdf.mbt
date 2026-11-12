// Strict validation for staging identities and scratch paths shared by the
// packing and smoke tools. The core rule: values that reach a filesystem
// write or delete must never be able to name anything outside this
// repository's generated `_scratch/` areas.
//
// An earlier form accepted `../`, absolute paths and scoped traversal in a
// staging name, resolved it against the scratch root and recursively deleted
// the result. Nothing user-supplied may ever name a deletion target again:
// staging happens in a fresh `mkdtemp` directory inside a fixed,
// tool-owned scratch root, and no code path removes anything else.

import { lstatSync, readdirSync, realpathSync } from "node:fs";
import { dirname, isAbsolute, join, resolve, sep } from "node:path";

///|
// An unscoped npm-style staging name: lowercase alphanumerics with dots,
// hyphens and underscores, not starting with a dot. Refuses empty, "." and
// "..", every slash or backslash (scoped names and traversal like
// "../source" or "@scope/x"), absolute paths, and uppercase.
export function validateStagingName(name) {
  if (typeof name !== "string"
    || name === "" || name === "." || name === ".."
    || name.includes("/") || name.includes("\\") || isAbsolute(name)
    || name.endsWith(".") || !/^[a-z0-9][a-z0-9._-]*$/.test(name)) {
    throw new Error(
      `invalid staging name ${JSON.stringify(String(name))}: use an unscoped lowercase npm-style name without slashes or traversal`,
    );
  }
  return name;
}

///|
// A staging version: dotted identifiers with optional prerelease/build
// suffixes (covers `0.0.0-staging`). Refuses empty strings and any path
// characters, so a version can never move a filename out of the output
// directory.
export function validateStagingVersion(version) {
  if (typeof version !== "string"
    || version === "" || version === "." || version === ".."
    || version.includes("/") || version.includes("\\") || isAbsolute(version)
    || !/^[0-9A-Za-z][0-9A-Za-z.+_-]*$/.test(version)) {
    throw new Error(
      `invalid staging version ${JSON.stringify(String(version))}: use a plain dotted version like 0.0.0-staging`,
    );
  }
  return version;
}

///|
// Every existing path component of a resolved absolute path must be reached
// without symbolic links. `realpathSync` cannot catch the one case that
// matters for a missing output: a parent that is a symlink pointing somewhere
// else INSIDE the allowed root resolves fine, and the write would follow it.
// Walking the components with `lstat` sees the link itself, no matter what it
// points at.
function refuseSymlinkedComponents(resolved, label) {
  const chain = [];
  for (let current = resolved; ;) {
    chain.unshift(current);
    const parent = dirname(current);
    if (parent === current) {
      // the filesystem root anchors the walk
      break;
    }
    current = parent;
  }
  for (const component of chain) {
    let stats;
    try {
      stats = lstatSync(component);
    } catch {
      continue; // absent components are directories the tool creates itself
    }
    if (stats.isSymbolicLink()) {
      throw new Error(`${label} may not travel through or be a symbolic link: ${resolved}`);
    }
  }
}

///|
// A user-supplied directory flag value must name a strict descendant of the
// tool's own repository root (after symbolic-link resolution), and must not
// be a symlink itself. This guards `--out` style flags against traversal,
// absolute paths and symlink escapes, so a tool may never write (let alone
// delete) outside the worktree it owns.
//
// A clean checkout has no `_scratch/` yet, so missing components are
// allowed: the inside-root check anchors on the deepest EXISTING ancestor,
// and any number of missing trailing components may follow — the tool
// creates exactly those directories after validation passes. Validation
// always happens before any directory is created.
export function resolveInsideRoot(value, root, label) {
  if (typeof value !== "string" || value === "") {
    throw new Error(`${label} must be a relative directory inside the repository`);
  }
  const resolved = resolve(root, value);
  refuseSymlinkedComponents(resolved, label);
  const realRoot = realpathSync(root);
  if (resolved === realRoot) {
    throw new Error(`${label} may not be the repository root itself`);
  }
  // walk up to the deepest existing ancestor; missing trailing components
  // are generated directories the tool creates itself after this check
  let anchor = resolved;
  let anchorFound = false;
  for (; ;) {
    try {
      lstatSync(anchor);
      anchorFound = true;
      break;
    } catch {
      const parent = dirname(anchor);
      if (parent === anchor) {
        break; // the filesystem root is missing: nothing to anchor on
      }
      anchor = parent;
    }
  }
  if (anchorFound) {
    const real = realpathSync(anchor);
    if (real !== realRoot && !real.startsWith(realRoot + sep)) {
      throw new Error(`${label} must stay inside the repository root: ${value}`);
    }
    if (real !== anchor) {
      // reached only through a symlinked component; refuse regardless of
      // the destination, so a planted link can never redirect a tool
      throw new Error(`${label} may not travel through or be a symbolic link: ${value}`);
    }
  }
  return resolved;
}

///|
// An output file destination before it is written: every existing component
// of its path must be symlink-free, and the destination itself must be
// absent or a plain regular file. An earlier generated output may be
// replaced (that is what repacking does); a directory, a device or a
// planted symlink may not be — `cpSync` would silently replace a link and
// `writeFileSync` would follow it, so both are refused here the same way.
//
// A regular file with more than one hard link is also refused: writing it
// truncates a shared inode, so an unrelated file elsewhere would be silently
// replaced. Outputs of this tool are always freshly linked single files.
export function assertWritableOutput(destination, label) {
  const resolved = resolve(destination);
  refuseSymlinkedComponents(resolved, label);
  let stats;
  try {
    stats = lstatSync(resolved);
  } catch {
    // the destination does not exist yet: the tool creates it
    return resolved;
  }
  if (!stats.isFile()) {
    throw new Error(`${label} exists and is not a regular file, refusing to replace it: ${resolved}`);
  }
  if (stats.nlink > 1) {
    throw new Error(`${label} is a hard-linked file, refusing to overwrite the shared inode: ${resolved}`);
  }
  return resolved;
}

///|
// Staging sources must be real files. A symbolic link in a source tree is an
// explicit error, not a silently-copied link or a silently-missing artifact:
// the packed output must be exactly what the build produced.
export function refuseSymlinkedSource(fsPath, label) {
  let stats;
  try {
    stats = lstatSync(fsPath);
  } catch {
    return; // existence is the caller's error to report
  }
  if (stats.isSymbolicLink()) {
    throw new Error(`${label} is a symbolic link, refusing to stage it: ${fsPath}`);
  }
  if (stats.isDirectory()) {
    for (const entry of readdirSync(fsPath, { withFileTypes: true })) {
      refuseSymlinkedSource(join(fsPath, entry.name), label);
    }
  }
}
