import '../entities/tool_definition.dart';

const Set<String> textToolIds = {
  'base_convert',
  'timestamp',
  'color_convert',
  'base64',
  'url_codec',
  'json_format',
  'ascii_unicode',
  'bitwise',
  'checksum',
  'uuid',
  'jwt_decode',
  'query_params',
  'html_entities',
  'regex_test',
  'text_stats',
  'csv_json',
  'fnv_crc',
  'custom_formula',
};

extension ToolCapabilities on ToolDefinition {
  bool get usesTextDetail => textToolIds.contains(id);
}
