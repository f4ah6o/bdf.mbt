import { readdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

for (const directory of ['../ooxml/', './']) {
  const dir = new URL(directory, import.meta.url);
  const scripts = readdirSync(dir).filter(name => /^verify-.+\.mjs$/.test(name) && name !== 'verify-all.mjs').sort();
  for (const script of scripts) {
    const file = fileURLToPath(new URL(script, dir));
    process.stdout.write(`Checking ${directory}${script}\n`);
    const result = spawnSync(process.execPath, [file], { stdio: 'inherit' });
    if (result.error) throw result.error;
    if (result.status !== 0) process.exit(result.status ?? 1);
  }
}
