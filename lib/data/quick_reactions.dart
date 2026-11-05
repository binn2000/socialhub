/// The emojis the quick send button can send, same list as the server
/// (`ConversationController::QUICK_REACTIONS`) and the web.
const kQuickReactions = [
  '👍',
  '❤️',
  '😂',
  '😮',
  '😢',
  '😡',
  '🔥',
  '🎉',
  '👏',
  '😍',
  '🙏',
  '💯',
];

const kDefaultQuickReaction = '👍';

/// What the server sent, or 👍 when it is missing or empty.
String quickReactionOf(String? value) {
  if (value == null) return kDefaultQuickReaction;
  final trimmed = value.trim();
  return trimmed.isNotEmpty ? trimmed : kDefaultQuickReaction;
}
