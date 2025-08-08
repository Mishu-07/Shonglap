import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String phone;
  final String? profilePicUrl;
  final String? about;
  final String? gender;
  final DateTime? dob;

  UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    this.profilePicUrl,
    this.about,
    this.gender,
    this.dob,
  });

  // Creates a UserModel from a Firebase document (includes all fields)
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] ?? '',
      name: data['name'] ?? 'No Name',
      phone: data['phone'] ?? '',
      profilePicUrl: data['profilePicUrl'],
      about: data['about'], // Added back
      gender: data['gender'], // Added back
      dob: data['dob'] != null ? (data['dob'] as Timestamp).toDate() : null, // Added back
    );
  }

  // Creates a UserModel from a JSON map (for local cache, only essential fields)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'],
      name: json['name'],
      phone: json['phone'],
      profilePicUrl: json['profilePicUrl'],
      // about, gender, dob are intentionally omitted for the cache
    );
  }

  // Converts a UserModel to a JSON map (for local cache, only essential fields)
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'profilePicUrl': profilePicUrl,
    };
  }
}
