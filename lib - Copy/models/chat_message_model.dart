// lib/models/chat_message_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, video, deleted }

MessageType messageTypeFromString(String? type) {
  switch (type) {
    case 'image':
      return MessageType.image;
    case 'video':
      return MessageType.video;
    case 'deleted':
      return MessageType.deleted;
    default:
      return MessageType.text;
  }
}

class ChatMessageModel {
  final String id;
  final String senderId;
  final String? text;
  final Timestamp timestamp;
  final MessageType type;
  final String? mediaUrl;
  final Map<String, String> reactions;
  final String? status;
  final Timestamp? seenAt;
  // **NEW**: Tracks which users have deleted this message for themselves.
  final List<String> deletedFor;

  ChatMessageModel({
    required this.id,
    required this.senderId,
    this.text,
    required this.timestamp,
    required this.type,
    this.mediaUrl,
    this.reactions = const {},
    this.status,
    this.seenAt,
    this.deletedFor = const [], // **NEW**
  });

  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChatMessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
      type: messageTypeFromString(data['type']),
      mediaUrl: data['mediaUrl'],
      reactions: Map<String, String>.from(data['reactions'] ?? {}),
      status: data['status'],
      seenAt: data['seenAt'],
      // **NEW**: Read the list of UIDs from Firestore.
      deletedFor: List<String>.from(data['deletedFor'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
      'type': type.toString().split('.').last,
      'mediaUrl': mediaUrl,
      'reactions': reactions,
      'status': status,
      'seenAt': seenAt,
      // **NEW**: Save the list of UIDs to Firestore.
      'deletedFor': deletedFor,
    };
  }
}
