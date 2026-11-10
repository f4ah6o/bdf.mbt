///|
/// The validated `options.fontFiles` value of one converter request.
///
/// The JavaScript side owns the validation and copies every accepted byte
/// range, so the Worker never holds a view into a caller buffer and never
/// detaches one. Names are kept only to label the font database entries; they
/// are not part of any diagnostic.
#external
priv type NativeFontFiles

///|
/// Read and validate `options.fontFiles`.
///
/// Accepted shape: an array of `{ name: string, bytes: Uint8Array | ArrayBuffer }`.
/// A missing or `null` value means "no byte-mode fonts". Every other shape is
/// rejected with an index-based message that never repeats a supplied name or
/// any font data.
extern "js" fn native_font_files_read(
  request : ConverterRequest,
) -> NativeFontFiles =
  #|(request) => {
  #| const value=request.options?.fontFiles;
  #| if(value===undefined||value===null)return {count:0,error:''};
  #| if(!Array.isArray(value))return {count:0,error:'fontFiles: expected an array of {name, bytes}'};
  #| const maxFiles=64,maxFileBytes=32*1024*1024,maxTotalBytes=64*1024*1024;
  #| if(value.length>maxFiles)return {count:0,error:`fontFiles: at most ${maxFiles} files are supported`};
  #| const files=[];let total=0;
  #| for(let i=0;i<value.length;i++){
  #|   const entry=value[i];
  #|   if(entry===null||typeof entry!=='object'||Array.isArray(entry))return {count:0,error:`fontFiles[${i}]: expected an object with name and bytes`};
  #|   const name=entry.name;
  #|   if(typeof name!=='string'||name.length===0)return {count:0,error:`fontFiles[${i}]: name must be a non-empty string`};
  #|   if(name.length>255||/[\u0000-\u001f\u007f]/.test(name))return {count:0,error:`fontFiles[${i}]: name must be at most 255 characters without control characters`};
  #|   const bytes=entry.bytes;
  #|   let view;
  #|   if(bytes instanceof ArrayBuffer)view=new Uint8Array(bytes);
  #|   else if(bytes instanceof Uint8Array)view=new Uint8Array(bytes.buffer,bytes.byteOffset,bytes.byteLength);
  #|   else return {count:0,error:`fontFiles[${i}]: bytes must be a Uint8Array or ArrayBuffer`};
  #|   if(view.byteLength===0)return {count:0,error:`fontFiles[${i}]: bytes must not be empty`};
  #|   if(view.byteLength>maxFileBytes)return {count:0,error:`fontFiles[${i}]: bytes exceed the ${maxFileBytes} byte per-file limit`};
  #|   total+=view.byteLength;
  #|   if(total>maxTotalBytes)return {count:0,error:`fontFiles: total bytes exceed the ${maxTotalBytes} byte limit`};
  #|   files.push({name,copy:new Uint8Array(view)});
  #| }
  #| return {count:files.length,error:'',files};
  #|}

///|
extern "js" fn native_font_files_error(files : NativeFontFiles) -> String =
  #|(files) => files.error

///|
extern "js" fn native_font_files_count(files : NativeFontFiles) -> Int32 =
  #|(files) => files.count

///|
extern "js" fn native_font_files_name(
  files : NativeFontFiles,
  index : Int32,
) -> String =
  #|(files,index) => files.files[index].name

///|
extern "js" fn native_font_files_bytes(
  files : NativeFontFiles,
  index : Int32,
) -> Bytes =
  #|(files,index) => files.files[index].copy
