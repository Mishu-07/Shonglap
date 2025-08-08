// lib/screens/conversation_details_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:first_app/models/user_model.dart';
import 'package:first_app/screens/other_user_profile_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ConversationDetailsScreen extends StatefulWidget {
  final UserModel otherUser;
  const ConversationDetailsScreen({super.key, required this.otherUser});

  @override
  State<ConversationDetailsScreen> createState() => _ConversationDetailsScreenState();
}

class _ConversationDetailsScreenState extends State<ConversationDetailsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _isBlocked = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkIfBlocked();
  }

  Future<void> _checkIfBlocked() async {
    setState(() => _isLoading = true);
    final currentUserDoc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
    final List<dynamic> blockedList = currentUserDoc.data()?['blockedUsers'] ?? [];
    if (mounted) {
      setState(() {
        _isBlocked = blockedList.contains(widget.otherUser.uid);
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBlockUser() async {
    final currentUserRef = _firestore.collection('users').doc(_auth.currentUser!.uid);
    if (_isBlocked) {
      // Unblock
      await currentUserRef.update({
        'blockedUsers': FieldValue.arrayRemove([widget.otherUser.uid])
      });
    } else {
      // Block
      await currentUserRef.update({
        'blockedUsers': FieldValue.arrayUnion([widget.otherUser.uid])
      });
    }
    _checkIfBlocked(); // Refresh the state
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Conversation Info', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: widget.otherUser.profilePicUrl != null && widget.otherUser.profilePicUrl!.isNotEmpty
                  ? NetworkImage(widget.otherUser.profilePicUrl!)
                  : null,
              child: widget.otherUser.profilePicUrl == null || widget.otherUser.profilePicUrl!.isEmpty
                  ? const Icon(Icons.person, size: 50)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(widget.otherUser.name, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(widget.otherUser.phone, style: GoogleFonts.inter(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 24),
            _buildOptions(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildOptions(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildTile(
            icon: CupertinoIcons.person_circle_fill,
            title: 'View Profile',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => OtherUserProfileScreen(user: widget.otherUser)),
            ),
          ),
          const Divider(height: 1),
          _buildTile(
            icon: CupertinoIcons.search,
            title: 'Search in Conversation',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature coming soon!')));
            },
          ),
          const Divider(height: 1),
          _buildTile(
            icon: CupertinoIcons.bell_slash_fill,
            title: 'Mute Notifications',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature coming soon!')));
            },
          ),
          const Divider(height: 1, thickness: 8),
          _buildTile(
            icon: CupertinoIcons.hand_raised_slash_fill,
            title: _isBlocked ? 'Unblock ${widget.otherUser.name}' : 'Block ${widget.otherUser.name}',
            color: Colors.red,
            onTap: _toggleBlockUser,
          ),
        ],
      ),
    );
  }

  Widget _buildTile({required IconData icon, required String title, Color? color, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: GoogleFonts.inter(color: color)),
      onTap: onTap,
    );
  }
}
