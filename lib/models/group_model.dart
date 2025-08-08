import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:first_app/models/user_model.dart';

class GroupModel {
  final String id;
  final String name;
  final String? groupPicUrl;
  final String lastMessage;
  final Timestamp lastMessageTimestamp;
  final List<UserModel>? members; // Made optional

  GroupModel({
    required this.id,
    required this.name,
    this.groupPicUrl,
    required this.lastMessage,
    required this.lastMessageTimestamp,
    this.members, // Added back as optional
  });

  // Creates a GroupModel from a Firestore document
  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return GroupModel(
      id: data['groupId'] ?? '',
      name: data['groupName'] ?? 'No Name',
      groupPicUrl: data['groupPicUrl'],
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTimestamp: data['lastMessageTimestamp'] ?? Timestamp.now(),
      // Members are not fetched here to keep the group list fast
    );
  }

  // Creates a GroupModel from a JSON map (used for local cache)
  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'],
      name: json['name'],
      groupPicUrl: json['groupPicUrl'],
      lastMessage: json['lastMessage'],
      lastMessageTimestamp: Timestamp(json['lastMessageTimestamp']['_seconds'], json['lastMessageTimestamp']['_nanoseconds']),
    );
  }

  // Converts a GroupModel to a JSON map (used for local cache)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'groupPicUrl': groupPicUrl,
      'lastMessage': lastMessage,
      'lastMessageTimestamp': {
        '_seconds': lastMessageTimestamp.seconds,
        '_nanoseconds': lastMessageTimestamp.nanoseconds,
      },
    };
  }
}
