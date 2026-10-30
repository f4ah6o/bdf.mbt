///|
// Generated from the upstream PDF CMap parser.
test "PDF CMaps match upstream Go" {
  check_pdf_cmap(
    b"",
    false,
    [
      (0L, None, ""),
      (1L, None, ""),
      (2L, None, ""),
      (3L, None, ""),
      (4L, None, ""),
      (5L, None, ""),
      (6L, None, ""),
      (16L, None, ""),
      (17L, None, ""),
      (18L, None, ""),
      (24L, None, ""),
      (32L, None, ""),
      (33L, None, ""),
      (33090L, None, ""),
      (65535L, None, ""),
    ],
    [
      (
        b"\x00\x03\x10\x11\x81\x42",
        [
          { code: 3L, size: 2, cid: 0L, },
          { code: 4113L, size: 2, cid: 0L, },
          { code: 33090L, size: 2, cid: 0L, },
        ],
      ),
      (b"\x81", [{ code: 129L, size: 1, cid: 0L, }]),
      (
        b"\x00\x03\x00\x04",
        [{ code: 3L, size: 2, cid: 0L, }, { code: 4L, size: 2, cid: 0L, }],
      ),
      (
        b"\xff\xff\xff",
        [{ code: 65535L, size: 2, cid: 0L, }, { code: 255L, size: 1, cid: 0L, }],
      ),
      (
        b"\x01\x02\x03\x04\x05",
        [
          { code: 258L, size: 2, cid: 0L, },
          { code: 772L, size: 2, cid: 0L, },
          { code: 5L, size: 1, cid: 0L, },
        ],
      ),
    ],
  )
  check_pdf_cmap(
    b"\x31\x20\x62\x65\x67\x69\x6e\x63\x6f\x64\x65\x73\x70\x61\x63\x65\x72\x61\x6e\x67\x65\x20\x3c\x30\x30\x3e\x20\x3c\x66\x66\x3e\x20\x65\x6e\x64\x63\x6f\x64\x65\x73\x70\x61\x63\x65\x72\x61\x6e\x67\x65\x20\x32\x20\x62\x65\x67\x69\x6e\x62\x66\x63\x68\x61\x72\x20\x3c\x30\x33\x3e\x20\x3c\x30\x30\x34\x31\x3e\x20\x3c\x30\x34\x3e\x20\x3c\x30\x30\x36\x36\x30\x30\x36\x39\x3e\x20\x65\x6e\x64\x62\x66\x63\x68\x61\x72\x20\x31\x20\x62\x65\x67\x69\x6e\x62\x66\x72\x61\x6e\x67\x65\x20\x3c\x31\x30\x3e\x20\x3c\x31\x32\x3e\x20\x3c\x30\x30\x36\x31\x3e\x20\x65\x6e\x64\x62\x66\x72\x61\x6e\x67\x65\x20\x31\x20\x62\x65\x67\x69\x6e\x62\x66\x72\x61\x6e\x67\x65\x20\x3c\x32\x30\x3e\x20\x3c\x32\x31\x3e\x20\x5b\x3c\x30\x30\x37\x38\x3e\x20\x3c\x30\x30\x37\x39\x3e\x5d\x20\x65\x6e\x64\x62\x66\x72\x61\x6e\x67\x65",
    false,
    [
      (0L, None, ""),
      (1L, None, ""),
      (2L, None, ""),
      (3L, None, "A"),
      (4L, None, "fi"),
      (5L, None, ""),
      (6L, None, ""),
      (16L, None, "a"),
      (17L, None, "b"),
      (18L, None, "c"),
      (24L, None, ""),
      (32L, None, "x"),
      (33L, None, "y"),
      (33090L, None, ""),
      (65535L, None, ""),
    ],
    [
      (
        b"\x00\x03\x10\x11\x81\x42",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 16L, size: 1, cid: 0L, },
          { code: 17L, size: 1, cid: 0L, },
          { code: 129L, size: 1, cid: 0L, },
          { code: 66L, size: 1, cid: 0L, },
        ],
      ),
      (b"\x81", [{ code: 129L, size: 1, cid: 0L, }]),
      (
        b"\x00\x03\x00\x04",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 0L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\xff\xff\xff",
        [
          { code: 255L, size: 1, cid: 0L, },
          { code: 255L, size: 1, cid: 0L, },
          { code: 255L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\x01\x02\x03\x04\x05",
        [
          { code: 1L, size: 1, cid: 0L, },
          { code: 2L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
          { code: 5L, size: 1, cid: 0L, },
        ],
      ),
    ],
  )
  check_pdf_cmap(
    b"\x31\x20\x62\x65\x67\x69\x6e\x63\x6f\x64\x65\x73\x70\x61\x63\x65\x72\x61\x6e\x67\x65\x20\x3c\x30\x30\x3e\x20\x3c\x38\x30\x3e\x20\x3c\x38\x31\x34\x30\x3e\x20\x3c\x39\x66\x66\x63\x3e\x20\x65\x6e\x64\x63\x6f\x64\x65\x73\x70\x61\x63\x65\x72\x61\x6e\x67\x65\x20\x31\x20\x62\x65\x67\x69\x6e\x63\x69\x64\x72\x61\x6e\x67\x65\x20\x3c\x38\x31\x34\x30\x3e\x20\x3c\x38\x31\x35\x30\x3e\x20\x36\x33\x33\x20\x65\x6e\x64\x63\x69\x64\x72\x61\x6e\x67\x65",
    false,
    [
      (0L, None, ""),
      (1L, None, ""),
      (2L, None, ""),
      (3L, None, ""),
      (4L, None, ""),
      (5L, None, ""),
      (6L, None, ""),
      (16L, None, ""),
      (17L, None, ""),
      (18L, None, ""),
      (24L, None, ""),
      (32L, None, ""),
      (33L, None, ""),
      (33090L, Some(635L), ""),
      (65535L, None, ""),
    ],
    [
      (
        b"\x00\x03\x10\x11\x81\x42",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 16L, size: 1, cid: 0L, },
          { code: 17L, size: 1, cid: 0L, },
          { code: 33090L, size: 2, cid: 635L, },
        ],
      ),
      (b"\x81", [{ code: 129L, size: 1, cid: 0L, }]),
      (
        b"\x00\x03\x00\x04",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 0L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\xff\xff\xff",
        [
          { code: 255L, size: 1, cid: 0L, },
          { code: 255L, size: 1, cid: 0L, },
          { code: 255L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\x01\x02\x03\x04\x05",
        [
          { code: 1L, size: 1, cid: 0L, },
          { code: 2L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
          { code: 5L, size: 1, cid: 0L, },
        ],
      ),
    ],
  )
  check_pdf_cmap(
    b"\x32\x20\x62\x65\x67\x69\x6e\x63\x69\x64\x72\x61\x6e\x67\x65\x20\x3c\x31\x30\x3e\x20\x3c\x32\x30\x3e\x20\x31\x30\x20\x3c\x31\x35\x3e\x20\x3c\x32\x35\x3e\x20\x34\x30\x20\x65\x6e\x64\x63\x69\x64\x72\x61\x6e\x67\x65\x20\x31\x20\x62\x65\x67\x69\x6e\x63\x69\x64\x63\x68\x61\x72\x20\x3c\x31\x38\x3e\x20\x31\x32\x33\x20\x65\x6e\x64\x63\x69\x64\x63\x68\x61\x72",
    false,
    [
      (0L, None, ""),
      (1L, None, ""),
      (2L, None, ""),
      (3L, None, ""),
      (4L, None, ""),
      (5L, None, ""),
      (6L, None, ""),
      (16L, Some(10L), ""),
      (17L, Some(11L), ""),
      (18L, Some(12L), ""),
      (24L, Some(123L), ""),
      (32L, Some(26L), ""),
      (33L, Some(52L), ""),
      (33090L, None, ""),
      (65535L, None, ""),
    ],
    [
      (
        b"\x00\x03\x10\x11\x81\x42",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 16L, size: 1, cid: 10L, },
          { code: 17L, size: 1, cid: 11L, },
          { code: 129L, size: 1, cid: 0L, },
          { code: 66L, size: 1, cid: 0L, },
        ],
      ),
      (b"\x81", [{ code: 129L, size: 1, cid: 0L, }]),
      (
        b"\x00\x03\x00\x04",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 0L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\xff\xff\xff",
        [
          { code: 255L, size: 1, cid: 0L, },
          { code: 255L, size: 1, cid: 0L, },
          { code: 255L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\x01\x02\x03\x04\x05",
        [
          { code: 1L, size: 1, cid: 0L, },
          { code: 2L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
          { code: 5L, size: 1, cid: 0L, },
        ],
      ),
    ],
  )
  check_pdf_cmap(
    b"\x31\x20\x62\x65\x67\x69\x6e\x62\x66\x63\x68\x61\x72\x20\x3c\x30\x33\x3e\x20\x2f\x41\x61\x63\x75\x74\x65\x20\x3c\x30\x34\x3e\x20\x2f\x75\x6e\x69\x30\x33\x41\x39\x20\x3c\x30\x35\x3e\x20\x2f\x75\x31\x46\x36\x30\x30\x20\x3c\x30\x36\x3e\x20\x2f\x41\x2e\x61\x6c\x74\x20\x65\x6e\x64\x62\x66\x63\x68\x61\x72",
    false,
    [
      (0L, None, ""),
      (1L, None, ""),
      (2L, None, ""),
      (3L, None, "Á"),
      (4L, None, "Ω"),
      (5L, None, "😀"),
      (6L, None, "A"),
      (16L, None, ""),
      (17L, None, ""),
      (18L, None, ""),
      (24L, None, ""),
      (32L, None, ""),
      (33L, None, ""),
      (33090L, None, ""),
      (65535L, None, ""),
    ],
    [
      (
        b"\x00\x03\x10\x11\x81\x42",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 16L, size: 1, cid: 0L, },
          { code: 17L, size: 1, cid: 0L, },
          { code: 129L, size: 1, cid: 0L, },
          { code: 66L, size: 1, cid: 0L, },
        ],
      ),
      (b"\x81", [{ code: 129L, size: 1, cid: 0L, }]),
      (
        b"\x00\x03\x00\x04",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 0L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\xff\xff\xff",
        [
          { code: 255L, size: 1, cid: 0L, },
          { code: 255L, size: 1, cid: 0L, },
          { code: 255L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\x01\x02\x03\x04\x05",
        [
          { code: 1L, size: 1, cid: 0L, },
          { code: 2L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
          { code: 5L, size: 1, cid: 0L, },
        ],
      ),
    ],
  )
  check_pdf_cmap(
    b"\x31\x20\x62\x65\x67\x69\x6e\x62\x66\x63\x68\x61\x72\x20\x3c\x30\x33\x3e\x20\x3c\x64\x38\x33\x64\x64\x65\x30\x30\x3e\x20\x3c\x30\x34\x3e\x20\x3c\x64\x38\x30\x30\x30\x30\x34\x31\x3e\x20\x3c\x30\x35\x3e\x20\x3c\x64\x66\x66\x66\x3e\x20\x3c\x30\x36\x3e\x20\x3c\x34\x31\x3e\x20\x65\x6e\x64\x62\x66\x63\x68\x61\x72",
    false,
    [
      (0L, None, ""),
      (1L, None, ""),
      (2L, None, ""),
      (3L, None, "😀"),
      (4L, None, "⑁"),
      (5L, None, "�"),
      (6L, None, "A"),
      (16L, None, ""),
      (17L, None, ""),
      (18L, None, ""),
      (24L, None, ""),
      (32L, None, ""),
      (33L, None, ""),
      (33090L, None, ""),
      (65535L, None, ""),
    ],
    [
      (
        b"\x00\x03\x10\x11\x81\x42",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 16L, size: 1, cid: 0L, },
          { code: 17L, size: 1, cid: 0L, },
          { code: 129L, size: 1, cid: 0L, },
          { code: 66L, size: 1, cid: 0L, },
        ],
      ),
      (b"\x81", [{ code: 129L, size: 1, cid: 0L, }]),
      (
        b"\x00\x03\x00\x04",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 0L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\xff\xff\xff",
        [
          { code: 255L, size: 1, cid: 0L, },
          { code: 255L, size: 1, cid: 0L, },
          { code: 255L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\x01\x02\x03\x04\x05",
        [
          { code: 1L, size: 1, cid: 0L, },
          { code: 2L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
          { code: 5L, size: 1, cid: 0L, },
        ],
      ),
    ],
  )
  check_pdf_cmap(
    b"\x2f\x49\x64\x65\x6e\x74\x69\x74\x79\x2d\x48\x20\x75\x73\x65\x63\x6d\x61\x70",
    false,
    [
      (0L, Some(0L), ""),
      (1L, Some(1L), ""),
      (2L, Some(2L), ""),
      (3L, Some(3L), ""),
      (4L, Some(4L), ""),
      (5L, Some(5L), ""),
      (6L, Some(6L), ""),
      (16L, Some(16L), ""),
      (17L, Some(17L), ""),
      (18L, Some(18L), ""),
      (24L, Some(24L), ""),
      (32L, Some(32L), ""),
      (33L, Some(33L), ""),
      (33090L, Some(33090L), ""),
      (65535L, Some(65535L), ""),
    ],
    [
      (
        b"\x00\x03\x10\x11\x81\x42",
        [
          { code: 3L, size: 2, cid: 3L, },
          { code: 4113L, size: 2, cid: 4113L, },
          { code: 33090L, size: 2, cid: 33090L, },
        ],
      ),
      (b"\x81", [{ code: 129L, size: 1, cid: 129L, }]),
      (
        b"\x00\x03\x00\x04",
        [{ code: 3L, size: 2, cid: 3L, }, { code: 4L, size: 2, cid: 4L, }],
      ),
      (
        b"\xff\xff\xff",
        [
          { code: 65535L, size: 2, cid: 65535L, },
          { code: 255L, size: 1, cid: 255L, },
        ],
      ),
      (
        b"\x01\x02\x03\x04\x05",
        [
          { code: 258L, size: 2, cid: 258L, },
          { code: 772L, size: 2, cid: 772L, },
          { code: 5L, size: 1, cid: 5L, },
        ],
      ),
    ],
  )
  check_pdf_cmap(
    b"\x2f\x49\x64\x65\x6e\x74\x69\x74\x79\x2d\x56\x20\x75\x73\x65\x63\x6d\x61\x70",
    true,
    [
      (0L, Some(0L), ""),
      (1L, Some(1L), ""),
      (2L, Some(2L), ""),
      (3L, Some(3L), ""),
      (4L, Some(4L), ""),
      (5L, Some(5L), ""),
      (6L, Some(6L), ""),
      (16L, Some(16L), ""),
      (17L, Some(17L), ""),
      (18L, Some(18L), ""),
      (24L, Some(24L), ""),
      (32L, Some(32L), ""),
      (33L, Some(33L), ""),
      (33090L, Some(33090L), ""),
      (65535L, Some(65535L), ""),
    ],
    [
      (
        b"\x00\x03\x10\x11\x81\x42",
        [
          { code: 3L, size: 2, cid: 3L, },
          { code: 4113L, size: 2, cid: 4113L, },
          { code: 33090L, size: 2, cid: 33090L, },
        ],
      ),
      (b"\x81", [{ code: 129L, size: 1, cid: 129L, }]),
      (
        b"\x00\x03\x00\x04",
        [{ code: 3L, size: 2, cid: 3L, }, { code: 4L, size: 2, cid: 4L, }],
      ),
      (
        b"\xff\xff\xff",
        [
          { code: 65535L, size: 2, cid: 65535L, },
          { code: 255L, size: 1, cid: 255L, },
        ],
      ),
      (
        b"\x01\x02\x03\x04\x05",
        [
          { code: 258L, size: 2, cid: 258L, },
          { code: 772L, size: 2, cid: 772L, },
          { code: 5L, size: 1, cid: 5L, },
        ],
      ),
    ],
  )
  check_pdf_cmap(
    b"\x2f\x49\x64\x65\x6e\x74\x69\x74\x79\x2d\x56\x20\x75\x73\x65\x63\x6d\x61\x70\x20\x2f\x57\x4d\x6f\x64\x65\x20\x30\x20\x64\x65\x66",
    false,
    [
      (0L, Some(0L), ""),
      (1L, Some(1L), ""),
      (2L, Some(2L), ""),
      (3L, Some(3L), ""),
      (4L, Some(4L), ""),
      (5L, Some(5L), ""),
      (6L, Some(6L), ""),
      (16L, Some(16L), ""),
      (17L, Some(17L), ""),
      (18L, Some(18L), ""),
      (24L, Some(24L), ""),
      (32L, Some(32L), ""),
      (33L, Some(33L), ""),
      (33090L, Some(33090L), ""),
      (65535L, Some(65535L), ""),
    ],
    [
      (
        b"\x00\x03\x10\x11\x81\x42",
        [
          { code: 3L, size: 2, cid: 3L, },
          { code: 4113L, size: 2, cid: 4113L, },
          { code: 33090L, size: 2, cid: 33090L, },
        ],
      ),
      (b"\x81", [{ code: 129L, size: 1, cid: 129L, }]),
      (
        b"\x00\x03\x00\x04",
        [{ code: 3L, size: 2, cid: 3L, }, { code: 4L, size: 2, cid: 4L, }],
      ),
      (
        b"\xff\xff\xff",
        [
          { code: 65535L, size: 2, cid: 65535L, },
          { code: 255L, size: 1, cid: 255L, },
        ],
      ),
      (
        b"\x01\x02\x03\x04\x05",
        [
          { code: 258L, size: 2, cid: 258L, },
          { code: 772L, size: 2, cid: 772L, },
          { code: 5L, size: 1, cid: 5L, },
        ],
      ),
    ],
  )
  check_pdf_cmap(
    b"\x2f\x39\x30\x6d\x73\x2d\x52\x4b\x53\x4a\x2d\x48\x20\x75\x73\x65\x63\x6d\x61\x70",
    false,
    [
      (0L, None, ""),
      (1L, None, ""),
      (2L, None, ""),
      (3L, None, ""),
      (4L, None, ""),
      (5L, None, ""),
      (6L, None, ""),
      (16L, None, ""),
      (17L, None, ""),
      (18L, None, ""),
      (24L, None, ""),
      (32L, Some(231L), ""),
      (33L, Some(232L), ""),
      (33090L, Some(635L), ""),
      (65535L, None, ""),
    ],
    [
      (
        b"\x00\x03\x10\x11\x81\x42",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 16L, size: 1, cid: 0L, },
          { code: 17L, size: 1, cid: 0L, },
          { code: 33090L, size: 2, cid: 635L, },
        ],
      ),
      (b"\x81", [{ code: 129L, size: 1, cid: 0L, }]),
      (
        b"\x00\x03\x00\x04",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 0L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\xff\xff\xff",
        [
          { code: 255L, size: 1, cid: 124L, },
          { code: 255L, size: 1, cid: 124L, },
          { code: 255L, size: 1, cid: 124L, },
        ],
      ),
      (
        b"\x01\x02\x03\x04\x05",
        [
          { code: 1L, size: 1, cid: 0L, },
          { code: 2L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
          { code: 5L, size: 1, cid: 0L, },
        ],
      ),
    ],
  )
  check_pdf_cmap(
    b"\x2f\x39\x30\x6d\x73\x2d\x52\x4b\x53\x4a\x2d\x56\x20\x75\x73\x65\x63\x6d\x61\x70",
    true,
    [
      (0L, None, ""),
      (1L, None, ""),
      (2L, None, ""),
      (3L, None, ""),
      (4L, None, ""),
      (5L, None, ""),
      (6L, None, ""),
      (16L, None, ""),
      (17L, None, ""),
      (18L, None, ""),
      (24L, None, ""),
      (32L, Some(231L), ""),
      (33L, Some(232L), ""),
      (33090L, Some(7888L), ""),
      (65535L, None, ""),
    ],
    [
      (
        b"\x00\x03\x10\x11\x81\x42",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 16L, size: 1, cid: 0L, },
          { code: 17L, size: 1, cid: 0L, },
          { code: 33090L, size: 2, cid: 7888L, },
        ],
      ),
      (b"\x81", [{ code: 129L, size: 1, cid: 0L, }]),
      (
        b"\x00\x03\x00\x04",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 0L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\xff\xff\xff",
        [
          { code: 255L, size: 1, cid: 124L, },
          { code: 255L, size: 1, cid: 124L, },
          { code: 255L, size: 1, cid: 124L, },
        ],
      ),
      (
        b"\x01\x02\x03\x04\x05",
        [
          { code: 1L, size: 1, cid: 0L, },
          { code: 2L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
          { code: 5L, size: 1, cid: 0L, },
        ],
      ),
    ],
  )
  check_pdf_cmap(
    b"\x2f\x55\x6e\x69\x4a\x49\x53\x2d\x55\x54\x46\x38\x2d\x48\x20\x75\x73\x65\x63\x6d\x61\x70",
    false,
    [
      (0L, None, ""),
      (1L, None, ""),
      (2L, None, ""),
      (3L, None, ""),
      (4L, None, ""),
      (5L, None, ""),
      (6L, None, ""),
      (16L, None, ""),
      (17L, None, ""),
      (18L, None, ""),
      (24L, None, ""),
      (32L, Some(1L), ""),
      (33L, Some(2L), ""),
      (33090L, None, ""),
      (65535L, None, ""),
    ],
    [
      (
        b"\x00\x03\x10\x11\x81\x42",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 16L, size: 1, cid: 0L, },
          { code: 17L, size: 1, cid: 0L, },
          { code: 129L, size: 1, cid: 0L, },
          { code: 66L, size: 1, cid: 35L, },
        ],
      ),
      (b"\x81", [{ code: 129L, size: 1, cid: 0L, }]),
      (
        b"\x00\x03\x00\x04",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 0L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\xff\xff\xff",
        [
          { code: 255L, size: 1, cid: 0L, },
          { code: 255L, size: 1, cid: 0L, },
          { code: 255L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\x01\x02\x03\x04\x05",
        [
          { code: 1L, size: 1, cid: 0L, },
          { code: 2L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
          { code: 5L, size: 1, cid: 0L, },
        ],
      ),
    ],
  )
  check_pdf_cmap(
    b"\x2f\x55\x6e\x69\x4a\x49\x53\x2d\x55\x54\x46\x31\x36\x2d\x56\x20\x75\x73\x65\x63\x6d\x61\x70",
    true,
    [
      (0L, None, ""),
      (1L, None, ""),
      (2L, None, ""),
      (3L, None, ""),
      (4L, None, ""),
      (5L, None, ""),
      (6L, None, ""),
      (16L, None, ""),
      (17L, None, ""),
      (18L, None, ""),
      (24L, None, ""),
      (32L, Some(1L), ""),
      (33L, Some(2L), ""),
      (33090L, None, ""),
      (65535L, None, ""),
    ],
    [
      (
        b"\x00\x03\x10\x11\x81\x42",
        [
          { code: 3L, size: 2, cid: 0L, },
          { code: 4113L, size: 2, cid: 0L, },
          { code: 33090L, size: 2, cid: 0L, },
        ],
      ),
      (b"\x81", [{ code: 129L, size: 1, cid: 0L, }]),
      (
        b"\x00\x03\x00\x04",
        [{ code: 3L, size: 2, cid: 0L, }, { code: 4L, size: 2, cid: 0L, }],
      ),
      (
        b"\xff\xff\xff",
        [
          { code: 65535L, size: 2, cid: 0L, },
          { code: 255L, size: 1, cid: 222L, },
        ],
      ),
      (
        b"\x01\x02\x03\x04\x05",
        [
          { code: 258L, size: 2, cid: 15756L, },
          { code: 772L, size: 2, cid: 129L, },
          { code: 5L, size: 1, cid: 0L, },
        ],
      ),
    ],
  )
  check_pdf_cmap(
    b"\x2f\x55\x6e\x69\x47\x42\x2d\x55\x43\x53\x32\x2d\x48\x20\x75\x73\x65\x63\x6d\x61\x70",
    false,
    [
      (0L, None, ""),
      (1L, None, ""),
      (2L, None, ""),
      (3L, None, ""),
      (4L, None, ""),
      (5L, None, ""),
      (6L, None, ""),
      (16L, None, ""),
      (17L, None, ""),
      (18L, None, ""),
      (24L, None, ""),
      (32L, Some(1L), ""),
      (33L, Some(2L), ""),
      (33090L, Some(17659L), ""),
      (65535L, None, ""),
    ],
    [
      (
        b"\x00\x03\x10\x11\x81\x42",
        [
          { code: 3L, size: 2, cid: 0L, },
          { code: 4113L, size: 2, cid: 0L, },
          { code: 33090L, size: 2, cid: 17659L, },
        ],
      ),
      (b"\x81", [{ code: 129L, size: 1, cid: 0L, }]),
      (
        b"\x00\x03\x00\x04",
        [{ code: 3L, size: 2, cid: 0L, }, { code: 4L, size: 2, cid: 0L, }],
      ),
      (
        b"\xff\xff\xff",
        [{ code: 65535L, size: 2, cid: 0L, }, { code: 255L, size: 1, cid: 0L, }],
      ),
      (
        b"\x01\x02\x03\x04\x05",
        [
          { code: 258L, size: 2, cid: 0L, },
          { code: 772L, size: 2, cid: 0L, },
          { code: 5L, size: 1, cid: 0L, },
        ],
      ),
    ],
  )
  check_pdf_cmap(
    b"\x31\x20\x62\x65\x67\x69\x6e\x62\x66\x63\x68\x61\x72\x20\x3c\x30\x30\x30\x33\x3e\x20\x3c\x30\x30\x34\x31\x3e\x20\x65\x6e\x64\x62\x66\x63\x68\x61\x72",
    false,
    [
      (0L, None, ""),
      (1L, None, ""),
      (2L, None, ""),
      (3L, None, "A"),
      (4L, None, ""),
      (5L, None, ""),
      (6L, None, ""),
      (16L, None, ""),
      (17L, None, ""),
      (18L, None, ""),
      (24L, None, ""),
      (32L, None, ""),
      (33L, None, ""),
      (33090L, None, ""),
      (65535L, None, ""),
    ],
    [
      (
        b"\x00\x03\x10\x11\x81\x42",
        [
          { code: 3L, size: 2, cid: 0L, },
          { code: 4113L, size: 2, cid: 0L, },
          { code: 33090L, size: 2, cid: 0L, },
        ],
      ),
      (b"\x81", [{ code: 129L, size: 1, cid: 0L, }]),
      (
        b"\x00\x03\x00\x04",
        [{ code: 3L, size: 2, cid: 0L, }, { code: 4L, size: 2, cid: 0L, }],
      ),
      (
        b"\xff\xff\xff",
        [{ code: 65535L, size: 2, cid: 0L, }, { code: 255L, size: 1, cid: 0L, }],
      ),
      (
        b"\x01\x02\x03\x04\x05",
        [
          { code: 258L, size: 2, cid: 0L, },
          { code: 772L, size: 2, cid: 0L, },
          { code: 5L, size: 1, cid: 0L, },
        ],
      ),
    ],
  )
  check_pdf_cmap(
    b"\x32\x20\x62\x65\x67\x69\x6e\x63\x69\x64\x63\x68\x61\x72\x20\x3c\x30\x30\x3e\x20\x31\x20\x3c\x31\x30\x30\x30\x3e\x20\x32\x32\x20\x65\x6e\x64\x63\x69\x64\x63\x68\x61\x72",
    false,
    [
      (0L, Some(1L), ""),
      (1L, None, ""),
      (2L, None, ""),
      (3L, None, ""),
      (4L, None, ""),
      (5L, None, ""),
      (6L, None, ""),
      (16L, None, ""),
      (17L, None, ""),
      (18L, None, ""),
      (24L, None, ""),
      (32L, None, ""),
      (33L, None, ""),
      (33090L, None, ""),
      (65535L, None, ""),
    ],
    [
      (
        b"\x00\x03\x10\x11\x81\x42",
        [
          { code: 0L, size: 1, cid: 1L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 16L, size: 1, cid: 0L, },
          { code: 17L, size: 1, cid: 0L, },
          { code: 129L, size: 1, cid: 0L, },
          { code: 66L, size: 1, cid: 0L, },
        ],
      ),
      (b"\x81", [{ code: 129L, size: 1, cid: 0L, }]),
      (
        b"\x00\x03\x00\x04",
        [
          { code: 0L, size: 1, cid: 1L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 0L, size: 1, cid: 1L, },
          { code: 4L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\xff\xff\xff",
        [
          { code: 255L, size: 1, cid: 0L, },
          { code: 255L, size: 1, cid: 0L, },
          { code: 255L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\x01\x02\x03\x04\x05",
        [
          { code: 1L, size: 1, cid: 0L, },
          { code: 2L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
          { code: 5L, size: 1, cid: 0L, },
        ],
      ),
    ],
  )
  check_pdf_cmap(
    b"\x31\x20\x62\x65\x67\x69\x6e\x62\x66\x72\x61\x6e\x67\x65\x20\x3c\x30\x31\x3e\x20\x3c\x30\x33\x3e\x20\x3c\x30\x30\x34\x31\x3e\x20\x65\x6e\x64\x62\x66\x72\x61\x6e\x67\x65",
    false,
    [
      (0L, None, ""),
      (1L, None, "A"),
      (2L, None, "B"),
      (3L, None, "C"),
      (4L, None, ""),
      (5L, None, ""),
      (6L, None, ""),
      (16L, None, ""),
      (17L, None, ""),
      (18L, None, ""),
      (24L, None, ""),
      (32L, None, ""),
      (33L, None, ""),
      (33090L, None, ""),
      (65535L, None, ""),
    ],
    [
      (
        b"\x00\x03\x10\x11\x81\x42",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 16L, size: 1, cid: 0L, },
          { code: 17L, size: 1, cid: 0L, },
          { code: 129L, size: 1, cid: 0L, },
          { code: 66L, size: 1, cid: 0L, },
        ],
      ),
      (b"\x81", [{ code: 129L, size: 1, cid: 0L, }]),
      (
        b"\x00\x03\x00\x04",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 0L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\xff\xff\xff",
        [
          { code: 255L, size: 1, cid: 0L, },
          { code: 255L, size: 1, cid: 0L, },
          { code: 255L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\x01\x02\x03\x04\x05",
        [
          { code: 1L, size: 1, cid: 0L, },
          { code: 2L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
          { code: 5L, size: 1, cid: 0L, },
        ],
      ),
    ],
  )
  check_pdf_cmap(
    b"\x31\x20\x62\x65\x67\x69\x6e\x62\x66\x72\x61\x6e\x67\x65\x20\x3c\x30\x31\x3e\x20\x3c\x30\x31\x3e\x20\x5b\x3c\x30\x30\x34\x31\x3e\x20\x3c\x30\x30\x34\x32\x3e\x20\x3c\x30\x30\x34\x33\x3e\x5d\x20\x65\x6e\x64\x62\x66\x72\x61\x6e\x67\x65",
    false,
    [
      (0L, None, ""),
      (1L, None, "A"),
      (2L, None, "B"),
      (3L, None, "C"),
      (4L, None, ""),
      (5L, None, ""),
      (6L, None, ""),
      (16L, None, ""),
      (17L, None, ""),
      (18L, None, ""),
      (24L, None, ""),
      (32L, None, ""),
      (33L, None, ""),
      (33090L, None, ""),
      (65535L, None, ""),
    ],
    [
      (
        b"\x00\x03\x10\x11\x81\x42",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 16L, size: 1, cid: 0L, },
          { code: 17L, size: 1, cid: 0L, },
          { code: 129L, size: 1, cid: 0L, },
          { code: 66L, size: 1, cid: 0L, },
        ],
      ),
      (b"\x81", [{ code: 129L, size: 1, cid: 0L, }]),
      (
        b"\x00\x03\x00\x04",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 0L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\xff\xff\xff",
        [
          { code: 255L, size: 1, cid: 0L, },
          { code: 255L, size: 1, cid: 0L, },
          { code: 255L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\x01\x02\x03\x04\x05",
        [
          { code: 1L, size: 1, cid: 0L, },
          { code: 2L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
          { code: 5L, size: 1, cid: 0L, },
        ],
      ),
    ],
  )
  check_pdf_cmap(
    b"\x31\x20\x62\x65\x67\x69\x6e\x63\x6f\x64\x65\x73\x70\x61\x63\x65\x72\x61\x6e\x67\x65\x20\x3c\x30\x30\x30\x30\x3e\x20\x3c\x66\x66\x66\x66\x3e\x20\x65\x6e\x64\x63\x6f\x64\x65\x73\x70\x61\x63\x65\x72\x61\x6e\x67\x65",
    false,
    [
      (0L, None, ""),
      (1L, None, ""),
      (2L, None, ""),
      (3L, None, ""),
      (4L, None, ""),
      (5L, None, ""),
      (6L, None, ""),
      (16L, None, ""),
      (17L, None, ""),
      (18L, None, ""),
      (24L, None, ""),
      (32L, None, ""),
      (33L, None, ""),
      (33090L, None, ""),
      (65535L, None, ""),
    ],
    [
      (
        b"\x00\x03\x10\x11\x81\x42",
        [
          { code: 3L, size: 2, cid: 0L, },
          { code: 4113L, size: 2, cid: 0L, },
          { code: 33090L, size: 2, cid: 0L, },
        ],
      ),
      (b"\x81", [{ code: 129L, size: 1, cid: 0L, }]),
      (
        b"\x00\x03\x00\x04",
        [{ code: 3L, size: 2, cid: 0L, }, { code: 4L, size: 2, cid: 0L, }],
      ),
      (
        b"\xff\xff\xff",
        [{ code: 65535L, size: 2, cid: 0L, }, { code: 255L, size: 1, cid: 0L, }],
      ),
      (
        b"\x01\x02\x03\x04\x05",
        [
          { code: 258L, size: 2, cid: 0L, },
          { code: 772L, size: 2, cid: 0L, },
          { code: 5L, size: 1, cid: 0L, },
        ],
      ),
    ],
  )
  check_pdf_cmap(
    b"\x31\x20\x62\x65\x67\x69\x6e\x63\x6f\x64\x65\x73\x70\x61\x63\x65\x72\x61\x6e\x67\x65\x20\x3c\x30\x30\x30\x30\x30\x30\x30\x30\x30\x30\x3e\x20\x3c\x66\x66\x66\x66\x66\x66\x66\x66\x66\x66\x3e\x20\x65\x6e\x64\x63\x6f\x64\x65\x73\x70\x61\x63\x65\x72\x61\x6e\x67\x65",
    false,
    [
      (0L, None, ""),
      (1L, None, ""),
      (2L, None, ""),
      (3L, None, ""),
      (4L, None, ""),
      (5L, None, ""),
      (6L, None, ""),
      (16L, None, ""),
      (17L, None, ""),
      (18L, None, ""),
      (24L, None, ""),
      (32L, None, ""),
      (33L, None, ""),
      (33090L, None, ""),
      (65535L, None, ""),
    ],
    [
      (
        b"\x00\x03\x10\x11\x81\x42",
        [
          { code: 51384705L, size: 5, cid: 0L, },
          { code: 66L, size: 1, cid: 0L, },
        ],
      ),
      (b"\x81", [{ code: 129L, size: 1, cid: 0L, }]),
      (b"\x00\x03\x00\x04", [{ code: 196612L, size: 4, cid: 0L, }]),
      (b"\xff\xff\xff", [{ code: 16777215L, size: 3, cid: 0L, }]),
      (b"\x01\x02\x03\x04\x05", [{ code: 33752069L, size: 5, cid: 0L, }]),
    ],
  )
  check_pdf_cmap(
    b"\x32\x20\x62\x65\x67\x69\x6e\x63\x69\x64\x63\x68\x61\x72\x20\x3c\x30\x31\x3e\x20\x2d\x31\x20\x3c\x30\x32\x3e\x20\x34\x32\x39\x34\x39\x36\x37\x32\x39\x37\x20\x65\x6e\x64\x63\x69\x64\x63\x68\x61\x72",
    false,
    [
      (0L, None, ""),
      (1L, Some(4294967295L), ""),
      (2L, Some(1L), ""),
      (3L, None, ""),
      (4L, None, ""),
      (5L, None, ""),
      (6L, None, ""),
      (16L, None, ""),
      (17L, None, ""),
      (18L, None, ""),
      (24L, None, ""),
      (32L, None, ""),
      (33L, None, ""),
      (33090L, None, ""),
      (65535L, None, ""),
    ],
    [
      (
        b"\x00\x03\x10\x11\x81\x42",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 16L, size: 1, cid: 0L, },
          { code: 17L, size: 1, cid: 0L, },
          { code: 129L, size: 1, cid: 0L, },
          { code: 66L, size: 1, cid: 0L, },
        ],
      ),
      (b"\x81", [{ code: 129L, size: 1, cid: 0L, }]),
      (
        b"\x00\x03\x00\x04",
        [
          { code: 0L, size: 1, cid: 0L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 0L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\xff\xff\xff",
        [
          { code: 255L, size: 1, cid: 0L, },
          { code: 255L, size: 1, cid: 0L, },
          { code: 255L, size: 1, cid: 0L, },
        ],
      ),
      (
        b"\x01\x02\x03\x04\x05",
        [
          { code: 1L, size: 1, cid: 4294967295L, },
          { code: 2L, size: 1, cid: 1L, },
          { code: 3L, size: 1, cid: 0L, },
          { code: 4L, size: 1, cid: 0L, },
          { code: 5L, size: 1, cid: 0L, },
        ],
      ),
    ],
  )
}

///|
test "PDF CMap parents match upstream Go" {
  check_pdf_cmap_parent(
    b"\x32\x20\x62\x65\x67\x69\x6e\x63\x69\x64\x63\x68\x61\x72\x20\x3c\x30\x31\x3e\x20\x31\x37\x20\x3c\x30\x32\x3e\x20\x33\x30\x20\x65\x6e\x64\x63\x69\x64\x63\x68\x61\x72\x20\x2f\x57\x4d\x6f\x64\x65\x20\x31\x20\x64\x65\x66",
    b"\x31\x20\x62\x65\x67\x69\x6e\x63\x69\x64\x63\x68\x61\x72\x20\x3c\x30\x31\x3e\x20\x34\x34\x20\x65\x6e\x64\x63\x69\x64\x63\x68\x61\x72",
    true,
    [
      (0L, None),
      (1L, Some(44L)),
      (2L, Some(30L)),
      (3L, None),
      (4L, None),
      (5L, None),
      (6L, None),
      (16L, None),
      (17L, None),
      (18L, None),
      (24L, None),
      (32L, None),
      (33L, None),
      (33090L, None),
      (65535L, None),
    ],
  )
  check_pdf_cmap_parent(
    b"\x32\x20\x62\x65\x67\x69\x6e\x63\x69\x64\x63\x68\x61\x72\x20\x3c\x30\x31\x3e\x20\x31\x37\x20\x3c\x30\x32\x3e\x20\x33\x30\x20\x65\x6e\x64\x63\x69\x64\x63\x68\x61\x72\x20\x2f\x57\x4d\x6f\x64\x65\x20\x31\x20\x64\x65\x66",
    b"\x2f\x57\x4d\x6f\x64\x65\x20\x30\x20\x64\x65\x66",
    false,
    [
      (0L, None),
      (1L, Some(17L)),
      (2L, Some(30L)),
      (3L, None),
      (4L, None),
      (5L, None),
      (6L, None),
      (16L, None),
      (17L, None),
      (18L, None),
      (24L, None),
      (32L, None),
      (33L, None),
      (33090L, None),
      (65535L, None),
    ],
  )
  check_pdf_cmap_parent(
    b"\x32\x20\x62\x65\x67\x69\x6e\x63\x69\x64\x63\x68\x61\x72\x20\x3c\x30\x31\x3e\x20\x31\x37\x20\x3c\x30\x32\x3e\x20\x33\x30\x20\x65\x6e\x64\x63\x69\x64\x63\x68\x61\x72\x20\x2f\x57\x4d\x6f\x64\x65\x20\x31\x20\x64\x65\x66",
    b"\x31\x20\x62\x65\x67\x69\x6e\x63\x69\x64\x72\x61\x6e\x67\x65\x20\x3c\x31\x30\x3e\x20\x3c\x32\x30\x3e\x20\x38\x30\x20\x65\x6e\x64\x63\x69\x64\x72\x61\x6e\x67\x65",
    true,
    [
      (0L, None),
      (1L, Some(17L)),
      (2L, Some(30L)),
      (3L, None),
      (4L, None),
      (5L, None),
      (6L, None),
      (16L, Some(80L)),
      (17L, Some(81L)),
      (18L, Some(82L)),
      (24L, Some(88L)),
      (32L, Some(96L)),
      (33L, None),
      (33090L, None),
      (65535L, None),
    ],
  )
  check_pdf_cmap_parent(
    b"\x32\x20\x62\x65\x67\x69\x6e\x63\x69\x64\x63\x68\x61\x72\x20\x3c\x30\x31\x3e\x20\x31\x37\x20\x3c\x30\x32\x3e\x20\x33\x30\x20\x65\x6e\x64\x63\x69\x64\x63\x68\x61\x72\x20\x2f\x57\x4d\x6f\x64\x65\x20\x31\x20\x64\x65\x66",
    b"",
    true,
    [
      (0L, None),
      (1L, Some(17L)),
      (2L, Some(30L)),
      (3L, None),
      (4L, None),
      (5L, None),
      (6L, None),
      (16L, None),
      (17L, None),
      (18L, None),
      (24L, None),
      (32L, None),
      (33L, None),
      (33090L, None),
      (65535L, None),
    ],
  )
  check_pdf_cmap_parent(
    b"\x2f\x49\x64\x65\x6e\x74\x69\x74\x79\x2d\x56\x20\x75\x73\x65\x63\x6d\x61\x70",
    b"\x31\x20\x62\x65\x67\x69\x6e\x63\x69\x64\x63\x68\x61\x72\x20\x3c\x30\x31\x3e\x20\x34\x34\x20\x65\x6e\x64\x63\x69\x64\x63\x68\x61\x72",
    true,
    [
      (0L, Some(0L)),
      (1L, Some(44L)),
      (2L, Some(2L)),
      (3L, Some(3L)),
      (4L, Some(4L)),
      (5L, Some(5L)),
      (6L, Some(6L)),
      (16L, Some(16L)),
      (17L, Some(17L)),
      (18L, Some(18L)),
      (24L, Some(24L)),
      (32L, Some(32L)),
      (33L, Some(33L)),
      (33090L, Some(33090L)),
      (65535L, Some(65535L)),
    ],
  )
  check_pdf_cmap_parent(
    b"\x2f\x49\x64\x65\x6e\x74\x69\x74\x79\x2d\x56\x20\x75\x73\x65\x63\x6d\x61\x70",
    b"\x2f\x57\x4d\x6f\x64\x65\x20\x30\x20\x64\x65\x66",
    false,
    [
      (0L, Some(0L)),
      (1L, Some(1L)),
      (2L, Some(2L)),
      (3L, Some(3L)),
      (4L, Some(4L)),
      (5L, Some(5L)),
      (6L, Some(6L)),
      (16L, Some(16L)),
      (17L, Some(17L)),
      (18L, Some(18L)),
      (24L, Some(24L)),
      (32L, Some(32L)),
      (33L, Some(33L)),
      (33090L, Some(33090L)),
      (65535L, Some(65535L)),
    ],
  )
  check_pdf_cmap_parent(
    b"\x2f\x49\x64\x65\x6e\x74\x69\x74\x79\x2d\x56\x20\x75\x73\x65\x63\x6d\x61\x70",
    b"\x31\x20\x62\x65\x67\x69\x6e\x63\x69\x64\x72\x61\x6e\x67\x65\x20\x3c\x31\x30\x3e\x20\x3c\x32\x30\x3e\x20\x38\x30\x20\x65\x6e\x64\x63\x69\x64\x72\x61\x6e\x67\x65",
    true,
    [
      (0L, Some(0L)),
      (1L, Some(1L)),
      (2L, Some(2L)),
      (3L, Some(3L)),
      (4L, Some(4L)),
      (5L, Some(5L)),
      (6L, Some(6L)),
      (16L, Some(80L)),
      (17L, Some(81L)),
      (18L, Some(82L)),
      (24L, Some(88L)),
      (32L, Some(96L)),
      (33L, Some(33L)),
      (33090L, Some(33090L)),
      (65535L, Some(65535L)),
    ],
  )
  check_pdf_cmap_parent(
    b"\x2f\x49\x64\x65\x6e\x74\x69\x74\x79\x2d\x56\x20\x75\x73\x65\x63\x6d\x61\x70",
    b"",
    true,
    [
      (0L, Some(0L)),
      (1L, Some(1L)),
      (2L, Some(2L)),
      (3L, Some(3L)),
      (4L, Some(4L)),
      (5L, Some(5L)),
      (6L, Some(6L)),
      (16L, Some(16L)),
      (17L, Some(17L)),
      (18L, Some(18L)),
      (24L, Some(24L)),
      (32L, Some(32L)),
      (33L, Some(33L)),
      (33090L, Some(33090L)),
      (65535L, Some(65535L)),
    ],
  )
  check_pdf_cmap_parent(
    b"\x2f\x39\x30\x6d\x73\x2d\x52\x4b\x53\x4a\x2d\x48\x20\x75\x73\x65\x63\x6d\x61\x70",
    b"\x31\x20\x62\x65\x67\x69\x6e\x63\x69\x64\x63\x68\x61\x72\x20\x3c\x30\x31\x3e\x20\x34\x34\x20\x65\x6e\x64\x63\x69\x64\x63\x68\x61\x72",
    false,
    [
      (0L, None),
      (1L, Some(44L)),
      (2L, None),
      (3L, None),
      (4L, None),
      (5L, None),
      (6L, None),
      (16L, None),
      (17L, None),
      (18L, None),
      (24L, None),
      (32L, Some(231L)),
      (33L, Some(232L)),
      (33090L, Some(635L)),
      (65535L, None),
    ],
  )
  check_pdf_cmap_parent(
    b"\x2f\x39\x30\x6d\x73\x2d\x52\x4b\x53\x4a\x2d\x48\x20\x75\x73\x65\x63\x6d\x61\x70",
    b"\x2f\x57\x4d\x6f\x64\x65\x20\x30\x20\x64\x65\x66",
    false,
    [
      (0L, None),
      (1L, None),
      (2L, None),
      (3L, None),
      (4L, None),
      (5L, None),
      (6L, None),
      (16L, None),
      (17L, None),
      (18L, None),
      (24L, None),
      (32L, Some(231L)),
      (33L, Some(232L)),
      (33090L, Some(635L)),
      (65535L, None),
    ],
  )
  check_pdf_cmap_parent(
    b"\x2f\x39\x30\x6d\x73\x2d\x52\x4b\x53\x4a\x2d\x48\x20\x75\x73\x65\x63\x6d\x61\x70",
    b"\x31\x20\x62\x65\x67\x69\x6e\x63\x69\x64\x72\x61\x6e\x67\x65\x20\x3c\x31\x30\x3e\x20\x3c\x32\x30\x3e\x20\x38\x30\x20\x65\x6e\x64\x63\x69\x64\x72\x61\x6e\x67\x65",
    false,
    [
      (0L, None),
      (1L, None),
      (2L, None),
      (3L, None),
      (4L, None),
      (5L, None),
      (6L, None),
      (16L, Some(80L)),
      (17L, Some(81L)),
      (18L, Some(82L)),
      (24L, Some(88L)),
      (32L, Some(96L)),
      (33L, Some(232L)),
      (33090L, Some(635L)),
      (65535L, None),
    ],
  )
  check_pdf_cmap_parent(
    b"\x2f\x39\x30\x6d\x73\x2d\x52\x4b\x53\x4a\x2d\x48\x20\x75\x73\x65\x63\x6d\x61\x70",
    b"",
    false,
    [
      (0L, None),
      (1L, None),
      (2L, None),
      (3L, None),
      (4L, None),
      (5L, None),
      (6L, None),
      (16L, None),
      (17L, None),
      (18L, None),
      (24L, None),
      (32L, Some(231L)),
      (33L, Some(232L)),
      (33090L, Some(635L)),
      (65535L, None),
    ],
  )
}

///|
fn check_pdf_cmap_parent(
  parent_input : Bytes,
  input : Bytes,
  vertical : Bool,
  entries : Array[(Int64, Int64?)],
) -> Unit raise {
  let parent = pdf_parse_cmap(parent_input, None)
  let map = pdf_parse_cmap(input, Some(parent))
  assert_eq(map.vertical, vertical)
  for (code, cid) in entries {
    assert_eq(map.lookup(code, 0), cid)
  }
}

///|
fn check_pdf_cmap(
  input : Bytes,
  vertical : Bool,
  entries : Array[(Int64, Int64?, String)],
  samples : Array[(Bytes, Array[PdfGlyphCode])],
) -> Unit raise {
  let map = pdf_parse_cmap(input, None)
  assert_eq(map.vertical, vertical)
  for (code, cid, value) in entries {
    assert_eq(map.lookup(code, 0), cid)
    assert_eq(map.to_unicode(code), value)
  }
  for (input, expected) in samples {
    assert_eq(map.decode(input), expected)
  }
}
