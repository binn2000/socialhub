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

/// What the server sent, or 👍 when it is missing or unknown.
String quickReactionOf(String? value) =>
    value != null && kQuickReactions.contains(value)
    ? value
    : kDefaultQuickReaction;
