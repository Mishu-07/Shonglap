// lib/main_screens/chats_list_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:first_app/models/user_model.dart';
import 'package:first_app/screens/ai_chat_screen.dart';
import 'package:first_app/screens/chat_conversation_screen.dart';
import 'package:first_app/widgets/chat_list_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  late User _currentUser;

  final Map<String, UserModel> _userCache = {};

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser!;
  }

  Future<UserModel> _getUserDetails(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    } else {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) {
        return UserModel(uid: userId, name: 'Deleted User', phone: '');
      }
      final user = UserModel.fromFirestore(doc);
      if (mounted) {
        setState(() {
          _userCache[userId] = user;
        });
      }
      return user;
    }
  }

  Future<void> _deleteConversation(String chatDocId) async {
    await _firestore.collection('chats').doc(chatDocId).update({
      'deletedBy': FieldValue.arrayUnion([_currentUser.uid])
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('chats')
            .where('participants', arrayContains: _currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Something went wrong: ${snapshot.error}'));
          }

          var chatDocs = (snapshot.data?.docs ?? []).where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final List<dynamic> deletedBy = data['deletedBy'] ?? [];
            return !deletedBy.contains(_currentUser.uid);
          }).toList();

          chatDocs.sort((a, b) {
            Timestamp tsA = (a.data() as Map<String, dynamic>)['lastMessageTimestamp'] ?? Timestamp(0, 0);
            Timestamp tsB = (b.data() as Map<String, dynamic>)['lastMessageTimestamp'] ?? Timestamp(0, 0);
            return tsB.compareTo(tsA);
          });

          // Always show the AI chat at the top.
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: chatDocs.length + 1, // Add 1 for the AI chat
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildAiChatItem();
              }
              final chatDoc = chatDocs[index - 1];
              return _buildConversationItem(chatDoc);
            },
          );
        },
      ),
    );
  }

  // A dedicated widget for the AI chat item.
  Widget _buildAiChatItem() {
    return ChatListItem(
      name: "AI Assistant",
      message: "Ask me anything...",
      time: "",
      avatarUrl: "", // You can add a URL to a logo here
      isOnline: true,
      onTap: () {
        Navigator.push(
          context,
          // Navigate to the new AiChatScreen.
          MaterialPageRoute(builder: (context) => const AiChatScreen()),
        );
      },
    );
  }

  Widget _buildConversationItem(DocumentSnapshot chatDoc) {
    final chatData = chatDoc.data() as Map<String, dynamic>;
    final List<String> participants = List<String>.from(chatData['participants'] ?? []);
    final String otherUserId = participants.firstWhere((id) => id != _currentUser.uid, orElse: () => '');

    if (otherUserId.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<UserModel>(
      future: _getUserDetails(otherUserId),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(height: 70),
          );
        }

        final otherUser = userSnapshot.data!;
        final lastMessage = chatData['lastMessage'] ?? 'No messages yet.';
        final timestamp = (chatData['lastMessageTimestamp'] as Timestamp? ?? Timestamp.now()).toDate();

        return Dismissible(
          key: Key(chatDoc.id),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            _deleteConversation(chatDoc.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Conversation with ${otherUser.name} deleted.')),
            );
          },
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: ChatListItem(
            name: otherUser.name,
            message: lastMessage,
            time: DateFormat.jm().format(timestamp),
            avatarUrl: otherUser.profilePicUrl ?? '',
            unreadCount: 0,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatConversationScreen(otherUser: otherUser),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.chat_bubble_2_fill, size: 80, color: theme.colorScheme.onSurface.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              'No Chats Yet',
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the "Compose" button to start a new conversation.',
              style: GoogleFonts.inter(fontSize: 16, color: theme.colorScheme.onSurface.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
