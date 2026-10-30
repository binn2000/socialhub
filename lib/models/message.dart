import 'package:flutter_learning/models/user.dart';

class ChatMessage {
  // Whether a message is "mine" is worked out from senderId and the
  // current user, so it is not stored separately.
  final String id;
  final String senderId;
  final String text;
  final String time;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.time,
  });
}

class Conversation {
  final String id;
  final UserModel user;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final List<ChatMessage> messages;

  const Conversation({
    required this.id,
    required this.user,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.messages,
  });
}
