part of 'text_tool_controller.dart';

String _normalizeAsciiLike(String source) {
  final buffer = StringBuffer();
  for (final rune in source.runes) {
    if (rune == 0x3000 || rune == 0x00a0 || rune == 0x2007 || rune == 0x202f) {
      buffer.write(' ');
    } else if (rune >= 0xff01 && rune <= 0xff5e) {
      buffer.writeCharCode(rune - 0xfee0);
    } else if (rune == 0x2212 || rune == 0x2013 || rune == 0x2014) {
      buffer.write('-');
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}
