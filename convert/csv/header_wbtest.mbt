///|
test "header detection matches upstream CSV examples" {
  let dialect = Dialect::{ delimiter: b',', quote: b'"', escape: 0, }
  for
    (text, expected) in [
      ("id,name,price\n1,Ann,3.5\n2,Bob,4\n3,Cy,5", true),
      ("1,2,3\n4,5,6\n7,8,9", false),
      ("1,Ann,3.5\n2,Bob,4\n3,Cy,5", false),
      ("when,who\n2024-01-02,a@example.com\n2024-01-03,b@example.com", true),
      ("country,2022,2023,2024\nJapan,1.2,1.3,1.5\nFrance,2.1,2.0,2.2", true),
      ("2022,Japan,1.2\n2023,Japan,1.3\n2024,France,2.2", false),
      ("name,city\nAnn,Tokyo\nBob,Osaka\nCy,Nagoya", true),
      ("Ann,Tokyo\nBob,Osaka\nCy,Tokyo\nDan,Osaka", false),
      ("name,code\nAnn,AB12\nBob,CD34\nCy,EF56", true),
      (",Jan,Feb\nA,1,2\nB,3,4", true),
      ("a,a,b\nc,d,e\nf,g,h", false),
      ("id,name", false),
      ("active,name\ntrue,Ann\nfalse,Bob\ntrue,Cy", true),
      ("氏名,年齢\n山田,30\n佐藤,25", true),
    ] {
    assert_eq(has_header(read_records(text, dialect).rows), expected)
  }
}
