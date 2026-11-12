// Planning audit only. This does not select fixtures or alter either verifier.
import{readFile}from'node:fs/promises';import{createHash}from'node:crypto';import{loadFixture}from'../fixtures.mjs';
const manifest=JSON.parse(await readFile(new URL('./notes-static-proposal.manifest',import.meta.url)));
if(manifest.version!==1||manifest.status!=='proposal-not-active'||manifest.upstream!=='a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22')throw Error('Invalid proposal');
const seen=new Set();let cases=0,bytes=0;
for(const entry of manifest.files){if(!/^sheet-multiple-notes(?:-filter|-legacy)?\.json$/.test(entry.file)||seen.has(entry.file))throw Error('Invalid/duplicate proposal file');seen.add(entry.file);const data=await loadFixture('./'+entry.file),text=JSON.stringify(data);if(data.length!==entry.cases||Buffer.byteLength(text)!==entry.serializedBytes||createHash('sha256').update(text).digest('hex')!==entry.sha256)throw Error('Static proposal no longer matches retained fixtures');cases+=data.length;bytes+=Buffer.byteLength(text);}
if(seen.size!==3)throw Error('Incomplete notes proposal');console.log(JSON.stringify({proposalOnly:true,files:seen.size,cases,serializedBytes:bytes,active:false}));
