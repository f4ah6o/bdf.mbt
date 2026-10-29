///|
#external
priv type NativeFontDirectory

///|
// The upstream browser converter caches font directories by URL. This adapter
// currently downloads each indexed SFNT file whole; the Go runtime uses ranges.
extern "js" fn native_font_directory(
  url : String,
) -> @js_async.Promise[NativeFontDirectory] =
  #|async (url) => {
  #| const key=Symbol.for('f4ah6o.bdf.nativeFontDirectories');const cache=globalThis[key]??=new Map();
  #| if(cache.has(url))return cache.get(url);
  #| const load=(async()=>{let base=url.endsWith('/')?url:url+'/';let baseURL;
  #|   try{baseURL=new URL(base,globalThis.location?.href)}catch(e){return {ok:false,error:`fonts: font directory URL: ${e.message}`}}
  #|   let response,body;try{response=await fetch(base+'index.json');body=await response.arrayBuffer()}catch(e){return {ok:false,error:`fonts: fetch ${base}index.json: JavaScript error: ${e.message}`}}
  #|   if(response.status!==200)return {ok:false,error:`fonts: ${base}index.json: HTTP ${response.status}`};
  #|   let index;try{index=JSON.parse(new TextDecoder().decode(body))}catch(e){return {ok:false,error:`fonts: ${base}index.json: ${e.message}`}}
  #|   if(index===null)index=[];if(!Array.isArray(index))return {ok:false,error:`fonts: ${base}index.json: expected an array`};
  #|   const entries=new Map(), parsed=[];
  #|   const jsonType=value=>Array.isArray(value)?'array':typeof value==='boolean'?'bool':typeof value==='object'?'object':typeof value;
  #|   for(const [i,entry] of index.entries()){
  #|     if(entry===null)continue;if(typeof entry!=='object'||Array.isArray(entry))return {ok:false,error:`fonts: ${base}index.json: invalid font entry`};
  #|     const values={name:'',url:'',size:0,scan:null};
  #|     for(const [key,value] of Object.entries(entry)){
  #|       const field=key.toLowerCase();if(!Object.hasOwn(values,field)||value===null)continue;
  #|       const kind=field==='size'?'number':field==='scan'?'array':'string', goType=field==='size'?'int64':field==='scan'?'[][2]int64':'string';
  #|       if((kind==='array'?!Array.isArray(value):typeof value!==kind)||kind==='number'&&!Number.isSafeInteger(value)){
  #|         const badType=kind==='number'&&typeof value==='number'?`number ${value}`:jsonType(value);
  #|         return {ok:false,error:`fonts: ${base}index.json: json: cannot unmarshal ${badType} into Go struct field .${i}.${key} of type ${goType}`};
  #|       }
  #|       if(field==='scan')for(const [j,range] of value.entries()){
  #|         if(range!==null&&!Array.isArray(range))return {ok:false,error:`fonts: ${base}index.json: json: cannot unmarshal ${jsonType(range)} into .${i}.${key}.${j} of type [2]int64`};
  #|         if(range)for(const [k,n] of range.slice(0,2).entries())if(n!==null&&(typeof n!=='number'||!Number.isSafeInteger(n))){
  #|           const badType=typeof n==='number'?`number ${n}`:jsonType(n);
  #|           return {ok:false,error:`fonts: ${base}index.json: json: cannot unmarshal ${badType} into .${i}.${key}.${j}.${k} of type int64`};
  #|         }
  #|       }
  #|       values[field]=value;
  #|     }
  #|     parsed.push(values);
  #|   }
  #|   for(const {name,url:ref,size} of parsed){
  #|     if(!name||name==='.'||name==='..'||name.includes('/')||size<=0)continue;
  #|     let source=base+name;
  #|     if(ref){try{if(/%(?![0-9a-f]{2})/i.test(ref)||/^[a-z][a-z\d+.-]*:/i.test(ref)&&!/^https?:\/\//i.test(ref))throw Error('invalid URL');const resolved=new URL(ref,baseURL);if(!/^https?:$/.test(resolved.protocol)||!resolved.host)throw Error('invalid URL');source=resolved.href}catch(e){return {ok:false,error:`fonts: ${base}index.json: font ${JSON.stringify(name)} has an invalid HTTP URL ${JSON.stringify(ref)}`}}}
  #|     if(/\.(ttf|otf|ttc|otc)$/i.test(name))entries.set(name,source);
  #|   }
  #|   const files=new Map(), pending=[...entries];let next=0, retry=false;
  #|   const worker=async()=>{while(next<pending.length){const [name,source]=pending[next++];try{const response=await fetch(source);if(response.status===200)files.set(name,new Uint8Array(await response.arrayBuffer()));else retry=true}catch(_){retry=true}}};
  #|   await Promise.all(Array.from({length:Math.min(4,pending.length)},worker));
  #|   return {ok:true,retry,files:[...files.entries()].sort((a,b)=>a[0]<b[0]?-1:a[0]>b[0]?1:0)};
  #| })();cache.set(url,load);const result=await load;if(!result.ok||result.retry)cache.delete(url);return result;
  #| }

///|
extern "js" fn native_font_directory_ok(result : NativeFontDirectory) -> Bool =
  #|(result) => result.ok

///|
extern "js" fn native_font_directory_error(
  result : NativeFontDirectory,
) -> String =
  #|(result) => result.error

///|
extern "js" fn native_font_directory_count(
  result : NativeFontDirectory,
) -> Int32 =
  #|(result) => result.files.length

///|
extern "js" fn native_font_directory_name(
  result : NativeFontDirectory,
  index : Int32,
) -> String =
  #|(result,index) => result.files[index][0]

///|
extern "js" fn native_font_directory_bytes(
  result : NativeFontDirectory,
  index : Int32,
) -> Bytes =
  #|(result,index) => result.files[index][1]
