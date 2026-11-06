///|
/// What a job says of itself in Get-Job-Attributes.
pub(all) struct JobStatus {
  id : Int
  uri : String
  name : String
  state : Int
  reasons : Array[String]
  message : String
  impressions : Int
  attrs : Array[Attribute]
  unsupported : Array[Attribute]
}

///|
pub fn job_status(attrs : Array[Attribute]) -> JobStatus {
  let mut id = 0
  let mut uri = ""
  let mut name = ""
  let mut state = 0
  let mut reasons : Array[String] = []
  let mut message = ""
  let mut impressions = -1
  for attribute in attrs {
    if attribute.name == "job-id" {
      id = attribute.int().unwrap_or(0)
    } else if attribute.name == "job-uri" {
      uri = attribute.text()
    } else if attribute.name == "job-name" {
      name = attribute.text()
    } else if attribute.name == "job-state" {
      state = attribute.int().unwrap_or(0)
    } else if attribute.name == "job-state-reasons" {
      reasons = attribute.strings()
    } else if attribute.name == "job-state-message" {
      message = attribute.text()
    } else if attribute.name == "job-impressions-completed" {
      impressions = attribute.int().unwrap_or(-1)
    }
  }
  {
    id,
    uri,
    name,
    state,
    reasons,
    message,
    impressions,
    attrs,
    unsupported: [],
  }
}

///|
pub fn JobStatus::to_string(self : JobStatus) -> String {
  let mut text = "job " + self.id.to_string() + " " + job_state_name(self.state)
  if self.reasons.length() > 0 {
    text += " (" + self.reasons.join(", ") + ")"
  }
  if self.impressions >= 0 {
    text += " " + self.impressions.to_string() + " impressions"
  }
  text
}
