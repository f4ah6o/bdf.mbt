// 上流 BDF のベンチマーク（docs/benchmarks/latest.json）を取り直して
// site/benchmarks/upstream.json に置く。bdf.mbt の計測は site/benchmark.mjs が
// site/benchmarks/bdfmbt.json に書き、トップページで 1 つの表にまとめる。
//
//   npm run bench:upstream
import { writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const output = resolve(import.meta.dirname, "benchmarks/upstream.json");
const repo = "https://raw.githubusercontent.com/shibukawa/bdf/main";
const [commit, latest] = await Promise.all([
  fetch("https://api.github.com/repos/shibukawa/bdf/commits/main").then((response) => response.json()).then((data) => data.sha),
  fetch(repo + "/docs/benchmarks/latest.json").then((response) => {
    if (!response.ok) throw new Error("latest.json: HTTP " + response.status);
    return response.json();
  }),
]);
const payload = {
  source: {
    repository: "https://github.com/shibukawa/bdf",
    path: "docs/benchmarks/latest.json",
    commit,
    url: repo + "/docs/benchmarks/latest.json",
    fetchedAt: new Date().toISOString(),
  },
  ...latest,
};
await writeFile(output, JSON.stringify(payload, null, 2) + "\n");
console.log("upstream benchmarks: " + Object.keys(payload.process.results).length + " cases at " + commit.slice(0, 7));
console.log("wrote " + output);
