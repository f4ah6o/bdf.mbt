///|
test "cups printer and job uris" {
  assert_eq(
    cups_printer_uri("printer.local", "office"),
    "ipp://printer.local:631/printers/office",
  )
  assert_eq(
    cups_printer_uri("ipp://printer.local:8631/", "office"),
    "ipp://printer.local:8631/printers/office",
  )
  assert_eq(
    cups_job_uri("printer.local", "office", 7),
    "ipp://printer.local:631/printers/office/jobs/7",
  )
  let client = cups_client("printer.local", "office", "alice")
  assert_eq(client.printer_uri, "ipp://printer.local:631/printers/office")
  assert_eq(client.user_name, "alice")
}

