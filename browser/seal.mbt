///|
#external
priv type BrowserSealingKey

///|
extern "js" fn new_password_sealing_key(
  password : String,
  iterations : Int32,
) -> @js_async.Promise[BrowserSealingKey] =
  #|async (password, iterations) => {
  #|  const raw = new TextEncoder().encode(password.normalize("NFKC"));
  #|  const salt = crypto.getRandomValues(new Uint8Array(16));
  #|  const content = await crypto.subtle.generateKey({name:"AES-GCM",length:256},true,["encrypt"]);
  #|  const material = await crypto.subtle.importKey("raw",raw,"PBKDF2",false,["deriveKey"]);
  #|  const wrapping = await crypto.subtle.deriveKey({name:"PBKDF2",hash:"SHA-256",salt,iterations},material,{name:"AES-KW",length:256},false,["wrapKey"]);
  #|  const wrapped = new Uint8Array(await crypto.subtle.wrapKey("raw",content,wrapping,"AES-KW"));
  #|  const b64 = bytes => btoa(String.fromCharCode(...bytes));
  #|  return {content,slot:{type:"password",kdf:"PBKDF2-SHA256",iter:iterations,salt:b64(salt),key:b64(wrapped)}};
  #|}

///|
extern "js" fn new_ecdh_sealing_key(
  public_key : Bytes,
) -> @js_async.Promise[BrowserSealingKey] =
  #|async publicKey => {
  #|  const recipient = await crypto.subtle.importKey("raw",publicKey,{name:"ECDH",namedCurve:"P-256"},false,[]);
  #|  const ephemeral = await crypto.subtle.generateKey({name:"ECDH",namedCurve:"P-256"},true,["deriveBits"]);
  #|  const epk = new Uint8Array(await crypto.subtle.exportKey("raw",ephemeral.publicKey));
  #|  const secret = await crypto.subtle.deriveBits({name:"ECDH",public:recipient},ephemeral.privateKey,256);
  #|  const material = await crypto.subtle.importKey("raw",secret,"HKDF",false,["deriveKey"]);
  #|  const keys = new Uint8Array(epk.length+publicKey.length); keys.set(epk); keys.set(publicKey,epk.length);
  #|  const salt = await crypto.subtle.digest("SHA-256",keys);
  #|  const wrapping = await crypto.subtle.deriveKey({name:"HKDF",hash:"SHA-256",salt,info:new TextEncoder().encode("bdf ecdh v1")},material,{name:"AES-KW",length:256},false,["wrapKey"]);
  #|  const content = await crypto.subtle.generateKey({name:"AES-GCM",length:256},true,["encrypt"]);
  #|  const wrapped = new Uint8Array(await crypto.subtle.wrapKey("raw",content,wrapping,"AES-KW"));
  #|  const b64 = bytes => btoa(String.fromCharCode(...bytes));
  #|  return {content,slot:{type:"ecdh",kdf:"HKDF-SHA256",crv:"P-256",epk:b64(epk),key:b64(wrapped)}};
  #|}

///|
extern "js" fn sealing_key_slot(key : BrowserSealingKey) -> String =
  #|(key) => JSON.stringify(key.slot)

///|
extern "js" fn seal_bytes(
  key : BrowserSealingKey,
  data : Bytes,
  hash : String,
) -> @js_async.Promise[Bytes] =
  #|async (key,data,hash) => {
  #|  const nonce = crypto.getRandomValues(new Uint8Array(12));
  #|  const aad = hash === "manifest" ? new TextEncoder().encode(hash) : Uint8Array.from(hash.match(/../g),x=>parseInt(x,16));
  #|  const encrypted = new Uint8Array(await crypto.subtle.encrypt({name:"AES-GCM",iv:nonce,additionalData:aad},key.content,data));
  #|  const output = new Uint8Array(nonce.length+encrypted.length); output.set(nonce); output.set(encrypted,nonce.length);
  #|  return output;
  #|}

///|
async fn seal_document(
  plan : @core.SealingPlan,
  key : BrowserSealingKey,
) -> Bytes {
  let encrypted : Array[Bytes] = []
  for part in plan.parts() {
    encrypted.push(seal_bytes(key, part.data, part.hash).wait())
  }
  let inner = plan.inner_manifest(encrypted)
  let sealed_manifest = seal_bytes(key, inner.data, "manifest").wait()
  let slot = @json.parse(sealing_key_slot(key))
  let split = plan.finish(encrypted, inner, sealed_manifest, [slot])
  let parts : Map[String, Bytes] = Map([])
  for part in split.parts { parts[part.hash] = part.data }
  @core.split_to_single(split.manifest, (hash, _) => {
    match parts.get(hash) {
      Some(data) => data
      None => raise BadFormat("sealed part missing")
    }
  })
}

///|
/// Encrypt a single-file BDF with a new password key slot using Web Crypto.
/// Zero iterations selects the upstream default of 600,000.
#export_name("encrypt_bdf_password")
pub fn encrypt_bdf_password(
  data : Bytes,
  password : String,
  iterations : Int32,
) -> @js_async.Promise[Bytes] {
  @js_async.Promise::from_async(() => {
    if password == "" { raise BadFormat("bdf: empty password") }
    let iterations = if iterations == 0 { 600000 } else { iterations }
    if iterations < 1 || iterations > 10000000 {
      raise BadFormat("bdf: iteration count \{iterations} out of range")
    }
    let plan = @core.prepare_sealing(data)
    let key = new_password_sealing_key(password, iterations).wait()
    seal_document(plan, key)
  })
}

///|
/// Encrypt a single-file BDF for a P-256 recipient's 65-byte raw public key.
#export_name("encrypt_bdf_ecdh")
pub fn encrypt_bdf_ecdh(
  data : Bytes,
  public_key : Bytes,
) -> @js_async.Promise[Bytes] {
  @js_async.Promise::from_async(() => {
    if public_key.length() != 65 || public_key[0] != 4 {
      raise BadFormat("bdf: invalid P-256 public key")
    }
    let plan = @core.prepare_sealing(data)
    let key = new_ecdh_sealing_key(public_key).wait()
    seal_document(plan, key)
  })
}
