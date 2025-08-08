import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:first_app/models/user_model.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContactService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _cacheKey = 'app_contacts_cache';

  // Fetches contacts from the network and updates the cache
  Future<List<UserModel>> fetchAndCacheContacts() async {
    List<UserModel> appContacts = [];
    if (await Permission.contacts.request().isGranted) {
      List<Contact> phoneContacts = await FlutterContacts.getContacts(withProperties: true);
      List<String> phoneNumbers = [];

      for (var contact in phoneContacts) {
        for (var phone in contact.phones) {
          String normalizedNumber = phone.number.replaceAll(RegExp(r'[\s-()]'), '');
          if (normalizedNumber.isNotEmpty) {
            phoneNumbers.add(normalizedNumber);
          }
        }
      }

      if (phoneNumbers.isNotEmpty) {
        for (int i = 0; i < phoneNumbers.length; i += 30) {
          List<String> batch = phoneNumbers.sublist(i, i + 30 > phoneNumbers.length ? phoneNumbers.length : i + 30);
          QuerySnapshot querySnapshot = await _firestore.collection('users').where('phone', whereIn: batch).get();
          for (var doc in querySnapshot.docs) {
            appContacts.add(UserModel.fromFirestore(doc));
          }
        }
      }
    }

    // Save the fresh list to the cache
    final prefs = await SharedPreferences.getInstance();
    List<String> jsonContactList = appContacts.map((user) => jsonEncode(user.toJson())).toList();
    await prefs.setStringList(_cacheKey, jsonContactList);

    return appContacts;
  }

  // Gets contacts from the cache first
  Future<List<UserModel>> getCachedContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getStringList(_cacheKey);

    if (cachedData != null) {
      return cachedData.map((jsonString) => UserModel.fromJson(jsonDecode(jsonString))).toList();
    }
    return []; // Return empty list if cache is empty
  }
}
