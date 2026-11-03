// Internal helpers — not part of the public API.
// Used by whitebox tests and CLI tools.

///|
fn bytes_to_hex(data : Array[Int]) -> String {
  @core.bytes_to_hex(data)
}

///|
fn hex_to_bytes(hex : String) -> Result[Array[Int], String] {
  @core.hex_to_bytes(hex)
}

///|
fn classify_marker(code : Int) -> @core.MarkerClass {
  @core.classify_marker(code)
}

///|
fn decode_tag_tree_inclusion_flags(
  data : Array[Int],
  width : Int,
  height : Int,
  threshold : Int,
) -> Result[(Array[Bool], Int), String] {
  @core.decode_tag_tree_inclusion_flags(
    @bytes.int_array_to_bytes(data), width, height, threshold,
  )
}

///|
fn decode_codeblock_segment_lengths_from_bits(
  data : Array[Int],
  initial_lblock : Int,
  added_passes : Array[Int],
) -> Result[(Array[Int], Int), String] {
  @core.decode_codeblock_segment_lengths_from_bits(
    @bytes.int_array_to_bytes(data), initial_lblock, added_passes,
  )
}

///|
fn parse_packet_headers_single_codeblock(
  data : Array[Int],
) -> Result[Array[@core.PacketHeaderMetadata], String] {
  @core.parse_packet_headers_single_codeblock(@bytes.int_array_to_bytes(data))
}

///|
fn parse_packet_headers_with_code_blocks(
  data : Array[Int],
  code_block_count : Int,
) -> Result[Array[@core.PacketHeaderMetadata], String] {
  @core.parse_packet_headers_with_code_blocks(
    @bytes.int_array_to_bytes(data), code_block_count,
  )
}

///|
fn parse_packet_headers_with_code_blocks_and_style(
  data : Array[Int],
  code_block_count : Int,
  code_block_style : Int,
) -> Result[Array[@core.PacketHeaderMetadata], String] {
  @core.parse_packet_headers_with_code_blocks_and_style(
    @bytes.int_array_to_bytes(data), code_block_count, code_block_style,
  )
}

///|
fn parse_packet_header_first_packet_with_code_blocks_and_style(
  data : Array[Int],
  code_block_count : Int,
  code_block_style : Int,
) -> Result[@core.PacketHeaderMetadata, String] {
  @core.parse_packet_header_first_packet_with_code_blocks_and_style(
    @bytes.int_array_to_bytes(data), code_block_count, code_block_style,
  )
}

///|
fn parse_packet_header_single_packet_with_tag_tree(
  data : Array[Int],
  width : Int,
  height : Int,
  layer_index : Int,
) -> Result[@core.PacketHeaderMetadata, String] {
  @core.parse_packet_header_single_packet_with_tag_tree(
    @bytes.int_array_to_bytes(data), width, height, layer_index,
  )
}

///|
fn parse_packet_header_single_packet_with_tag_tree_and_pass_splits(
  data : Array[Int],
  width : Int,
  height : Int,
  layer_index : Int,
  added_passes_per_code_block : Array[Array[Int]],
) -> Result[@core.PacketHeaderMetadata, String] {
  @core.parse_packet_header_single_packet_with_tag_tree_and_pass_splits(
    @bytes.int_array_to_bytes(data), width, height, layer_index,
    added_passes_per_code_block,
  )
}

///|
fn parse_packet_headers_with_tag_tree_sequence(
  data : Array[Int],
  width : Int,
  height : Int,
  packet_count : Int,
) -> Result[Array[@core.PacketHeaderMetadata], String] {
  @core.parse_packet_headers_with_tag_tree_sequence(
    @bytes.int_array_to_bytes(data), width, height, packet_count,
  )
}

///|
fn parse_packet_headers_with_tag_tree_sequence_and_pass_splits(
  data : Array[Int],
  width : Int,
  height : Int,
  packet_count : Int,
  added_passes_per_packet_per_code_block : Array[Array[Array[Int]]],
) -> Result[Array[@core.PacketHeaderMetadata], String] {
  @core.parse_packet_headers_with_tag_tree_sequence_and_pass_splits(
    @bytes.int_array_to_bytes(data), width, height, packet_count,
    added_passes_per_packet_per_code_block,
  )
}
