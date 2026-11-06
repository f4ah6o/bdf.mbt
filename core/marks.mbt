///|
/// MARK kinds (BDF spec §7.8). They give the reading structure of a page:
/// headings, paragraphs, lines, lists, tables, figures and languages.
/// A MARK does not affect drawing.
pub const MARK_PARAGRAPH : Byte = 0
pub const MARK_LINE : Byte = 1
pub const MARK_CELL : Byte = 2
pub const MARK_BOX : Byte = 3
pub const MARK_ALT_TEXT : Byte = 4
pub const MARK_WRAP : Byte = 5
pub const MARK_HEADING : Byte = 6
pub const MARK_LIST : Byte = 7
pub const MARK_LIST_ITEM : Byte = 8
pub const MARK_TABLE : Byte = 9
pub const MARK_FIGURE : Byte = 10
pub const MARK_END : Byte = 11
pub const MARK_LANG : Byte = 12
pub const MARK_BARCODE : Byte = 13
pub const MARK_DATA : Byte = 14
