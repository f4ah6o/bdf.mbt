///|
/// Iteration counts above this are refused, so a file cannot keep a reader
/// busy for long; so is their sum over the key slots tried.
pub const MAX_ITERATIONS : Int32 = 10000000

///|
/// At most this many ecdh key slots are tried: each costs a key agreement.
pub const MAX_ECDH_SLOTS : Int32 = 16

///|
priv struct UnlockBudget {
  mut spent : Int32
  mut ecdh : Int32
}

///|
fn UnlockBudget::new() -> UnlockBudget {
  { spent: 0, ecdh: 0, }
}

///|
fn UnlockBudget::password(
  self : UnlockBudget,
  kdf : String,
  iterations : Int32,
) -> Unit raise {
  if kdf != "PBKDF2-SHA256" {
    raise BadFormat("unknown key derivation " + kdf)
  }
  if iterations < 1 || iterations > MAX_ITERATIONS {
    raise BadFormat("iteration count " + iterations.to_string() + " out of range")
  }
  self.spent += iterations
  if self.spent > MAX_ITERATIONS {
    raise BadFormat(
      "the key slots take more than " + MAX_ITERATIONS.to_string() + " iterations",
    )
  }
}

///|
fn UnlockBudget::ecdh(self : UnlockBudget, kdf : String, curve : String) -> Unit raise {
  if curve != "P-256" {
    raise BadFormat("unknown curve " + curve)
  }
  if kdf != "HKDF-SHA256" {
    raise BadFormat("unknown key derivation " + kdf)
  }
  self.ecdh += 1
  if self.ecdh > MAX_ECDH_SLOTS {
    raise BadFormat(
      "more than " + MAX_ECDH_SLOTS.to_string() + " ecdh key slots",
    )
  }
}

///|
fn unlock_hex(value : String) -> Bytes raise {
  if value.length() % 2 != 0 {
    raise BadFormat("invalid hex")
  }
  let out : Array[Byte] = []
  for i in 0..<(value.length() / 2) {
    let high = value.get_char(i * 2).unwrap()
    let low = value.get_char(i * 2 + 1).unwrap()
    let digit = fn(c : Char) -> Int32 raise {
      if c >= '0' && c <= '9' {
        c.to_int() - '0'.to_int()
      } else if c >= 'a' && c <= 'f' {
        c.to_int() - 'a'.to_int() + 10
      } else if c >= 'A' && c <= 'F' {
        c.to_int() - 'A'.to_int() + 10
      } else {
        raise BadFormat("invalid hex digit")
      }
    }
    out.push(((digit(high) << 4) | digit(low)).to_byte())
  }
  Bytes::from_array(out)
}

///|
fn unlock_base64(value : String) -> Bytes raise {
  @base64.decode(value, ignore_whitespace=true) catch {
    _ => raise BadFormat("invalid base64 key slot")
  }
}

///|
fn unlock_parts(
  single : EncryptedSingle,
  key : Bytes,
  inner_manifest : Bytes,
) -> Document raise {
  let (_, inner, _) = writer_manifest(inner_manifest)
  let refs = sealed_references(
    @utf8.decode(inner_manifest) catch {
      _ => raise BadFormat("invalid inner manifest")
    },
    single.metadata.outer,
  )
  let loaded : Map[String, Bytes] = Map([])
  let loader = fn(hash : String, _ : Int32) raise {
    match loaded.get(hash) {
      Some(value) => value
      None => {
        let sealed_hash = match refs.get(hash) {
          Some(value) => value
          None => raise BadFormat("missing sealed part")
        }
        let stored = single.stored_part(sealed_hash)
        if stored.length() < 28 {
          raise BadFormat("sealed part is truncated")
        }
        let nonce = stored[:12].to_owned()
        let ciphertext = stored[12:stored.length() - 16].to_owned()
        let tag = stored[stored.length() - 16:].to_owned()
        let aad = unlock_hex(hash)
        let plain = @crypto.aes_gcm_decrypt(key, nonce, ciphertext, tag, aad) catch {
          _ => None
        }
        match plain {
          Some(value) => {
            loaded[hash] = value
            value
          }
          None => raise BadFormat("sealed part authentication failed")
        }
      }
    }
  }
  let output = split_to_single(inner_manifest, loader)
  let document = open_single(output)
  if document.manifest.views.length() != inner.views.length() {
    raise BadFormat("unlocked manifest mismatch")
  }
  document
}

///|
fn unlock_with_content_key(
  single : EncryptedSingle,
  key : Bytes,
) -> Document raise {
  let sealed = single.stored_part(single.metadata.manifest_hash)
  if sealed.length() < 28 {
    raise BadFormat("sealed manifest is truncated")
  }
  let nonce = sealed[:12].to_owned()
  let ciphertext = sealed[12:sealed.length() - 16].to_owned()
  let tag = sealed[sealed.length() - 16:].to_owned()
  let manifest_plain = @crypto.aes_gcm_decrypt(
    key, nonce, ciphertext, tag, b"manifest",
  ) catch {
    _ => None
  }
  let plain = match manifest_plain {
    Some(value) => value
    None => raise BadFormat("sealed manifest authentication failed")
  }
  let encoded = decode_encoded(
    plain,
    single.metadata.manifest_encoding,
    268435456,
  )
  unlock_parts(single, key, encoded)
}

///|
/// Unlock an encrypted single-file BDF with a password. Password key slots
/// use PBKDF2-HMAC-SHA-256 and AES-KW; sealed parts use AES-256-GCM.
pub fn open_encrypted_with_password(
  data : Bytes,
  password : String,
) -> Document raise {
  let single = open_encrypted_single(data)
  let normalized = @normalization.nfkc(password)
  let budget = UnlockBudget::new()
  for slot in single.metadata.keys {
    match slot {
      Password(kdf, iterations, salt, wrapped) => {
        budget.password(kdf, iterations)
        let salt_bytes = unlock_base64(salt) catch { _ => continue }
        let wrapped_bytes = unlock_base64(wrapped) catch { _ => continue }
        let kek = @crypto.pbkdf2_sha256(
          @utf8.encode(normalized),
          salt_bytes,
          iterations,
          32,
        )
        let key = @crypto.aes_key_unwrap(kek, wrapped_bytes) catch { _ => None }
        match key {
          Some(key) if key.length() == 32 =>
            return unlock_with_content_key(single, key)
          _ => ()
        }
      }
      _ => ()
    }
  }
  raise BadFormat("wrong password or unsupported key slot")
}

///|
/// Unlock an encrypted single-file BDF with a P-256 private key.
pub fn open_encrypted_with_ecdh(
  data : Bytes,
  private_key : Bytes,
) -> Document raise {
  let single = open_encrypted_single(data)
  let public_key = @crypto.p256_public_key(private_key)
  let budget = UnlockBudget::new()
  for slot in single.metadata.keys {
    match slot {
      Ecdh(kdf, curve, epk, wrapped) => {
        budget.ecdh(kdf, curve)
        let epk_bytes = unlock_base64(epk) catch { _ => continue }
        let wrapped_bytes = unlock_base64(wrapped) catch { _ => continue }
        let shared = @crypto.p256_ecdh(private_key, epk_bytes) catch {
          _ => continue
        }
        let salt_input : Array[Byte] = []
        for byte in epk_bytes {
          salt_input.push(byte)
        }
        for byte in public_key {
          salt_input.push(byte)
        }
        let salt = @crypto.sha256_bytes(Bytes::from_array(salt_input))
        let kek = @crypto.hkdf_sha256(shared, salt, b"bdf ecdh v1", 32) catch {
          _ => continue
        }
        let key = @crypto.aes_key_unwrap(kek, wrapped_bytes) catch { _ => None }
        match key {
          Some(key) if key.length() == 32 =>
            return unlock_with_content_key(single, key)
          _ => ()
        }
      }
      _ => ()
    }
  }
  raise BadFormat("wrong key or unsupported key slot")
}
