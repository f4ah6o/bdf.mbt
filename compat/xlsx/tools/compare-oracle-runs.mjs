// A repeatability gate, separate from the mandatory static migration gate.
import {readdir,readFile,writeFile,realpath} from 'node:fs/promises';
import {parseArgs,isDeepStrictEqual} from 'node:util';
import path from 'node:path';
const {values}=parseArgs({options:{first:{type:'string'},second:{type:'string'},report:{type:'string'}}});
if(!values.first||!values.second||!values.report)throw Error('--first --second --report required');
const a=path.resolve(values.first),b=path.resolve(values.second);
if(await realpath(a)===await realpath(b))throw Error('Distinct run directories required');
const ia=JSON.parse(await readFile(path.join(a,'identity.json'))),ib=JSON.parse(await readFile(path.join(b,'identity.json')));
const keys=['upstream','go','goos','goarch','goamd64','goarm64','goFlags','goExperiment','goWork','goEnv','binarySha256','adapters','seeds','inputSeeds','retainedInputs','tests'];
for(const identity of [ia,ib]){
 if(identity.version!==1||keys.filter(k=>k!=='goarm64').some(k=>!Object.hasOwn(identity,k)))throw Error('Incomplete oracle identity');
 if(identity.upstream!=='a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22'||identity.go!=='go1.27.0'||!['linux','darwin'].includes(identity.goos)||!['amd64','arm64'].includes(identity.goarch))throw Error('Invalid oracle profile');
 if(identity.goarch==='amd64'&&!['v1','v3'].includes(identity.goamd64)||identity.goarch==='arm64'&&identity.goarm64!=='v8.0')throw Error('Invalid arithmetic profile');
 if(identity.goFlags!==''||identity.goExperiment!==''||identity.goWork!=='off'||identity.goEnv!=='off'||! /^[a-f0-9]{64}$/.test(identity.binarySha256))throw Error('Unpinned build identity');
 for(const key of ['adapters','seeds','inputSeeds','retainedInputs'])if(!identity[key]||Array.isArray(identity[key])||typeof identity[key]!=='object'||!Object.keys(identity[key]).length||Object.values(identity[key]).some(v=>typeof v!=='string'||! /^[a-f0-9]{64}$/.test(v)))throw Error('Invalid receipt map');
 if(!Array.isArray(identity.tests)||!identity.tests.length||identity.tests.some(t=>typeof t!=='string'||!/^Test\w+$/.test(t)))throw Error('Invalid adapter test inventory');
}
const identityDifferences=keys.filter(k=>!isDeepStrictEqual(ia[k],ib[k]));
const inventory=async root=>(await readdir(path.join(root,'compat/xlsx'),{recursive:true})).filter(f=>f.endsWith('.json')).sort();
const fa=await inventory(a),fb=await inventory(b);if(!fa.length||!fb.length)throw Error('Empty output inventory');
const result={version:1,identityDifferences,missing:fa.filter(f=>!fb.includes(f)),extra:fb.filter(f=>!fa.includes(f)),different:[],equal:0};
for(const file of fa){if(!fb.includes(file))continue;let x=JSON.parse(await readFile(path.join(a,'compat/xlsx',file))),y=JSON.parse(await readFile(path.join(b,'compat/xlsx',file)));if(isDeepStrictEqual(x,y))result.equal++;else result.different.push(file);}
await writeFile(values.report,JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));
if(identityDifferences.length||result.missing.length||result.extra.length||result.different.length)process.exitCode=1;
