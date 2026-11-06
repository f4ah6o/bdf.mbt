///|
// IPP tags (RFC 8010 §3.5).
pub type Tag = Byte

pub const TAG_OPERATION : Tag = 0x01
pub const TAG_JOB : Tag = 0x02
pub const TAG_END : Tag = 0x03
pub const TAG_PRINTER : Tag = 0x04
pub const TAG_UNSUPPORTED_GROUP : Tag = 0x05
pub const TAG_SUBSCRIPTION : Tag = 0x06
pub const TAG_EVENT_NOTIFICATION : Tag = 0x07
pub const TAG_RESOURCE : Tag = 0x08
pub const TAG_DOCUMENT : Tag = 0x09
pub const TAG_SYSTEM : Tag = 0x0a

pub const TAG_UNSUPPORTED : Tag = 0x10
pub const TAG_DEFAULT : Tag = 0x11
pub const TAG_UNKNOWN : Tag = 0x12
pub const TAG_NO_VALUE : Tag = 0x13
pub const TAG_NOT_SETTABLE : Tag = 0x15
pub const TAG_DELETE_ATTRIBUTE : Tag = 0x16
pub const TAG_ADMIN_DEFINE : Tag = 0x17

pub const TAG_INTEGER : Tag = 0x21
pub const TAG_BOOLEAN : Tag = 0x22
pub const TAG_ENUM : Tag = 0x23
pub const TAG_OCTET_STRING : Tag = 0x30
pub const TAG_DATE_TIME : Tag = 0x31
pub const TAG_RESOLUTION : Tag = 0x32
pub const TAG_RANGE : Tag = 0x33
pub const TAG_BEGIN_COLLECTION : Tag = 0x34
pub const TAG_TEXT_LANG : Tag = 0x35
pub const TAG_NAME_LANG : Tag = 0x36
pub const TAG_END_COLLECTION : Tag = 0x37
pub const TAG_TEXT : Tag = 0x41
pub const TAG_NAME : Tag = 0x42
pub const TAG_RESERVED_STRING : Tag = 0x43
pub const TAG_KEYWORD : Tag = 0x44
pub const TAG_URI : Tag = 0x45
pub const TAG_URI_SCHEME : Tag = 0x46
pub const TAG_CHARSET : Tag = 0x47
pub const TAG_LANGUAGE : Tag = 0x48
pub const TAG_MIME_TYPE : Tag = 0x49
pub const TAG_MEMBER_NAME : Tag = 0x4a
pub const TAG_EXTENSION : Tag = 0x7f

///|
pub fn tag_name(tag : Tag) -> String {
  if tag == TAG_OPERATION {
    "operation-attributes"
  } else if tag == TAG_JOB {
    "job-attributes"
  } else if tag == TAG_END {
    "end-of-attributes"
  } else if tag == TAG_PRINTER {
    "printer-attributes"
  } else if tag == TAG_UNSUPPORTED_GROUP {
    "unsupported-attributes"
  } else if tag == TAG_SUBSCRIPTION {
    "subscription-attributes"
  } else if tag == TAG_EVENT_NOTIFICATION {
    "event-notification-attributes"
  } else if tag == TAG_RESOURCE {
    "resource-attributes"
  } else if tag == TAG_DOCUMENT {
    "document-attributes"
  } else if tag == TAG_SYSTEM {
    "system-attributes"
  } else if tag == TAG_UNSUPPORTED {
    "unsupported"
  } else if tag == TAG_DEFAULT {
    "default"
  } else if tag == TAG_UNKNOWN {
    "unknown"
  } else if tag == TAG_NO_VALUE {
    "no-value"
  } else if tag == TAG_NOT_SETTABLE {
    "not-settable"
  } else if tag == TAG_DELETE_ATTRIBUTE {
    "delete-attribute"
  } else if tag == TAG_ADMIN_DEFINE {
    "admin-define"
  } else if tag == TAG_INTEGER {
    "integer"
  } else if tag == TAG_BOOLEAN {
    "boolean"
  } else if tag == TAG_ENUM {
    "enum"
  } else if tag == TAG_OCTET_STRING {
    "octetString"
  } else if tag == TAG_DATE_TIME {
    "dateTime"
  } else if tag == TAG_RESOLUTION {
    "resolution"
  } else if tag == TAG_RANGE {
    "rangeOfInteger"
  } else if tag == TAG_BEGIN_COLLECTION {
    "collection"
  } else if tag == TAG_TEXT_LANG {
    "textWithLanguage"
  } else if tag == TAG_NAME_LANG {
    "nameWithLanguage"
  } else if tag == TAG_END_COLLECTION {
    "endCollection"
  } else if tag == TAG_TEXT {
    "text"
  } else if tag == TAG_NAME {
    "name"
  } else if tag == TAG_RESERVED_STRING {
    "reservedString"
  } else if tag == TAG_KEYWORD {
    "keyword"
  } else if tag == TAG_URI {
    "uri"
  } else if tag == TAG_URI_SCHEME {
    "uriScheme"
  } else if tag == TAG_CHARSET {
    "charset"
  } else if tag == TAG_LANGUAGE {
    "naturalLanguage"
  } else if tag == TAG_MIME_TYPE {
    "mimeMediaType"
  } else if tag == TAG_MEMBER_NAME {
    "memberAttrName"
  } else if tag == TAG_EXTENSION {
    "extension"
  } else {
    "tag-0x" + tag.to_int().to_string()
  }
}

///|
pub fn tag_is_group(tag : Tag) -> Bool {
  tag.to_int() < 0x10
}

///|
pub fn tag_is_out_of_band(tag : Tag) -> Bool {
  tag.to_int() >= 0x10 && tag.to_int() < 0x20
}

///|
pub fn tag_is_string(tag : Tag) -> Bool {
  tag.to_int() >= 0x40 && tag.to_int() < 0x60 && tag != TAG_MEMBER_NAME
}

///|
pub const OP_PRINT_JOB : Int = 0x0002
pub const OP_PRINT_URI : Int = 0x0003
pub const OP_VALIDATE_JOB : Int = 0x0004
pub const OP_CREATE_JOB : Int = 0x0005
pub const OP_SEND_DOCUMENT : Int = 0x0006
pub const OP_SEND_URI : Int = 0x0007
pub const OP_CANCEL_JOB : Int = 0x0008
pub const OP_GET_JOB_ATTRIBUTES : Int = 0x0009
pub const OP_GET_JOBS : Int = 0x000a
pub const OP_GET_PRINTER_ATTRIBUTES : Int = 0x000b
pub const OP_GET_PRINTER_SUPPORTED_VALUES : Int = 0x0015

pub const STATUS_OK : Int = 0x0000
pub const STATUS_OK_IGNORED_OR_SUBSTITUTED : Int = 0x0001
pub const STATUS_CLIENT_ERROR_BAD_REQUEST : Int = 0x0400
pub const STATUS_CLIENT_ERROR_FORBIDDEN : Int = 0x0401
pub const STATUS_CLIENT_ERROR_NOT_FOUND : Int = 0x0406
pub const STATUS_SERVER_ERROR_INTERNAL : Int = 0x0500
