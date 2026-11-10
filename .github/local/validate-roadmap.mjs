#!/usr/bin/env node
// Deterministic validation for docs/roadmap.md and issues/open/*.md.
//
// The docs worktree is sparse: it contains docs/, issues/ and .github/local/
// only. File references are therefore checked against the fixed base commit
// (ROADMAP_BASE, default b05cd93) as well as the working tree. No network
// access is used; external links are only checked for an https scheme.
//
// Usage: node .github/local/validate-roadmap.mjs
// Exit: 0 when every check passes, 1 otherwise.

import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, join, normalize, resolve } from 'node:path';

const ROOT = process.cwd();
const BASE = process.env.ROADMAP_BASE ?? 'b05cd93';
const ROADMAP = 'docs/roadmap.md';
const ISSUES_DIR = 'issues/open';
const STATUSES = new Set(['open', 'done', 'superseded']);
const REQUIRED_SECTIONS = [
  'Status vocabulary',
  'Definition of done',
  'Scope',
  'Work in flight',
  'Targets',
  'Milestones',
  'Verification gates',
  'Issue index',
  'Risks',
];

const failures = [];
const checks = [];

function fail(message) {
  failures.push(message);
}

function check(name, fn) {
  const before = failures.length;
  try {
    fn();
  } catch (error) {
    fail(`${name}: ${error.message}`);
  }
  checks.push({ name, ok: failures.length === before });
}

function read(path) {
  return readFileSync(join(ROOT, path), 'utf8');
}

function baseTree() {
  let out;
  try {
    out = execFileSync('git', ['ls-tree', '-r', '--name-only', BASE], {
      cwd: ROOT,
      encoding: 'utf8',
    });
  } catch (error) {
    throw new Error(`cannot read base commit ${BASE}: ${error.message}`);
  }
  const files = new Set(out.split('\n').filter(Boolean));
  const dirs = new Set();
  for (const file of files) {
    const parts = file.split('/');
    for (let i = 1; i < parts.length; i += 1) {
      dirs.add(parts.slice(0, i).join('/'));
    }
  }
  return { files, dirs };
}

const tree = baseTree();

function existsInRepo(path) {
  const clean = normalize(path).replace(/^\.\//, '').replace(/\/$/, '');
  if (clean === '' || clean === '.') return true;
  if (existsSync(join(ROOT, clean))) return true;
  return tree.files.has(clean) || tree.dirs.has(clean);
}

function issueFiles() {
  return readdirSync(join(ROOT, ISSUES_DIR))
    .filter((name) => name.endsWith('.md'))
    .sort();
}

function issueSlug(name) {
  return name.replace(/\.md$/, '');
}

function parseHeader(text) {
  const header = {};
  for (const line of text.split('\n').slice(0, 12)) {
    const match = /^([A-Za-z]+):\s*(.*)$/.exec(line);
    if (match) header[match[1]] = match[2].trim();
  }
  return header;
}

function section(text, heading) {
  const start = text.indexOf(`## ${heading}`);
  if (start === -1) return '';
  const rest = text.slice(start + heading.length + 3);
  const end = rest.search(/^## /m);
  return end === -1 ? rest : rest.slice(0, end);
}

function tableRows(text) {
  return text
    .split('\n')
    .filter((line) => line.startsWith('|') && !/^\|\s*-+/.test(line))
    .map((line) => line.split('|').slice(1, -1).map((cell) => cell.trim()))
    .filter((cells) => cells.length > 0);
}

function backticked(text) {
  return [...text.matchAll(/`([^`\n]+)`/g)].map((match) => match[1]);
}

function markdownLinks(text) {
  return [...text.matchAll(/\[[^\]]*\]\(([^)\s]+)\)/g)].map((match) => match[1]);
}

function stripLineSuffix(token) {
  return token.replace(/:\d+$/, '');
}

function isConcreteRepoPath(token) {
  const path = stripLineSuffix(token);
  if (path.includes('*') || path.includes('{') || path.includes('}')) return false;
  if (path.includes(' ') || path.includes('<') || path.includes('>')) return false;
  return (
    /^docs\/[A-Za-z0-9._/-]+\.md$/.test(path) ||
    /^issues\/open\/[A-Za-z0-9._/-]+\.md$/.test(path) ||
    /^\.github\/(workflows|local)\/[A-Za-z0-9._/-]+\.(yml|mjs)$/.test(path) ||
    /^compat\/[A-Za-z0-9._/-]+\.(mjs|md)$/.test(path) ||
    /^convert\/[A-Za-z0-9._/-]+\.(mbt|pkg)$/.test(path) ||
    /^browser\/[A-Za-z0-9._/-]+\.mbt$/.test(path) ||
    /^site\/[A-Za-z0-9._/-]+\.(md|mjs)$/.test(path) ||
    /^licenses\/[A-Za-z0-9._/-]+$/.test(path) ||
    /^(moon\.mod|package\.json|package-lock\.json|README\.md|CHANGES\.md)$/.test(path)
  );
}

const roadmap = read(ROADMAP);
const issues = issueFiles();
const issueTexts = new Map(issues.map((name) => [name, read(join(ISSUES_DIR, name))]));

check('roadmap exists and has the required sections', () => {
  for (const heading of REQUIRED_SECTIONS) {
    if (!roadmap.includes(`## ${heading}`)) fail(`missing section: ${heading}`);
  }
});

check('status vocabulary is complete', () => {
  const vocabulary = section(roadmap, 'Status vocabulary');
  for (const status of STATUSES) {
    if (!vocabulary.includes(`\`${status}\``)) fail(`status vocabulary omits ${status}`);
  }
});

check('every issue has a valid header', () => {
  for (const name of issues) {
    const header = parseHeader(issueTexts.get(name));
    for (const field of ['Status', 'Created', 'Updated', 'Branch']) {
      if (!header[field]) fail(`${name}: missing ${field}`);
    }
    if (header.Status && !STATUSES.has(header.Status)) {
      fail(`${name}: unknown status ${header.Status}`);
    }
    for (const field of ['Created', 'Updated']) {
      if (header[field] && !/^\d{4}-\d{2}-\d{2}$/.test(header[field])) {
        fail(`${name}: ${field} is not YYYY-MM-DD`);
      }
    }
    if (header.Created && header.Updated && header.Updated < header.Created) {
      fail(`${name}: Updated is before Created`);
    }
  }
});

check('acceptance checkboxes match the status', () => {
  for (const name of issues) {
    const text = issueTexts.get(name);
    const status = parseHeader(text).Status;
    const unchecked = (text.match(/^- \[ \]/gm) ?? []).length;
    const checked = (text.match(/^- \[x\]/gm) ?? []).length;
    if (status === 'done' && unchecked > 0) {
      fail(`${name}: done but has ${unchecked} unchecked acceptance item(s)`);
    }
    if (status === 'open' && checked + unchecked > 0 && unchecked === 0) {
      fail(`${name}: open but has no unchecked acceptance item`);
    }
  }
});

check('issue index covers every issue exactly once', () => {
  const index = section(roadmap, 'Issue index');
  const rows = tableRows(index).filter(
    (cells) => cells.length >= 4 && cells[0] !== 'Milestone',
  );
  const slugs = rows.map((cells) => {
    const match = /^`([^`]+)`$/.exec(cells[1]);
    return match ? match[1] : null;
  });
  const seen = new Set();
  for (const slug of slugs) {
    if (!slug) {
      fail(`issue index row has no backticked slug: ${JSON.stringify(rows)}`);
      continue;
    }
    if (seen.has(slug)) fail(`issue index lists ${slug} more than once`);
    seen.add(slug);
    if (!issues.includes(`${slug}.md`)) fail(`issue index lists missing file ${slug}.md`);
  }
  for (const name of issues) {
    const slug = issueSlug(name);
    if (!seen.has(slug)) fail(`issue index omits ${slug}`);
  }
});

check('issue index status matches the issue file', () => {
  const index = section(roadmap, 'Issue index');
  for (const cells of tableRows(index)) {
    if (cells.length < 4 || cells[0] === 'Milestone') continue;
    const match = /^`([^`]+)`$/.exec(cells[1]);
    if (!match) continue;
    const slug = match[1];
    const file = `${slug}.md`;
    if (!issues.includes(file)) continue;
    const indexStatus = cells[3].split(':')[0].trim();
    const fileStatus = parseHeader(issueTexts.get(file)).Status;
    if (indexStatus !== fileStatus) {
      fail(`${slug}: index status ${indexStatus} != file status ${fileStatus}`);
    }
  }
});

check('work in flight separates PR state from implementation', () => {
  const table = section(roadmap, 'Work in flight');
  const rows = tableRows(table);
  if (rows.length === 0) {
    fail('work in flight table is empty');
    return;
  }
  const header = rows[0].map((cell) => cell.toLowerCase());
  for (const column of ['pr', 'branch', 'pr state', 'implementation in main']) {
    if (!header.some((cell) => cell.includes(column))) {
      fail(`work in flight table has no ${column} column`);
    }
  }
  for (const pr of ['#6', '#7', '#8', '#9', '#10', '#11']) {
    if (!table.includes(pr)) fail(`work in flight table omits ${pr}`);
  }
});

check('verification gates use local actrun and keep Pages manual', () => {
  const gates = section(roadmap, 'Verification gates');
  if (!gates.includes('actrun')) fail('verification gates do not mention actrun');
  if (!gates.includes('npm run verify:local')) {
    fail('verification gates do not mention npm run verify:local');
  }
  if (!gates.includes('GitHub never runs the verification')) {
    fail('verification gates do not state that GitHub never runs the verification workflows');
  }
  if (!gates.includes('pages-deploy.yml')) fail('verification gates omit pages-deploy.yml');
  if (!gates.includes('workflow_dispatch')) {
    fail('verification gates do not describe the manual Pages trigger');
  }
  if (!gates.includes('never runs or\ndispatches it')) {
    fail('verification gates do not state that the local flow never runs the Pages deployment');
  }
});

check('historical measurements are labelled', () => {
  const m1 = section(roadmap, 'M1 — native target');
  if (!m1.includes('historical')) fail('M1 does not label its measurements as historical');
  if (!roadmap.includes('historical fixed-head')) {
    fail('roadmap does not use the phrase historical fixed-head');
  }
  if (/\blatest\b/i.test(roadmap)) fail('roadmap claims a latest run');
});

check('backticked issue references resolve', () => {
  const texts = [roadmap, ...issueTexts.values()];
  for (const text of texts) {
    for (const token of backticked(text)) {
      const match = /^(\d{8}-[a-z0-9-]+)(?:\.md)?$/.exec(token);
      if (!match) continue;
      if (!issues.includes(`${match[1]}.md`)) {
        fail(`reference to missing issue ${match[1]}`);
      }
    }
  }
});

check('concrete repo paths resolve', () => {
  const texts = [roadmap, ...issueTexts.values()];
  for (const text of texts) {
    for (const token of backticked(text)) {
      if (!isConcreteRepoPath(token)) continue;
      const path = stripLineSuffix(token);
      if (!existsInRepo(path)) fail(`missing repo path ${path}`);
    }
  }
});

check('relative markdown links resolve', () => {
  const files = [ROADMAP, ...issues.map((name) => join(ISSUES_DIR, name))];
  for (const file of files) {
    const text = read(file);
    for (const link of markdownLinks(text)) {
      if (/^(https?:|mailto:|#)/.test(link)) {
        if (link.startsWith('http:') || link.startsWith('mailto:')) {
          fail(`${file}: link must use https: ${link}`);
        }
        continue;
      }
      const target = link.split('#')[0];
      if (!target) continue;
      const candidates = [
        resolve(ROOT, target),
        resolve(ROOT, dirname(file), target),
      ];
      if (!candidates.some((candidate) => existsSync(candidate))) {
        fail(`${file}: relative link does not resolve: ${link}`);
      }
    }
  }
});

check('external links are https', () => {
  const files = [ROADMAP, ...issues.map((name) => join(ISSUES_DIR, name))];
  for (const file of files) {
    for (const link of markdownLinks(read(file))) {
      if (/^https?:\/\//.test(link) && !link.startsWith('https://')) {
        fail(`${file}: external link is not https: ${link}`);
      }
    }
  }
});

check('no issue file is empty', () => {
  for (const name of issues) {
    const text = issueTexts.get(name);
    if (text.trim().length < 200) fail(`${name}: file is suspiciously short`);
    if (!text.includes('## 概要')) fail(`${name}: missing 概要 section`);
    if (!text.includes('## 受け入れ条件')) fail(`${name}: missing 受け入れ条件 section`);
  }
});

const failed = failures.length > 0;
for (const { name, ok } of checks) {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${name}`);
}
if (failed) {
  console.error(`\n${failures.length} failure(s):`);
  for (const message of failures) console.error(`- ${message}`);
  process.exit(1);
}
console.log(`\nvalidated ${issues.length} issues against ${BASE}`);
