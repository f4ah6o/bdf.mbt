import { appendFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

// 2026.11.0 is reserved by the approved npm staged bootstrap, not a release.
export function selectReleaseVersion(allocated) {
  if (!/^[1-9][0-9]{3}\.(?:[1-9]|1[0-2])\.(?:0|[1-9][0-9]*)$/.test(allocated ?? '')) {
    throw new Error('Expected a semver-compatible CalVer allocation');
  }
  return allocated === '2026.11.0' ? '2026.11.1' : allocated;
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const version = selectReleaseVersion(process.argv[2]);
  if (!process.env.GITHUB_OUTPUT) throw new Error('GITHUB_OUTPUT is required');
  appendFileSync(process.env.GITHUB_OUTPUT, `version=${version}\ntag=${version}\n`);
}
