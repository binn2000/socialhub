/// Reaction emojis available for chat messages.
const List<String> kChatMessageReactions = ['❤️', '👍', '😂', '😮', '😢', '😡'];

/// A quoted message envelope parsed from a reply message.
class QuotedMessage {
  final String id;
  final String senderName;
  final String text;

  const QuotedMessage({
    required this.id,
    required this.senderName,
    required this.text,
  });
}

class ParsedChatMessage {
  final QuotedMessage? replyTo;
  final String cleanText;

  const ParsedChatMessage({this.replyTo, required this.cleanText});
}

/// Parses [rawText] checking for the reply envelope `[reply:id:sender:preview]\n...`.
ParsedChatMessage parseChatMessageReply(String rawText) {
  if (rawText.isEmpty) {
    return const ParsedChatMessage(cleanText: '');
  }

  final regex = RegExp(r'^\[reply:([^:]+):([^:]+):([^\]]*)\]\n?([\s\S]*)$');
  final match = regex.firstMatch(rawText);
  if (match != null) {
    return ParsedChatMessage(
      replyTo: QuotedMessage(
        id: match.group(1) ?? '',
        senderName: match.group(2) ?? '',
        text: match.group(3) ?? '',
      ),
      cleanText: match.group(4) ?? '',
    );
  }

  return ParsedChatMessage(cleanText: rawText);
}

/// Formats a message with a quoted reply envelope.
String buildChatMessageReplyPayload(QuotedMessage reply, String text) {
  final cleanSender = reply.senderName
      .replaceAll(RegExp(r'[:\]\n]'), '')
      .trim();
  final cleanSnippet = (reply.text.isNotEmpty ? reply.text : '[Tệp tin/Ảnh]')
      .replaceAll(RegExp(r'[:\]\n]'), ' ')
      .trim();
  final truncatedSnippet = cleanSnippet.length > 80
      ? cleanSnippet.substring(0, 80)
      : cleanSnippet;

  return '[reply:${reply.id}:$cleanSender:$truncatedSnippet]\n${text.trim()}';
}
