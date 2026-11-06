///|
/// The questions a DNS-SD responder probes before it advertises a
/// printer: its full name and its host, any type.
pub fn probe_questions(service : Advertisement) -> Array[Question] {
  [
    { name: service_full_name(service), typ: TYPE_ANY, class_: CLASS_IN },
    { name: service.host, typ: TYPE_ANY, class_: CLASS_IN },
  ]
}

///|
pub fn probe_message(id : Int, service : Advertisement) -> Bytes raise DnsError {
  encode_query(id, probe_questions(service))
}

///|
/// An announcement of the printer's records.
pub fn announce_message(id : Int, service : Advertisement) -> Bytes raise DnsError {
  encode_response(id, [], advertisement_records(service))
}
