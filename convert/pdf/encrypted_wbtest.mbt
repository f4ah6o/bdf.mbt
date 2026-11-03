///|
fn pdf_r2_encrypted() -> Bytes {
  @base64.decode(
    "JVBERi0xLjcKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgPj4KZW5kb2JqCjIgMCBvYmoKPDwgL1R5cGUgL1BhZ2VzIC9LaWRzIFszIDAgUl0gL0NvdW50IDEgPj4KZW5kb2JqCjMgMCBvYmoKPDwgL1R5cGUgL1BhZ2UgL1BhcmVudCAyIDAgUiAvTWVkaWFCb3ggWzAgMCAyMDAgMjAwXSAvUmVzb3VyY2VzIDw8IC9Gb250IDw8IC9GMSA1IDAgUiA+PiA+PiAvQ29udGVudHMgNCAwIFIgPj4KZW5kb2JqCjQgMCBvYmoKPDwgL0xlbmd0aCA0OSA+PgpzdHJlYW0K8gi39sx+ugui+3rbgzR1kMb5a0K9K6BvfB7q5hgtoOhLg4Pa8VUp+rDqD675L9g3KgplbmRzdHJlYW0KZW5kb2JqCjUgMCBvYmoKPDwgL1R5cGUgL0ZvbnQgL1N1YnR5cGUgL1R5cGUxIC9CYXNlRm9udCAvSGVsdmV0aWNhID4+CmVuZG9iago2IDAgb2JqCjw8IC9GaWx0ZXIgL1N0YW5kYXJkIC9WIDEgL1IgMiAvTGVuZ3RoIDQwIC9QIC00IC9PIDxjYjU4OWJhN2FiZTdmMDU1NmNmZDQwMWY0YzI2M2Y4ZDY0YTVhYWFkOWMyMGNjYjZkZTdlOTFhMDc1N2Y3YjM0PiAvVSA8NDRiM2QxYWMwMDZkZDY3MGFkZGM3MjUyMTg5MWU5MDMyM2E0MmM2ZGI2NTQwNWQ1YzYxYjhmOTZkN2RjNDlmYj4gPj4KZW5kb2JqCjcgMCBvYmoKPDwgL1RpdGxlIDwxOWEwOTY1NWFlY2NjYjg2NDdmNT4gPj4KZW5kb2JqCnhyZWYKMCA4CjAwMDAwMDAwMDAgNjU1MzUgZiAKMDAwMDAwMDAwOSAwMDAwMCBuIAowMDAwMDAwMDU4IDAwMDAwIG4gCjAwMDAwMDAxMTUgMDAwMDAgbiAKMDAwMDAwMDI0MSAwMDAwMCBuIAowMDAwMDAwMzQwIDAwMDAwIG4gCjAwMDAwMDA0MTAgMDAwMDAgbiAKMDAwMDAwMDYxNiAwMDAwMCBuIAp0cmFpbGVyCjw8IC9TaXplIDggL1Jvb3QgMSAwIFIgL0VuY3J5cHQgNiAwIFIgL0luZm8gNyAwIFIgL0lEIFs8MDEyMzQ1Njc4OWFiY2RlZj48MDEyMzQ1Njc4OWFiY2RlZj5dID4+CnN0YXJ0eHJlZgo2NjcKJSVFT0YK"[:],
  ) catch {
    _ => b""
  }
}

///|
fn pdf_r4_encrypted() -> Bytes {
  @base64.decode(
    "JVBERi0xLjcKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgPj4KZW5kb2JqCjIgMCBvYmoKPDwgL1R5cGUgL1BhZ2VzIC9LaWRzIFszIDAgUl0gL0NvdW50IDEgPj4KZW5kb2JqCjMgMCBvYmoKPDwgL1R5cGUgL1BhZ2UgL1BhcmVudCAyIDAgUiAvTWVkaWFCb3ggWzAgMCAyMDAgMjAwXSAvUmVzb3VyY2VzIDw8IC9Gb250IDw8IC9GMSA1IDAgUiA+PiA+PiAvQ29udGVudHMgNCAwIFIgPj4KZW5kb2JqCjQgMCBvYmoKPDwgL0xlbmd0aCA4MCA+PgpzdHJlYW0KABEiM0RVZneImaq7zN3u/22qyKioY1J3y/T2hnYQRky6I10epvbrel8BG1F8JJK/ZTMxqRIHPRKaT1lnZklrAfg0LgrVfU4a1YXv7r1ce6kKZW5kc3RyZWFtCmVuZG9iago1IDAgb2JqCjw8IC9UeXBlIC9Gb250IC9TdWJ0eXBlIC9UeXBlMSAvQmFzZUZvbnQgL0hlbHZldGljYSA+PgplbmRvYmoKNiAwIG9iago8PCAvRmlsdGVyIC9TdGFuZGFyZCAvViA0IC9SIDQgL0xlbmd0aCAxMjggL1AgLTQgL0NGIDw8IC9TdGRDRiA8PCAvQ0ZNIC9BRVNWMiAvTGVuZ3RoIDE2IC9BdXRoRXZlbnQgL0RvY09wZW4gPj4gPj4gL1N0bUYgL1N0ZENGIC9TdHJGIC9TdGRDRiAvTyA8YWNiYTVjMzIwY2IyNjVmZDdhYjViOTUwODk3ZjYzYTZmMzA4YWM3M2UxODRlYzU1ZWYxMDgzN2ZhYjcyMDU5Yj4gL1UgPGQwMTc5NDVjYWY3ZTRiMmQ4MDVkNWRkOTZlNWE3NmZlMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDA+ID4+CmVuZG9iago3IDAgb2JqCjw8IC9UaXRsZSA8MDAxMTIyMzM0NDU1NjY3Nzg4OTlhYWJiY2NkZGVlZmY0NWZmOWY3MmE0ZDAwZWJjMGYxNGJlNDRmNTM5OWY4ZD4gPj4KZW5kb2JqCnhyZWYKMCA4CjAwMDAwMDAwMDAgNjU1MzUgZiAKMDAwMDAwMDAwOSAwMDAwMCBuIAowMDAwMDAwMDU4IDAwMDAwIG4gCjAwMDAwMDAxMTUgMDAwMDAgbiAKMDAwMDAwMDI0MSAwMDAwMCBuIAowMDAwMDAwMzcxIDAwMDAwIG4gCjAwMDAwMDA0NDEgMDAwMDAgbiAKMDAwMDAwMDc0MCAwMDAwMCBuIAp0cmFpbGVyCjw8IC9TaXplIDggL1Jvb3QgMSAwIFIgL0VuY3J5cHQgNiAwIFIgL0luZm8gNyAwIFIgL0lEIFs8MDEyMzQ1Njc4OWFiY2RlZj48MDEyMzQ1Njc4OWFiY2RlZj5dID4+CnN0YXJ0eHJlZgo4MzUKJSVFT0YK"[:],
  ) catch {
    _ => b""
  }
}

///|
fn pdf_r3_encrypted() -> Bytes {
  @base64.decode(
    "JVBERi0xLjcKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgPj4KZW5kb2JqCjIgMCBvYmoKPDwgL1R5cGUgL1BhZ2VzIC9LaWRzIFszIDAgUl0gL0NvdW50IDEgPj4KZW5kb2JqCjMgMCBvYmoKPDwgL1R5cGUgL1BhZ2UgL1BhcmVudCAyIDAgUiAvTWVkaWFCb3ggWzAgMCAyMDAgMjAwXSAvUmVzb3VyY2VzIDw8IC9Gb250IDw8IC9GMSA1IDAgUiA+PiA+PiAvQ29udGVudHMgNCAwIFIgPj4KZW5kb2JqCjQgMCBvYmoKPDwgL0xlbmd0aCA0OSA+PgpzdHJlYW0K2yH+lNYK7D9u7CUa4X5S/ReP5YNtQtRQx0zosofsy698UHENLDuWJc1RNv633Pe6dAplbmRzdHJlYW0KZW5kb2JqCjUgMCBvYmoKPDwgL1R5cGUgL0ZvbnQgL1N1YnR5cGUgL1R5cGUxIC9CYXNlRm9udCAvSGVsdmV0aWNhID4+CmVuZG9iago2IDAgb2JqCjw8IC9GaWx0ZXIgL1N0YW5kYXJkIC9WIDIgL1IgMyAvTGVuZ3RoIDEyOCAvUCAtNCAvTyA8YWNiYTVjMzIwY2IyNjVmZDdhYjViOTUwODk3ZjYzYTZmMzA4YWM3M2UxODRlYzU1ZWYxMDgzN2ZhYjcyMDU5Yj4gL1UgPGQwMTc5NDVjYWY3ZTRiMmQ4MDVkNWRkOTZlNWE3NmZlMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDA+ID4+CmVuZG9iago3IDAgb2JqCjw8IC9UaXRsZSA8YzEyYjE1Y2Q1ZTk1YmE3NTJiNWM+ID4+CmVuZG9iagp4cmVmCjAgOAowMDAwMDAwMDAwIDY1NTM1IGYgCjAwMDAwMDAwMDkgMDAwMDAgbiAKMDAwMDAwMDA1OCAwMDAwMCBuIAowMDAwMDAwMTE1IDAwMDAwIG4gCjAwMDAwMDAyNDEgMDAwMDAgbiAKMDAwMDAwMDM0MCAwMDAwMCBuIAowMDAwMDAwNDEwIDAwMDAwIG4gCjAwMDAwMDA2MTcgMDAwMDAgbiAKdHJhaWxlcgo8PCAvU2l6ZSA4IC9Sb290IDEgMCBSIC9FbmNyeXB0IDYgMCBSIC9JbmZvIDcgMCBSIC9JRCBbPDAxMjM0NTY3ODlhYmNkZWY+PDAxMjM0NTY3ODlhYmNkZWY+XSA+PgpzdGFydHhyZWYKNjY4CiUlRU9GCg=="[:],
  ) catch {
    _ => b""
  }
}

///|
fn pdf_r6_encrypted() -> Bytes {
  @base64.decode(
    "JVBERi0xLjcKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgPj4KZW5kb2JqCjIgMCBvYmoKPDwgL1R5cGUgL1BhZ2VzIC9LaWRzIFszIDAgUl0gL0NvdW50IDEgPj4KZW5kb2JqCjMgMCBvYmoKPDwgL1R5cGUgL1BhZ2UgL1BhcmVudCAyIDAgUiAvTWVkaWFCb3ggWzAgMCAyMDAgMjAwXSAvUmVzb3VyY2VzIDw8IC9Gb250IDw8IC9GMSA1IDAgUiA+PiA+PiAvQ29udGVudHMgNCAwIFIgPj4KZW5kb2JqCjQgMCBvYmoKPDwgL0xlbmd0aCA4MCA+PgpzdHJlYW0KABEiM0RVZneImaq7zN3u/8GYaWvNLAIiW95NBfnh4ZavE8lIKlpQ86H8Fpi0YeACrBWHHNqsx8F+QApKv8SXxXfJus0pqRcjkKogFtqS330KZW5kc3RyZWFtCmVuZG9iago1IDAgb2JqCjw8IC9UeXBlIC9Gb250IC9TdWJ0eXBlIC9UeXBlMSAvQmFzZUZvbnQgL0hlbHZldGljYSA+PgplbmRvYmoKNiAwIG9iago8PCAvRmlsdGVyIC9TdGFuZGFyZCAvViA1IC9SIDYgL0xlbmd0aCAyNTYgL1AgLTQgL0NGIDw8IC9TdGRDRiA8PCAvQ0ZNIC9BRVNWMyAvTGVuZ3RoIDMyIC9BdXRoRXZlbnQgL0RvY09wZW4gPj4gPj4gL1N0bUYgL1N0ZENGIC9TdHJGIC9TdGRDRiAvTyA8Yzg1OWRjM2U3ODU2ZjZhZmM3ZDA5NGM2YjU1NWE1NjJkZmU4MTc3NThhNTk2MjQ3ZDJkZjZhNzg3ZTA3YTYyNjIxMjIyMzI0MjUyNjI3MjgzMTMyMzMzNDM1MzYzNzM4PiAvVSA8ZjczYzk1NDcyMmZiOGUzOWVjZDQyZDZmYmJhNjRjN2I3YzllMjA2NmQzZDI1MGNjYzk5MGJjMTgzYjRhYjViODAxMDIwMzA0MDUwNjA3MDgxMTEyMTMxNDE1MTYxNzE4PiAvT0UgPGYxYjA1ODdhODRjNzNmY2U5YWJhYzk2MWE2ZmRlZjkxZGFlNDRhMDZhYjg3NmVlYjBmMWEyMDdkNDAxZjYyZmQ+IC9VRSA8YWE5ZjE5NmFkODk3OGNjODM3NWUzZTYyMjE4ZDAwZGFmN2QyODUzNTQ1NjA2YzBlYjZkZTZkMDY2ZjU1MTYyOD4gPj4KZW5kb2JqCjcgMCBvYmoKPDwgL1RpdGxlIDwwMDExMjIzMzQ0NTU2Njc3ODg5OWFhYmJjY2RkZWVmZmM1MTcxMmNiYWViNGE5MWVhY2EzNDA2YTQzNmE3YTFlPiA+PgplbmRvYmoKeHJlZgowIDgKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwNTggMDAwMDAgbiAKMDAwMDAwMDExNSAwMDAwMCBuIAowMDAwMDAwMjQxIDAwMDAwIG4gCjAwMDAwMDAzNzEgMDAwMDAgbiAKMDAwMDAwMDQ0MSAwMDAwMCBuIAowMDAwMDAwOTQ2IDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgOCAvUm9vdCAxIDAgUiAvRW5jcnlwdCA2IDAgUiAvSW5mbyA3IDAgUiAvSUQgWzwwMTIzNDU2Nzg5YWJjZGVmPjwwMTIzNDU2Nzg5YWJjZGVmPl0gPj4Kc3RhcnR4cmVmCjEwNDEKJSVFT0YK"[:],
  ) catch {
    _ => b""
  }
}

///|
test "PDF R2 RC4 decryption opens with the user password" {
  let data = pdf_r2_encrypted()
  let file = pdf_open_file(data)
  file.unlock("secret")
  assert_eq(file.metadata().title, "Top Secret", msg="PDF R2 title")
  let result = convert(data, no_text_index=true, password="secret")
  assert_eq(result.pages, 1, msg="PDF R2 pages")
}

///|
test "PDF R4 AES-128 decryption opens with user and owner passwords" {
  let data = pdf_r4_encrypted()
  let user = pdf_open_file(data)
  user.unlock("secret")
  assert_eq(user.metadata().title, "Top Secret", msg="PDF R4 user title")
  let owner = pdf_open_file(data)
  owner.unlock("owner")
  assert_eq(owner.metadata().title, "Top Secret", msg="PDF R4 owner title")
  let result = convert(data, no_text_index=true, password="secret")
  assert_eq(result.pages, 1, msg="PDF R4 pages")
}

///|
test "PDF R3 RC4 decryption opens with the user password" {
  let data = pdf_r3_encrypted()
  let file = pdf_open_file(data)
  file.unlock("secret")
  assert_eq(file.metadata().title, "Top Secret", msg="PDF R3 title")
  let result = convert(data, no_text_index=true, password="secret")
  assert_eq(result.pages, 1, msg="PDF R3 pages")
}

///|
test "PDF R6 AES-256 decryption opens with user and owner passwords" {
  let data = pdf_r6_encrypted()
  let user = pdf_open_file(data)
  user.unlock("secret")
  assert_eq(user.metadata().title, "Top Secret", msg="PDF R6 user title")
  let owner = pdf_open_file(data)
  owner.unlock("owner")
  assert_eq(owner.metadata().title, "Top Secret", msg="PDF R6 owner title")
  let result = convert(data, no_text_index=true, password="secret")
  assert_eq(result.pages, 1, msg="PDF R6 pages")
}

///|
test "PDF encrypted files report empty and wrong passwords" {
  let empty = try {
    ignore(convert(pdf_r2_encrypted(), no_text_index=true))
    false
  } catch {
    PdfFailure(message) => message.contains("needs a password")
    _ => false
  }
  assert_true(empty, msg="PDF empty password error")
  let wrong = try {
    ignore(convert(pdf_r4_encrypted(), no_text_index=true, password="wrong"))
    false
  } catch {
    PdfFailure(message) => message.contains("incorrect")
    _ => false
  }
  assert_true(wrong, msg="PDF wrong password error")
}
