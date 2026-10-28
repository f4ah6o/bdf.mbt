///|
/// A password string or a Web Crypto P-256 CryptoKeyPair.
#external
pub type CryptoCredential

///|
/// Convert a MoonBit password into a browser crypto credential.
#export_name("password_credential")
pub fn password_credential(password : String) -> CryptoCredential {
  password_credential_js(password)
}

///|
extern "js" fn password_credential_js(password : String) -> CryptoCredential =
  #|(password) => password

///|
/// A Web Crypto ECDH P-256 key pair supplied by the browser host.
#external
pub type BrowserKeyPair

///|
/// Convert a browser key pair into a crypto credential.
#export_name("key_pair_credential")
pub fn key_pair_credential(pair : BrowserKeyPair) -> CryptoCredential {
  key_pair_credential_js(pair)
}

///|
extern "js" fn key_pair_credential_js(pair : BrowserKeyPair) -> CryptoCredential =
  #|(pair) => pair

///|
#external
priv type ContentKey

///|
extern "js" fn is_password(credential : CryptoCredential) -> Bool =
  #|(credential) => typeof credential === "string"

///|
extern "js" fn key_missing(key : ContentKey) -> Bool =
  #|(key) => key === null

///|
extern "js" fn unwrap_password(
  credential : CryptoCredential,
  salt : String,
  iterations : Int32,
  wrapped : String,
) -> @js_async.Promise[ContentKey] =
  #|async (password, salt, iterations, wrapped) => {
  #|  const b64=s=>Uint8Array.from(atob(s),c=>c.charCodeAt(0));
  #|  const pw=new TextEncoder().encode(password.normalize("NFKC"));
  #|  if(!pw.length) return null;
  #|  const base=await crypto.subtle.importKey("raw",pw,"PBKDF2",false,["deriveKey"]);
  #|  const kek=await crypto.subtle.deriveKey({name:"PBKDF2",hash:"SHA-256",salt:b64(salt),iterations},base,{name:"AES-KW",length:256},false,["unwrapKey"]);
  #|  const key=b64(wrapped);
  #|  try { return await crypto.subtle.unwrapKey("raw",key,kek,"AES-KW",{name:"AES-GCM",length:256},false,["decrypt"]); }
  #|  catch { return null; }
  #|}

///|
extern "js" fn unwrap_ecdh(
  credential : CryptoCredential,
  epk : String,
  wrapped : String,
) -> @js_async.Promise[ContentKey] =
  #|async (pair, epk, wrapped) => {
  #|  const b64=s=>Uint8Array.from(atob(s),c=>c.charCodeAt(0));
  #|  const pub=b64(epk), reader=new Uint8Array(await crypto.subtle.exportKey("raw",pair.publicKey));
  #|  const writer=await crypto.subtle.importKey("raw",pub,{name:"ECDH",namedCurve:"P-256"},false,[]);
  #|  const secret=await crypto.subtle.deriveKey({name:"ECDH",public:writer},pair.privateKey,{name:"HKDF"},false,["deriveKey"]);
  #|  const both=new Uint8Array(pub.length+reader.length); both.set(pub); both.set(reader,pub.length);
  #|  const salt=await crypto.subtle.digest("SHA-256",both);
  #|  const kek=await crypto.subtle.deriveKey({name:"HKDF",hash:"SHA-256",salt,info:new TextEncoder().encode("bdf ecdh v1")},secret,{name:"AES-KW",length:256},false,["unwrapKey"]);
  #|  const key=b64(wrapped);
  #|  try { return await crypto.subtle.unwrapKey("raw",key,kek,"AES-KW",{name:"AES-GCM",length:256},false,["decrypt"]); }
  #|  catch { return null; }
  #|}

///|
extern "js" fn decrypt_sealed(
  key : ContentKey,
  bytes : Bytes,
  hash : String,
) -> @js_async.Promise[Bytes] =
  #|async (key,bytes,hash) => {
  #|  if(bytes.length<28) throw new Error("sealed part too short");
  #|  const aad=hash==="manifest" ? new TextEncoder().encode(hash) : Uint8Array.from(hash.match(/../g),x=>parseInt(x,16));
  #|  return new Uint8Array(await crypto.subtle.decrypt({name:"AES-GCM",iv:bytes.subarray(0,12),additionalData:aad},key,bytes.subarray(12)));
  #|}

///|
extern "js" fn make_split_loader(
  callback : (String, Int32) -> @js_async.Promise[Bytes],
) -> SplitPartLoader =
  #|(callback) => callback

///|
async fn unlock_content_key(
  metadata : @core.EncryptedManifest,
  credential : CryptoCredential,
) -> ContentKey {
  let password = is_password(credential)
  let mut spent = 0
  let mut ecdh_slots = 0
  for slot in metadata.keys {
    match slot {
      @core.Password(kdf, iterations, salt, wrapped) if password => {
        if kdf != "PBKDF2-SHA256" ||
          iterations < 1 ||
          iterations > 10000000 ||
          iterations > 10000000 - spent {
          raise BadFormat("invalid password key slot")
        }
        spent += iterations
        let key = unwrap_password(credential, salt, iterations, wrapped).wait()
        if !key_missing(key) {
          return key
        }
      }
      @core.Ecdh(kdf, curve, epk, wrapped) if !password => {
        ecdh_slots += 1
        if kdf != "HKDF-SHA256" || curve != "P-256" || ecdh_slots > 16 {
          raise BadFormat("invalid ECDH key slot")
        }
        let key = unwrap_ecdh(credential, epk, wrapped).wait()
        if !key_missing(key) {
          return key
        }
      }
      _ => ()
    }
  }
  if password {
    raise WrongPassword
  } else {
    raise WrongKey
  }
}

///|
async fn load_sealed(
  metadata : @core.EncryptedManifest,
  loader : SplitPartLoader,
  hash : String,
) -> Bytes {
  for part in metadata.outer.parts {
    if part.hash == hash {
      let bytes = fetch_split_part(loader, hash, part.length).wait()
      if bytes.length() != part.length {
        raise BadFormat("stored part size does not match manifest")
      }
      return bytes
    }
  }
  raise BadFormat("sealed part missing")
}

///|
async fn mount_encrypted(
  host : BrowserHost,
  metadata : @core.EncryptedManifest,
  loader : SplitPartLoader,
  credential : CryptoCredential,
  layout : String,
) -> Int32 {
  let key = unlock_content_key(metadata, credential)
  let encrypted_manifest = load_sealed(metadata, loader, metadata.manifest_hash)
  let compressed = decrypt_sealed(key, encrypted_manifest, "manifest").wait()
  let manifest = @core.decode_encoded(
    compressed,
    metadata.manifest_encoding,
    268435456,
  )
  let text = @utf8.decode(manifest) catch {
    _ => raise BadFormat("invalid UTF-8 manifest")
  }
  let refs = @core.sealed_references(text, metadata.outer)
  let inner_loader = make_split_loader(fn(hash, limit) {
    @js_async.Promise::from_async(() => {
      let sealed_hash = match refs.get(hash) {
        Some(value) => value
        None => raise BadFormat("sealed part missing")
      }
      let encrypted = load_sealed(metadata, loader, sealed_hash)
      let bytes = decrypt_sealed(key, encrypted, hash).wait()
      if bytes.length() > limit {
        raise BadFormat("decrypted part exceeds declared size")
      }
      bytes
    })
  })
  mount_bdf_split_async(host, manifest, inner_loader, layout).wait()
}

///|
/// Open and mount a password- or P-256-key-protected single-file document.
#export_name("mount_bdf_encrypted_async")
pub fn mount_bdf_encrypted_async(
  host : BrowserHost,
  data : Bytes,
  credential : CryptoCredential,
  layout : String,
) -> @js_async.Promise[Int32] {
  @js_async.Promise::from_async(() => {
    let single = @core.open_encrypted_single(data)
    let loader = make_split_loader(fn(hash, _) {
      @js_async.Promise::from_async(() => single.stored_part(hash))
    })
    mount_encrypted(host, single.metadata, loader, credential, layout)
  })
}

///|
/// Open and mount an encrypted split document using an asynchronous loader.
#export_name("mount_bdf_encrypted_split_async")
pub fn mount_bdf_encrypted_split_async(
  host : BrowserHost,
  manifest : Bytes,
  loader : SplitPartLoader,
  credential : CryptoCredential,
  layout : String,
) -> @js_async.Promise[Int32] {
  @js_async.Promise::from_async(() => {
    if manifest.length() > 268435456 {
      raise BadFormat("manifest exceeds 256 MiB")
    }
    let text = @utf8.decode(manifest) catch {
      _ => raise BadFormat("invalid UTF-8 manifest")
    }
    mount_encrypted(
      host,
      @core.parse_encrypted_manifest(text),
      loader,
      credential,
      layout,
    )
  })
}
