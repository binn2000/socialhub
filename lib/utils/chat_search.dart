import 'package:flutter_learning/data/chat_interactions.dart';
import 'package:flutter_learning/data/chat_stickers.dart';
import 'package:flutter_learning/models/message.dart';

const _withAccents =
    'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
    'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
const _without =
    'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
    'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';

/// Lower case without Vietnamese accents, so "ha noi" finds "Hà Nội".
String normalizeForSearch(String text) {
  final out = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final index = _withAccents.indexOf(char);
    out.write(index == -1 ? char : _without[index]);
  }
  return out.toString().toLowerCase();
}

/// Whether [message] says [query]: what was written is searched, not the
/// quote at the top of a reply; stickers and recalled messages never match.
bool messageMatches(ChatMessage message, String query) {
  final q = normalizeForSearch(query.trim());
  if (q.isEmpty || message.isRecalled) return false;
  final written = parseChatMessageReply(message.text).cleanText;
  if (written.isEmpty || isStickerMessage(written)) return false;
  return normalizeForSearch(written).contains(q);
}
