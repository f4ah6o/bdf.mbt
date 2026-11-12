#!/usr/bin/env python3
"""Build pinned upstream XLSX adapters in a disposable tree, never in a checkout.

This is the migration-stage builder, not a replacement for test:xlsx-compat yet.
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile

UPSTREAM = 'a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22'
GO_VERSION = 'go1.27.0'
p = argparse.ArgumentParser()
p.add_argument('--upstream', required=True, help='local git repository containing pinned upstream')
p.add_argument('--go', required=True, help='Go 1.27.0 executable')
p.add_argument('--output', required=True, help='new build directory')
p.add_argument('--goos', choices=['linux', 'darwin'], default='linux')
p.add_argument('--goarch', choices=['amd64', 'arm64'], required=True)
p.add_argument('--goamd64', choices=['v1', 'v3'], default='v1')
a = p.parse_args()
a.go = str(Path(a.go).resolve())
out = Path(a.output).resolve()
if out.exists(): raise SystemExit('Output must not exist; do not reuse an unverified build')
version = subprocess.check_output([a.go, 'version'], text=True).strip()
if version.split()[2] != GO_VERSION: raise SystemExit(f'Expected {GO_VERSION}, got {version}')
commit = subprocess.check_output(['git', '-C', a.upstream, 'rev-parse', UPSTREAM + '^{commit}'], text=True).strip()
if commit != UPSTREAM: raise SystemExit('Upstream SHA mismatch')
archive = subprocess.check_output(['git', '-C', a.upstream, 'archive', '--format=tar', UPSTREAM])
fixtures = Path(__file__).resolve().parent.parent
adapters = []
for source in sorted(fixtures.glob('generate*.go')):
    raw = source.read_bytes()
    text = raw.decode('utf8')
    if re.search(r'^package xlsx\s*$', text, re.M):
        adapters.append((source, text, hashlib.sha256(raw).hexdigest()))
if not adapters: raise SystemExit('No XLSX adapters')
out.mkdir(parents=True)
try:
    with tempfile.TemporaryDirectory(prefix='bdf-xlsx-oracle-') as temp:
        source_root = Path(temp)
        with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
            tar.extractall(source_root, filter='data')
        for source, text, _ in adapters:
            (source_root / 'converter/xlsx' / source.name).write_text(text.replace('//go:build ignore\n', '', 1))
        env = dict(os.environ, GOTOOLCHAIN='local', GOOS=a.goos, GOARCH=a.goarch,
                   GOAMD64=a.goamd64, CGO_ENABLED='0', GOMAXPROCS='2',
                   GOFLAGS='', GOEXPERIMENT='', GOWORK='off', GOENV='off')
        subprocess.run([a.go, 'test', '-mod=readonly', '-p=2', '-trimpath', '-c',
                        './converter/xlsx', '-o', str(out / 'xlsx-oracle.test')],
                       cwd=source_root, env=env, check=True)
        # Real upstream seeds are needed even with a prebuilt executable.
        import shutil
        for part in ['xlsx', 'image']:
            shutil.copytree(source_root / f'converter/{part}/testdata', out / f'runtime/{part}/testdata')
    sha = lambda data: hashlib.sha256(data).hexdigest()
    record = {'version': 1, 'upstream': UPSTREAM, 'go': GO_VERSION,
              'goFlags': '', 'goExperiment': '', 'goWork': 'off', 'goEnv': 'off',
              'goos': a.goos, 'goarch': a.goarch, 'goamd64': a.goamd64 if a.goarch == 'amd64' else None,
              'binarySha256': sha((out / 'xlsx-oracle.test').read_bytes()),
              'adapters': {source.name: digest for source, _, digest in adapters},
              'seeds': {str(file.relative_to(out)): sha(file.read_bytes())
                        for file in sorted((out / 'runtime').rglob('*')) if file.is_file()}}
    (out / 'identity.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({'output': str(out), 'upstream': UPSTREAM, 'adapters': len(adapters),
                      'binarySha256': record['binarySha256']}))
except Exception:
    # Preserve incomplete artifacts for investigation, but never write identity.
    raise
