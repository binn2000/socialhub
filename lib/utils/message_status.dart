import 'package:flutter_learning/models/message.dart';

/// One of my messages as the other person sees it.
enum SendState { sending, sent, delivered, seen }

/// "sent": the server has it; "delivered": the other person's app fetched it;
/// "seen": they read it. Message ids only grow, so a message counts as
/// delivered or seen when its id is not greater than the other person's marker.
/// A message that still has a local id is being sent.
SendState sendState(String messageId, String? deliveredId, String? readId) {
  if (messageId.startsWith('message_')) return SendState.sending;
  if (readId != null && messageId.compareTo(readId) <= 0) return SendState.seen;
  if (deliveredId != null && messageId.compareTo(deliveredId) <= 0) {
    return SendState.delivered;
  }
  return SendState.sent;
}

/// The newest of my messages the other person has read: their small avatar
/// goes under it.
String? lastSeenOfMine(
  List<ChatMessage> messages,
  String myId,
  String? readId,
) {
  if (readId == null) return null;
  for (final m in messages.reversed) {
    if (m.senderId == myId &&
        !m.isRecalled &&
        !m.id.startsWith('message_') &&
        m.id.compareTo(readId) <= 0) {
      return m.id;
    }
  }
  return null;
}
