// Pure release identity validation. Creating a tarball never publishes it.
export function releaseMetadata(args, name) {
  const index = args.indexOf("--release-version");
  const sourceIndex = args.indexOf("--source-sha");
  if (index === -1) {
    if (sourceIndex !== -1) throw new Error("--source-sha requires --release-version");
    return null;
  }
  if (args.filter(value => value === "--release-version").length !== 1
      || args.filter(value => value === "--source-sha").length !== 1) {
    throw new Error("release version and source SHA must each be supplied once");
  }
  const version = args[index + 1];
  const sha = args[sourceIndex + 1];
  if (name !== "bdf.mbt" || args.includes("--staging-version")) {
    throw new Error("release mode requires bdf.mbt and no staging version override");
  }
  if (!/^[1-9][0-9]{3}\.(?:[1-9]|1[0-2])\.(?:0|[1-9][0-9]*)$/.test(version ?? "")) {
    throw new Error("release version must use YYYY.MM.PATCH without zero padding");
  }
  if (!/^[0-9a-f]{40}$/.test(sha ?? "")) throw new Error("release requires a full lowercase source SHA");
  return {
    version, private: false,
    repository: { type: "git", url: "git+https://github.com/f4ah6o/bdf.mbt.git" },
    homepage: "https://github.com/f4ah6o/bdf.mbt",
    publishConfig: { access: "public", registry: "https://registry.npmjs.org/" },
    gitHead: sha,
  };
}
