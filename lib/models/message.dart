import 'package:flutter_learning/models/user.dart';

class ChatAttachment {
  final String id;
  final String type; // 'image' or 'file'
  final String url;
  final String name;
  final String mimeType;
  final int sizeBytes;
  final int? width;
  final int? height;

  const ChatAttachment({
    required this.id,
    required this.type,
    required this.url,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    this.width,
    this.height,
  });

  bool get isImage => type == 'image';

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class ChatMessage {
  // Whether a message is "mine" is worked out from senderId and the
  // current user, so it is not stored separately.
  final String id;
  final String senderId;
  final String text;
  final String time;
  final List<ChatAttachment> attachments;

  /// Server only: the sender took the message back, how many people used each
  /// reaction emoji, and my own reaction.
  final bool isRecalled;
  final Map<String, int> reactions;
  final String? myReaction;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.time,
    this.attachments = const [],
    this.isRecalled = false,
    this.reactions = const {},
    this.myReaction,
  });

  /// The message with a new state (what the server says can change later).
  ChatMessage withState(MessageState state) => ChatMessage(
    id: id,
    senderId: senderId,
    // A recalled message loses its text and files for everybody.
    text: state.isRecalled ? '' : text,
    time: time,
    attachments: state.isRecalled ? const [] : attachments,
    isRecalled: state.isRecalled,
    reactions: state.reactions,
    myReaction: state.myReaction,
  );
}

/// What can still change on a message: reactions and being recalled.
class MessageState {
  final Map<String, int> reactions;
  final String? myReaction;
  final bool isRecalled;

  const MessageState({
    this.reactions = const {},
    this.myReaction,
    this.isRecalled = false,
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
