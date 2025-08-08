import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:first_app/models/group_model.dart';
import 'package:first_app/models/user_model.dart';
import 'package:first_app/utilities/assets_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GroupSettingsScreen extends StatefulWidget {
  final GroupModel group;
  const GroupSettingsScreen({super.key, required this.group});

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  // **FIX**: Use a Future to fetch fresh member data.
  late Future<List<UserModel>> _membersFuture;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // **FIX**: Assign the fetch operation to the future.
    _membersFuture = _fetchMembers();
  }

  // **NEW**: Function to fetch full member details from Firestore.
  Future<List<UserModel>> _fetchMembers() async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(widget.group.id).get();
      if (!groupDoc.exists) return [];

      final List<String> memberIds = List<String>.from(groupDoc.data()?['members'] ?? []);
      if (memberIds.isEmpty) return [];

      final List<UserModel> members = [];
      // Fetch users in chunks of 10 to satisfy Firestore's 'whereIn' limitation.
      for (var i = 0; i < memberIds.length; i += 10) {
        final chunk = memberIds.sublist(i, i + 10 > memberIds.length ? memberIds.length : i + 10);
        final usersSnapshot = await _firestore.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
        members.addAll(usersSnapshot.docs.map((doc) => UserModel.fromFirestore(doc)));
      }
      return members;
    } catch (e) {
      // Handle error appropriately
      print("Error fetching members: $e");
      return [];
    }
  }

  Future<void> _leaveGroup() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Show a confirmation dialog
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: Text('Are you sure you want to leave "${widget.group.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('groups').doc(widget.group.id).update({
        'members': FieldValue.arrayRemove([currentUser.uid])
      });
      // Pop all the way back to the home screen
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Group Info', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      // **FIX**: Use a FutureBuilder to handle the loading state.
      body: FutureBuilder<List<UserModel>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Could not load group members.'));
          }

          final members = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                const CircleAvatar(
                  radius: 60,
                  child: Icon(CupertinoIcons.group_solid, size: 60),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.group.name,
                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Group • ${members.length} members', // **FIX**: Use the length of the fetched list.
                  style: GoogleFonts.inter(fontSize: 16, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                ),
                const SizedBox(height: 24),
                _buildMembersSection(theme, members), // **FIX**: Pass the fetched list.
                const SizedBox(height: 24),
                _buildExitGroupButton(theme),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMembersSection(ThemeData theme, List<UserModel> members) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(CupertinoIcons.person_2_fill, color: theme.colorScheme.onSurface.withOpacity(0.7)),
            title: Text('${members.length} Members'),
            trailing: TextButton(
              onPressed: () {
                // TODO: Add logic to add new members
              },
              child: const Text('Add'),
            ),
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return ListTile(
                leading: CircleAvatar(
                  radius: 20,
                  backgroundImage: member.profilePicUrl != null && member.profilePicUrl!.isNotEmpty
                      ? NetworkImage(member.profilePicUrl!)
                      : const AssetImage(AssetsManager.userImage) as ImageProvider,
                ),
                title: Text(member.name),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExitGroupButton(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: _leaveGroup,
        leading: const Icon(CupertinoIcons.square_arrow_left, color: Colors.red),
        title: Text('Exit Group', style: GoogleFonts.inter(color: Colors.red)),
      ),
    );
  }
}
