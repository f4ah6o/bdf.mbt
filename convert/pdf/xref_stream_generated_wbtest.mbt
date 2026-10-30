///|
test "PDF xref streams match upstream Go 0" {
  check_pdf_xrefs(
    "xref-stream-0",
    [
      "H4sIAAAAAAAA/2SPwUrzQBSF7/+7m51vcDYBXehNxlgRShdWu1FsSUWF0sXU3saUJlMyU1Ef1xepDAlYyGwOA+fjOzea3I7OkvMrFTlfiylVghh2sVb9PvjpayvgofFmY3PwxOTioBEjw2CgpFqGou4ATY+Hdld5xOD7Yukwmx8wFx1mvFhPfQl+RAIeFbXzSAF+kCr379DXAW4XpogRZM9msxOcvNlyW4tzsjxtDW2vdV12XK+ZrMDT4lvQA2fWeoSrM/ALZglS6PmfOtUHagpvv/9HRMdEIW6a+CD6T0RHze+HqLvDeVP7z1pWSuueiqK78Uj9DgBnfGR2fgEAAA==",
    ],
    Some(PdfRef(1L, 0L)),
    [
      (0L, XRefFree(65535L)),
      (1L, XRefOffset(17L, 0L)),
      (2L, XRefOffset(66L, 0L)),
      (3L, XRefOffset(118L, 0L)),
      (4L, XRefCompressed(3L, 0L)),
      (5L, XRefOffset(226L, 0L)),
    ],
  )
}

///|
test "PDF compressed object matches upstream Go 0" {
  check_pdf_resolve(
    "xref-stream-0",
    [
      "H4sIAAAAAAAA/2SPwUrzQBSF7/+7m51vcDYBXehNxlgRShdWu1FsSUWF0sXU3saUJlMyU1Ef1xepDAlYyGwOA+fjOzea3I7OkvMrFTlfiylVghh2sVb9PvjpayvgofFmY3PwxOTioBEjw2CgpFqGou4ATY+Hdld5xOD7Yukwmx8wFx1mvFhPfQl+RAIeFbXzSAF+kCr379DXAW4XpogRZM9msxOcvNlyW4tzsjxtDW2vdV12XK+ZrMDT4lvQA2fWeoSrM/ALZglS6PmfOtUHagpvv/9HRMdEIW6a+CD6T0RHze+HqLvDeVP7z1pWSuueiqK78Uj9DgBnfGR2fgEAAA==",
    ],
    [
      (
        4L,
        PdfDict([
          (
            b"\x56\x61\x6c\x75\x65",
            PdfString(b"\x63\x6f\x6d\x70\x72\x65\x73\x73\x65\x64"),
          ),
        ]),
        -1,
        0UL,
      ),
    ],
  )
}

///|
test "PDF xref streams match upstream Go 1" {
  check_pdf_xrefs(
    "xref-stream-1",
    [
      "H4sIAAAAAAAA/2yQQU7CQBSGH7Ixs/MAJv+miS502lo0JqQLwW40QopRE8JioA+EFIbMDIqexRt4K7ceAjPCwqTO5p+X/N/Llxd029lJdHohAusMq7mIEEIPZ6LZhLx/WzJkSzlV6glkV03YIkaIHGkqeFH4YlwBtj3Z0quFQwh5My0s+oM/zFmF6QxnPTeHvEMEmU2NdUj8p3RsILNSOW7zSBcMecuLiXtGEvuFO+v1Bx3S1yZBCO/xoMoV42ik50vD1nJxjDSt0+v3/qfX3kE7mUZF5innMWRv+s44h8y1dvBnySEf0Y+QIB7gfw/yb7OpEdEBkY+rbbwQ7RFR/Xeq1YmqHtYp49aGxyJuXIoguO5k4mcAAMDF7Z8BAAA=",
    ],
    Some(PdfRef(1L, 0L)),
    [
      (0L, XRefFree(65535L)),
      (1L, XRefOffset(17L, 0L)),
      (2L, XRefOffset(66L, 0L)),
      (3L, XRefOffset(118L, 0L)),
      (4L, XRefCompressed(3L, 0L)),
      (5L, XRefOffset(259L, 0L)),
    ],
  )
}

///|
test "PDF compressed object matches upstream Go 1" {
  check_pdf_resolve(
    "xref-stream-1",
    [
      "H4sIAAAAAAAA/2yQQU7CQBSGH7Ixs/MAJv+miS502lo0JqQLwW40QopRE8JioA+EFIbMDIqexRt4K7ceAjPCwqTO5p+X/N/Llxd029lJdHohAusMq7mIEEIPZ6LZhLx/WzJkSzlV6glkV03YIkaIHGkqeFH4YlwBtj3Z0quFQwh5My0s+oM/zFmF6QxnPTeHvEMEmU2NdUj8p3RsILNSOW7zSBcMecuLiXtGEvuFO+v1Bx3S1yZBCO/xoMoV42ik50vD1nJxjDSt0+v3/qfX3kE7mUZF5innMWRv+s44h8y1dvBnySEf0Y+QIB7gfw/yb7OpEdEBkY+rbbwQ7RFR/Xeq1YmqHtYp49aGxyJuXIoguO5k4mcAAMDF7Z8BAAA=",
    ],
    [
      (
        4L,
        PdfDict([
          (
            b"\x56\x61\x6c\x75\x65",
            PdfString(b"\x63\x6f\x6d\x70\x72\x65\x73\x73\x65\x64"),
          ),
        ]),
        -1,
        0UL,
      ),
    ],
  )
}

///|
test "PDF xref streams match upstream Go 2" {
  check_pdf_xrefs(
    "xref-stream-2",
    [
      "H4sIAAAAAAAA/2SP0Uo6QRjFv//fu7nrDc7NQgX17W5qBOJF2t4UKWtUYF6M7qcpqyM7Y1jP0lv0LL1AL2IMLiHs3JwZOIffb4J+NzmLzi9VYF0heqkihDDjhWq1wA/vawF3tNO5mYH7eiYWMUKkaLeVrDJfjCuDfY87ZrNyCMG388xiODrYXFQ2vfFi4Jbge0TgZF5YhzrAd7KauVfEV35cGtYRwsMedb4RHE/Mcl2ItZKdlISyV7IaFdZzKlPwYP4haIJTYxz8r1PwE4YR6ohH3iF3UoCTXDvpysRk8qfTaBzobD/plL535M9u94+Ijoh8XO/jjeg/EdX2rx9/e4lqX1VR63ThtoVMVRw3VRDc9BL1OwDRJCHcnwEAAA==",
    ],
    Some(PdfRef(1L, 0L)),
    [
      (0L, XRefFree(65535L)),
      (1L, XRefOffset(17L, 0L)),
      (2L, XRefOffset(66L, 0L)),
      (3L, XRefOffset(118L, 0L)),
      (4L, XRefCompressed(3L, 0L)),
      (5L, XRefOffset(226L, 0L)),
    ],
  )
}

///|
test "PDF compressed object matches upstream Go 2" {
  check_pdf_resolve(
    "xref-stream-2",
    [
      "H4sIAAAAAAAA/2SP0Uo6QRjFv//fu7nrDc7NQgX17W5qBOJF2t4UKWtUYF6M7qcpqyM7Y1jP0lv0LL1AL2IMLiHs3JwZOIffb4J+NzmLzi9VYF0heqkihDDjhWq1wA/vawF3tNO5mYH7eiYWMUKkaLeVrDJfjCuDfY87ZrNyCMG388xiODrYXFQ2vfFi4Jbge0TgZF5YhzrAd7KauVfEV35cGtYRwsMedb4RHE/Mcl2ItZKdlISyV7IaFdZzKlPwYP4haIJTYxz8r1PwE4YR6ohH3iF3UoCTXDvpysRk8qfTaBzobD/plL535M9u94+Ijoh8XO/jjeg/EdX2rx9/e4lqX1VR63ThtoVMVRw3VRDc9BL1OwDRJCHcnwEAAA==",
    ],
    [
      (
        4L,
        PdfDict([
          (
            b"\x56\x61\x6c\x75\x65",
            PdfString(b"\x63\x6f\x6d\x70\x72\x65\x73\x73\x65\x64"),
          ),
        ]),
        -1,
        0UL,
      ),
    ],
  )
}

///|
test "PDF xref streams match upstream Go 3" {
  check_pdf_xrefs(
    "xref-stream-3",
    [
      "H4sIAAAAAAAA/3zQz0rrQBQG8NN2c8nuPsCFbxO494JOEhNFKFnYmo1iSyr+oXQxbU5rS9opmalWn8SFb+Dz9AXc+hCRsV0oAWdzzsD3DT/G7baTPX//yHG1KVjOHR8e1HDmNJsQl49LhmhJI3M1gejKCWsE8JAijh1eZDYYVArbnGip1cLAgzibZhr9wZfOQaXTGc56Zg5xAR8imRbaILRLbriASHJpuM0jlTHEOS8m5g5hYB/cqdcv9IfeyhAerONK5ivG35GaLwvWmrN/iOMGPbz/erXsXWmHiSqYm5THEL3pE+MQIlXKwH5LCnGNvo8QweBnWxR9t/2nTUn2lGWNiH4T2XGyHfdEdSJqfN5qDbvdPtc3Vag2sjDrgsdOEB07rnvaSZyPAQBgNw2pwAEAAA==",
    ],
    Some(PdfRef(1L, 0L)),
    [
      (0L, XRefFree(65535L)),
      (1L, XRefOffset(17L, 0L)),
      (2L, XRefOffset(66L, 0L)),
      (3L, XRefOffset(118L, 0L)),
      (4L, XRefCompressed(3L, 0L)),
      (5L, XRefOffset(259L, 0L)),
    ],
  )
}

///|
test "PDF compressed object matches upstream Go 3" {
  check_pdf_resolve(
    "xref-stream-3",
    [
      "H4sIAAAAAAAA/3zQz0rrQBQG8NN2c8nuPsCFbxO494JOEhNFKFnYmo1iSyr+oXQxbU5rS9opmalWn8SFb+Dz9AXc+hCRsV0oAWdzzsD3DT/G7baTPX//yHG1KVjOHR8e1HDmNJsQl49LhmhJI3M1gejKCWsE8JAijh1eZDYYVArbnGip1cLAgzibZhr9wZfOQaXTGc56Zg5xAR8imRbaILRLbriASHJpuM0jlTHEOS8m5g5hYB/cqdcv9IfeyhAerONK5ivG35GaLwvWmrN/iOMGPbz/erXsXWmHiSqYm5THEL3pE+MQIlXKwH5LCnGNvo8QweBnWxR9t/2nTUn2lGWNiH4T2XGyHfdEdSJqfN5qDbvdPtc3Vag2sjDrgsdOEB07rnvaSZyPAQBgNw2pwAEAAA==",
    ],
    [
      (
        4L,
        PdfDict([
          (
            b"\x56\x61\x6c\x75\x65",
            PdfString(b"\x63\x6f\x6d\x70\x72\x65\x73\x73\x65\x64"),
          ),
        ]),
        -1,
        0UL,
      ),
    ],
  )
}
