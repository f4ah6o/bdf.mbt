///|
priv enum PdfCryptMethod {
  PdfCryptNone
  PdfCryptRC4
  PdfCryptAES128
  PdfCryptAES256
}

///|
priv struct PdfEncryption {
  key : Bytes
  stream_method : PdfCryptMethod
  string_method : PdfCryptMethod
  key_length : Int32
  encrypt_metadata : Bool
}

///|
let pdf_encryption_padding : Bytes = b"\x28\xbf\x4e\x5e\x4e\x75\x8a\x41\x64\x00\x4e\x56\xff\xfa\x01\x08\x2e\x2e\x00\xb6\xd0\x68\x3e\x80\x2f\x0c\xa9\xfe\x64\x53\x69\x7a"

///|
fn pdf_encryption_bytes(object : PdfObject?) -> Bytes? {
  match object {
    Some(PdfString(value)) => Some(value)
    Some(PdfHex(value)) => Some(value)
    _ => None
  }
}

///|
fn pdf_encryption_int(
  file : PdfFile,
  dict : PdfObject,
  key : Bytes,
  default : Int32,
) -> Int32 {
  match file.page_num(pdf_dict_get(dict, key)) {
    Some(value) if value >= -2147483648.0 && value <= 2147483647.0 =>
      value.to_int()
    _ => default
  }
}

///|
fn pdf_encryption_bool(
  file : PdfFile,
  dict : PdfObject,
  key : Bytes,
  default : Bool,
) -> Bool {
  match file.page_deref(pdf_dict_get(dict, key)) {
    PdfBool(value) => value
    _ => default
  }
}

///|
fn pdf_encryption_id(file : PdfFile) -> Bytes {
  match file.trailer_entry(b"ID") {
    Some(value) =>
      match file.page_deref(Some(value)) {
        PdfArray(values) =>
          if values.is_empty() {
            b""
          } else {
            match pdf_encryption_bytes(Some(values[0])) {
              Some(bytes) => bytes
              None => b""
            }
          }
        _ => b""
      }
    None => b""
  }
}

///|
fn pdf_encryption_password(password : String) -> Bytes {
  let raw = @utf8.encode(password)
  let out = @buffer.Buffer(size_hint=32)
  let count = if raw.length() > 32 { 32 } else { raw.length() }
  out.write_bytesview(raw[:count])
  for i in count..<32 {
    out.write_byte(pdf_encryption_padding[i])
  }
  out.to_bytes()
}

///|
fn pdf_encryption_password_short(password : String) -> Bytes {
  let raw = @utf8.encode(password)
  if raw.length() > 127 {
    raw[:127].to_owned()
  } else {
    raw
  }
}

///|
fn pdf_md5_bytes(data : Bytes) -> Bytes {
  Bytes::from_array(@xcrypto.md5(data))
}

///|
fn pdf_sha256_bytes(data : Bytes) -> Bytes {
  Bytes::from_array(@xcrypto.sha256(data))
}

///|
fn pdf_sha384_bytes(data : Bytes) -> Bytes {
  Bytes::from_array(@xcrypto.sha384(data))
}

///|
fn pdf_sha512_bytes(data : Bytes) -> Bytes {
  Bytes::from_array(@xcrypto.sha512(data))
}

///|
fn pdf_rc4(key : Bytes, data : Bytes) -> Bytes {
  let state : FixedArray[Int32] = FixedArray::make(256, 0)
  for i in 0..<256 {
    state[i] = i
  }
  let mut j = 0
  for i in 0..<256 {
    j = (j + state[i] + key[i % key.length()].to_int()) % 256
    let temp = state[i]
    state[i] = state[j]
    state[j] = temp
  }
  let out = @buffer.Buffer(size_hint=data.length())
  let mut i = 0
  j = 0
  for byte in data {
    i = (i + 1) % 256
    j = (j + state[i]) % 256
    let temp = state[i]
    state[i] = state[j]
    state[j] = temp
    out.write_byte(
      (byte.to_int() ^ state[(state[i] + state[j]) % 256]).to_byte(),
    )
  }
  out.to_bytes()
}

///|
fn pdf_aes_decrypt_no_padding(key : Bytes, iv : Bytes, data : Bytes) -> Bytes raise PdfStreamError {
  if data.length() % 16 != 0 || iv.length() != 16 {
    raise InvalidStream("invalid PDF AES data")
  }
  @xcrypto.aes_cbc_decrypt(key, iv, data) catch {
    _ => raise InvalidStream("invalid PDF AES data")
  }
}

///|
fn pdf_aes_decrypt(key : Bytes, data : Bytes) -> Bytes raise PdfStreamError {
  if data.length() < 16 || (data.length() - 16) % 16 != 0 {
    raise InvalidStream("invalid PDF AES data")
  }
  let iv = data[:16].to_owned()
  let body = data[16:].to_owned()
  let plain = pdf_aes_decrypt_no_padding(key, iv, body)
  let length = plain.length()
  if length == 0 {
    raise InvalidStream("invalid PDF AES padding")
  }
  let padding = plain[length - 1].to_int()
  if padding <= 0 || padding > 16 || padding > length {
    raise InvalidStream("invalid PDF AES padding")
  }
  for i in (length - padding)..<length {
    if plain[i].to_int() != padding {
      raise InvalidStream("invalid PDF AES padding")
    }
  }
  plain[:length - padding].to_owned()
}

///|
fn pdf_object_key(
  encryption : PdfEncryption,
  number : Int64,
  generation : Int64,
  aes : Bool,
) -> Bytes {
  let out = @buffer.Buffer(size_hint=encryption.key.length() + 9)
  out.write_bytesview(encryption.key[:])
  out.write_byte(((number >> 0) & 0xffL).to_int().to_byte())
  out.write_byte(((number >> 8) & 0xffL).to_int().to_byte())
  out.write_byte(((number >> 16) & 0xffL).to_int().to_byte())
  out.write_byte(((generation >> 0) & 0xffL).to_int().to_byte())
  out.write_byte(((generation >> 8) & 0xffL).to_int().to_byte())
  if aes {
    out.write_bytesview(b"sAlT"[:])
  }
  let digest = pdf_md5_bytes(out.to_bytes())
  let length = Int32::min(encryption.key_length + 5, 16)
  digest[:length].to_owned()
}

///|
fn pdf_decrypt_bytes(
  encryption : PdfEncryption,
  number : Int64,
  generation : Int64,
  data : Bytes,
  crypt_method : PdfCryptMethod,
) -> Bytes raise PdfStreamError {
  match crypt_method {
    PdfCryptNone => data
    PdfCryptRC4 =>
      pdf_rc4(pdf_object_key(encryption, number, generation, false), data)
    PdfCryptAES128 =>
      pdf_aes_decrypt(pdf_object_key(encryption, number, generation, true), data)
    PdfCryptAES256 => pdf_aes_decrypt(encryption.key, data)
  }
}

///|
fn pdf_decrypt_object(
  encryption : PdfEncryption,
  number : Int64,
  generation : Int64,
  object : PdfObject,
  depth : Int32,
) -> PdfObject raise PdfStreamError {
  if depth > 100 {
    raise InvalidStream("PDF encrypted object nesting limit")
  }
  match object {
    PdfString(value) =>
      PdfString(
        pdf_decrypt_bytes(
          encryption,
          number,
          generation,
          value,
          encryption.string_method,
        ),
      )
    PdfHex(value) =>
      PdfHex(
        pdf_decrypt_bytes(
          encryption,
          number,
          generation,
          value,
          encryption.string_method,
        ),
      )
    PdfArray(values) =>
      PdfArray(
        values.map(fn(value) raise PdfStreamError {
          pdf_decrypt_object(encryption, number, generation, value, depth + 1)
        }),
      )
    PdfDict(entries) =>
      PdfDict(
        entries.map(fn(entry) raise PdfStreamError {
          let (key, value) = entry
          (
            key,
            pdf_decrypt_object(encryption, number, generation, value, depth + 1),
          )
        }),
      )
    _ => object
  }
}

///|
fn PdfFile::decrypt_loaded(
  self : PdfFile,
  number : Int64,
  generation : Int64,
  value : PdfObject,
  stream : Bytes?,
) -> (PdfObject, Bytes?) raise PdfStreamError {
  let encryption = match self.encryption {
    Some(value) => value
    None => return (value, stream)
  }
  let is_xref = pdf_dict_get(value, b"Type") is Some(PdfName(b"XRef"))
  if is_xref {
    return (value, stream)
  }
  let value = pdf_decrypt_object(
    encryption, number, generation, value, 0,
  )
  let stream = match stream {
    Some(data) => {
      let is_metadata = pdf_dict_get(value, b"Type") is Some(PdfName(b"Metadata"))
      if is_metadata && !encryption.encrypt_metadata {
        Some(data)
      } else {
        Some(
          pdf_decrypt_bytes(
            encryption,
            number,
            generation,
            data,
            encryption.stream_method,
          ),
        )
      }
    }
    None => None
  }
  (value, stream)
}

///|
fn pdf_legacy_file_key(
  password : Bytes,
  owner : Bytes,
  permissions : Int64,
  id : Bytes,
  revision : Int32,
  key_length : Int32,
  encrypt_metadata : Bool,
) -> Bytes {
  let input = @buffer.Buffer(size_hint=password.length() + owner.length() + id.length() + 9)
  input.write_bytesview(password[:])
  input.write_bytesview(owner[:])
  let p = permissions & 0xffffffffL
  for i in 0..<4 {
    input.write_byte(((p >> (i * 8)) & 0xffL).to_int().to_byte())
  }
  input.write_bytesview(id[:])
  if revision >= 4 && !encrypt_metadata {
    input.write_bytesview(b"\xff\xff\xff\xff"[:])
  }
  let mut key = pdf_md5_bytes(input.to_bytes())
  if revision >= 3 {
    for _ in 0..<50 {
      key = pdf_md5_bytes(key[:key_length].to_owned())
    }
  }
  key[:key_length].to_owned()
}

///|
fn pdf_legacy_user_hash(
  key : Bytes,
  id : Bytes,
  revision : Int32,
) -> Bytes {
  if revision == 2 {
    pdf_rc4(key, pdf_encryption_padding)
  } else {
    let input = @buffer.Buffer(size_hint=pdf_encryption_padding.length() + id.length())
    input.write_bytesview(pdf_encryption_padding[:])
    input.write_bytesview(id[:])
    let mut hash = pdf_md5_bytes(input.to_bytes())
    let base_key : Array[Byte] = key.to_array()
    hash = pdf_rc4(key, hash)
    for i in 1..<20 {
      let key_bytes = base_key.copy()
      for j in 0..<key_bytes.length() {
        key_bytes[j] = (key_bytes[j].to_int() ^ i).to_byte()
      }
      hash = pdf_rc4(Bytes::from_array(key_bytes), hash)
    }
    hash
  }
}

///|
fn pdf_legacy_check_user(
  key : Bytes,
  user : Bytes,
  id : Bytes,
  revision : Int32,
) -> Bool {
  let hash = pdf_legacy_user_hash(key, id, revision)
  let needed = if revision == 2 { 32 } else { 16 }
  if user.length() < needed || hash.length() < needed {
    return false
  }
  for i in 0..<needed {
    if user[i] != hash[i] {
      return false
    }
  }
  true
}

///|
fn pdf_legacy_owner_password(
  password : Bytes,
  owner : Bytes,
  revision : Int32,
  key_length : Int32,
) -> Bytes {
  let mut key = pdf_md5_bytes(password)
  if revision >= 3 {
    for _ in 0..<50 {
      key = pdf_md5_bytes(key[:key_length].to_owned())
    }
  }
  key = key[:key_length].to_owned()
  let mut result = pdf_rc4(key, owner)
  if revision >= 3 {
    let base_key : Array[Byte] = key.to_array()
    for i in 1..<20 {
      let key_bytes = base_key.copy()
      for j in 0..<key_bytes.length() {
        key_bytes[j] = (key_bytes[j].to_int() ^ i).to_byte()
      }
      result = pdf_rc4(Bytes::from_array(key_bytes), result)
    }
  }
  result
}

///|
fn pdf_r6_hash(password : Bytes, salt : Bytes, user_key : Bytes) -> Bytes {
  let seed = @buffer.Buffer(size_hint=password.length() + salt.length() + user_key.length())
  seed.write_bytesview(password[:])
  seed.write_bytesview(salt[:])
  seed.write_bytesview(user_key[:])
  let mut key = pdf_sha256_bytes(seed.to_bytes())
  let mut round = 0
  while true {
    let block = @buffer.Buffer(size_hint=password.length() + key.length() + user_key.length())
    block.write_bytesview(password[:])
    block.write_bytesview(key[:])
    block.write_bytesview(user_key[:])
    let unit = block.to_bytes()
    let repeated = @buffer.Buffer(size_hint=unit.length() * 64)
    for _ in 0..<64 {
      repeated.write_bytesview(unit[:])
    }
    let data = repeated.to_bytes()
    let aes_key = key[:16].to_owned()
    let iv = key[16:32].to_owned()
    let encrypted = @xcrypto.aes_cbc_encrypt(aes_key, iv, data) catch {
      _ => return key[:32].to_owned()
    }
    let mut selector = 0
    for i in 0..<16 {
      selector = (selector + encrypted[i].to_int()) % 3
    }
    key = match selector {
      0 => pdf_sha256_bytes(encrypted)
      1 => pdf_sha384_bytes(encrypted)
      _ => pdf_sha512_bytes(encrypted)
    }
    round += 1
    let last = encrypted[encrypted.length() - 1].to_int()
    if round >= 64 && last <= round - 32 {
      break
    }
  }
  key[:32].to_owned()
}

///|
fn pdf_r6_unlock(
  password : String,
  owner : Bytes,
  user : Bytes,
  owner_encrypted : Bytes,
  user_encrypted : Bytes,
) -> Bytes? {
  let password = pdf_encryption_password_short(password)
  if user.length() < 48 {
    return None
  }
  let user_hash = pdf_r6_hash(password, user[32:40].to_owned(), b"")
  if user_hash == user[:32].to_owned() {
    let key = pdf_r6_hash(password, user[40:48].to_owned(), b"")
    let decrypted = pdf_aes_decrypt_no_padding(
      key,
      Bytes::make(16, 0),
      user_encrypted,
    ) catch {
      _ => return None
    }
    return Some(decrypted)
  }
  if owner.length() < 48 {
    return None
  }
  let owner_hash = pdf_r6_hash(password, owner[32:40].to_owned(), user)
  if owner_hash == owner[:32].to_owned() {
    let key = pdf_r6_hash(password, owner[40:48].to_owned(), user)
    let decrypted = pdf_aes_decrypt_no_padding(
      key,
      Bytes::make(16, 0),
      owner_encrypted,
    ) catch {
      _ => return None
    }
    return Some(decrypted)
  }
  None
}

///|
fn pdf_crypt_filter(
  file : PdfFile,
  dict : PdfObject,
  key : Bytes,
) -> (PdfCryptMethod, Int32) {
  let name = match file.page_deref(pdf_dict_get(dict, key)) {
    PdfName(value) => value
    _ => return (PdfCryptNone, 0)
  }
  if name == b"Identity" {
    return (PdfCryptNone, 0)
  }
  let filters = file.page_deref(pdf_dict_get(dict, b"CF"))
  let filter = file.page_deref(pdf_dict_get(filters, name))
  let crypt_method = match file.page_deref(pdf_dict_get(filter, b"CFM")) {
    PdfName(b"AESV2") => PdfCryptAES128
    PdfName(b"AESV3") => PdfCryptAES256
    PdfName(b"V2") => PdfCryptRC4
    PdfName(b"None") => PdfCryptNone
    _ => PdfCryptNone
  }
  let length = match file.page_num(pdf_dict_get(filter, b"Length")) {
    Some(value) =>
      if value <= 32.0 {
        value.to_int()
      } else {
        (value / 8.0).to_int()
      }
    None => 0
  }
  (crypt_method, length)
}

///|
fn PdfFile::unlock(self : PdfFile, password : String) -> Unit raise PdfStreamError {
  if self.encryption is Some(_) {
    return
  }
  let encrypt_object = match self.trailer_entry(b"Encrypt") {
    Some(value) =>
      match self.page_deref(Some(value)) {
        PdfNull => return
        dict => dict
      }
    None => return
  }
  let filter = match self.page_deref(pdf_dict_get(encrypt_object, b"Filter")) {
    PdfName(value) => value
    _ => raise InvalidStream("unsupported PDF encryption handler")
  }
  if filter != b"Standard" {
    raise InvalidStream("unsupported PDF encryption handler")
  }
  let version = pdf_encryption_int(self, encrypt_object, b"V", 0)
  let revision = pdf_encryption_int(self, encrypt_object, b"R", 2)
  if revision < 2 || revision == 5 || revision > 6 {
    raise InvalidStream(
      "unsupported PDF encryption revision " + revision.to_string(),
    )
  }
  let owner = match pdf_encryption_bytes(pdf_dict_get(encrypt_object, b"O")) {
    Some(value) => value
    None => raise InvalidStream("PDF encryption owner entry is missing")
  }
  let user = match pdf_encryption_bytes(pdf_dict_get(encrypt_object, b"U")) {
    Some(value) => value
    None => raise InvalidStream("PDF encryption user entry is missing")
  }
  let permissions = match pdf_object_int(pdf_dict_get(encrypt_object, b"P")) {
    Some(value) => value
    None => 0L
  }
  let id = pdf_encryption_id(self)
  let encrypt_metadata = pdf_encryption_bool(
    self, encrypt_object, b"EncryptMetadata", true,
  )
  let length_bits = pdf_encryption_int(
    self,
    encrypt_object,
    b"Length",
    if version == 1 { 40 } else { 128 },
  )
  let mut stream_method = PdfCryptRC4
  let mut string_method = PdfCryptRC4
  let mut key_length = if revision == 2 {
    5
  } else {
    Int32::min(16, Int32::max(5, length_bits / 8))
  }
  if version == 4 {
    let (stream, stream_length) = pdf_crypt_filter(self, encrypt_object, b"StmF")
    let (string, string_length) = pdf_crypt_filter(self, encrypt_object, b"StrF")
    stream_method = stream
    string_method = string
    if stream_length > 0 {
      key_length = stream_length
    } else if string_length > 0 {
      key_length = string_length
    }
  } else if version == 5 {
    stream_method = PdfCryptAES256
    string_method = PdfCryptAES256
    key_length = 32
  }
  let key = if revision >= 5 {
    let owner_encrypted = match pdf_encryption_bytes(pdf_dict_get(encrypt_object, b"OE")) {
      Some(value) => value
      None => raise InvalidStream("PDF encryption owner key is missing")
    }
    let user_encrypted = match pdf_encryption_bytes(pdf_dict_get(encrypt_object, b"UE")) {
      Some(value) => value
      None => raise InvalidStream("PDF encryption user key is missing")
    }
    match pdf_r6_unlock(password, owner, user, owner_encrypted, user_encrypted) {
      Some(value) => value
      None => raise InvalidStream("PDF password is incorrect")
    }
  } else {
    let user_password = pdf_encryption_password(password)
    let mut found : Bytes? = None
    let candidate = pdf_legacy_file_key(
      user_password,
      owner,
      permissions,
      id,
      revision,
      key_length,
      encrypt_metadata,
    )
    if pdf_legacy_check_user(candidate, user, id, revision) {
      found = Some(candidate)
    } else {
      let recovered = pdf_legacy_owner_password(
        user_password, owner, revision, key_length,
      )
      let candidate = pdf_legacy_file_key(
        recovered,
        owner,
        permissions,
        id,
        revision,
        key_length,
        encrypt_metadata,
      )
      if pdf_legacy_check_user(candidate, user, id, revision) {
        found = Some(candidate)
      }
    }
    match found {
      Some(value) => value
      None => {
        if password == "" {
          raise InvalidStream("PDF is encrypted and needs a password")
        } else {
          raise InvalidStream("PDF password is incorrect")
        }
      }
    }
  }
  self.encryption = Some({
    key,
    stream_method,
    string_method,
    key_length,
    encrypt_metadata,
  })
}
