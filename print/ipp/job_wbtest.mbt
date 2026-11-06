///|
test "job status" {
  let attrs = [
    attr("job-id", [integer(42)]),
    attr("job-uri", [uri("ipp://printer/jobs/42")]),
    attr("job-name", [name("report")]),
    attr("job-state", [enum_value(JOB_PROCESSING)]),
    attr("job-state-reasons", [keyword("job-printing"), keyword("none")]),
    attr("job-state-message", [text("printing page 2")]),
    attr("job-impressions-completed", [integer(2)]),
  ]
  let job = job_status(attrs)
  assert_eq(job.id, 42)
  assert_eq(job.uri, "ipp://printer/jobs/42")
  assert_eq(job.name, "report")
  assert_eq(job.state, JOB_PROCESSING)
  assert_eq(job.reasons, ["job-printing", "none"])
  assert_eq(job.message, "printing page 2")
  assert_eq(job.impressions, 2)
  assert_eq(
    job.to_string(),
    "job 42 processing (job-printing, none) 2 impressions",
  )
  assert_true(!job_state_done(job.state))
  assert_true(job_state_done(JOB_COMPLETED))
  assert_eq(job_state_name(JOB_PENDING_HELD), "pending-held")
  assert_eq(printer_state_name(PRINTER_IDLE), "idle")
  let empty = job_status([])
  assert_eq(empty.impressions, -1)
  assert_eq(empty.to_string(), "job 0 job-state-0")
}
