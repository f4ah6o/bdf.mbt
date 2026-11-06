///|
// Job and printer states (RFC 8011 §5.3.7 and §5.4.11).
pub const JOB_PENDING : Int = 3
pub const JOB_PENDING_HELD : Int = 4
pub const JOB_PROCESSING : Int = 5
pub const JOB_PROCESSING_STOPPED : Int = 6
pub const JOB_CANCELED : Int = 7
pub const JOB_ABORTED : Int = 8
pub const JOB_COMPLETED : Int = 9

///|
pub fn job_state_name(state : Int) -> String {
  if state == JOB_PENDING {
    "pending"
  } else if state == JOB_PENDING_HELD {
    "pending-held"
  } else if state == JOB_PROCESSING {
    "processing"
  } else if state == JOB_PROCESSING_STOPPED {
    "processing-stopped"
  } else if state == JOB_CANCELED {
    "canceled"
  } else if state == JOB_ABORTED {
    "aborted"
  } else if state == JOB_COMPLETED {
    "completed"
  } else {
    "job-state-" + state.to_string()
  }
}

///|
pub fn job_state_done(state : Int) -> Bool {
  state >= JOB_CANCELED
}

pub const PRINTER_IDLE : Int = 3
pub const PRINTER_PROCESSING : Int = 4
pub const PRINTER_STOPPED : Int = 5

///|
pub fn printer_state_name(state : Int) -> String {
  if state == PRINTER_IDLE {
    "idle"
  } else if state == PRINTER_PROCESSING {
    "processing"
  } else if state == PRINTER_STOPPED {
    "stopped"
  } else {
    "printer-state-" + state.to_string()
  }
}
