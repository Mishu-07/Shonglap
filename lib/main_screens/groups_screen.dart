import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:first_app/models/group_model.dart';
import 'package:first_app/screens/group_chat_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  List<GroupModel> _cachedGroups = [];
  String _searchQuery = "";
  static const String _cacheKey = 'groups_cache';

  @override
  void initState() {
    super.initState();
    _loadCachedGroups();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // **NEW**: Function to leave a group.
  Future<void> _leaveGroup(String groupId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayRemove([currentUser.uid])
    });
  }

  Future<void> _loadCachedGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getStringList(_cacheKey);
    if (cachedData != null && mounted) {
      setState(() {
        _cachedGroups = cachedData.map((jsonString) => GroupModel.fromJson(jsonDecode(jsonString))).toList();
      });
    }
  }

  Future<void> _cacheGroups(List<QueryDocumentSnapshot> docs) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> jsonList = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return jsonEncode({
        'id': data['groupId'],
        'name': data['groupName'],
        'groupPicUrl': data['groupPicUrl'],
        'lastMessage': data['lastMessage'],
        'lastMessageTimestamp': {
          '_seconds': (data['lastMessageTimestamp'] as Timestamp).seconds,
          '_nanoseconds': (data['lastMessageTimestamp'] as Timestamp).nanoseconds,
        }
      });
    }).toList();
    await prefs.setStringList(_cacheKey, jsonList);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = _auth.currentUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildSearchBar(theme),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('groups')
                  .where('members', arrayContains: currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _cachedGroups.isNotEmpty) {
                  final filteredCachedGroups = _getFilteredGroups(_cachedGroups);
                  return _buildGroupList(filteredCachedGroups, theme);
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(theme, isSearch: false);
                }

                var groupDocs = snapshot.data!.docs;
                _cacheGroups(groupDocs);

                groupDocs.sort((a, b) {
                  Timestamp tsA = (a.data() as Map<String, dynamic>)['lastMessageTimestamp'] ?? Timestamp(0, 0);
                  Timestamp tsB = (b.data() as Map<String, dynamic>)['lastMessageTimestamp'] ?? Timestamp(0, 0);
                  return tsB.compareTo(tsA);
                });

                final List<GroupModel> groups = groupDocs.map((doc) => GroupModel.fromFirestore(doc)).toList();
                final filteredGroups = _getFilteredGroups(groups);

                if (filteredGroups.isEmpty) {
                  return _buildEmptyState(theme, isSearch: _searchQuery.isNotEmpty);
                }

                return _buildGroupList(filteredGroups, theme);
              },
            ),
          ),
        ],
      ),
    );
  }

  List<GroupModel> _getFilteredGroups(List<GroupModel> groups) {
    if (_searchQuery.isEmpty) {
      return groups;
    }
    return groups.where((group) => group.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  ListView _buildGroupList(List<GroupModel> groups, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        // **NEW**: Wrapped with Dismissible for swipe-to-leave.
        return Dismissible(
          key: Key(group.id),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            _leaveGroup(group.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('You left "${group.name}".')),
            );
          },
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.exit_to_app, color: Colors.white),
          ),
          child: _buildGroupConversationTile(group, theme),
        );
      },
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search groups...',
          prefixIcon: const Icon(CupertinoIcons.search),
          filled: true,
          fillColor: theme.colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupConversationTile(GroupModel group, ThemeData theme) {
    final bool hasUnread = false;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surface,
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupChatScreen(group: group),
            ),
          );
        },
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          child: Icon(
            CupertinoIcons.group_solid,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(
          group.name,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          group.lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: hasUnread
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withOpacity(0.7),
            fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: Text(
          DateFormat.jm().format(group.lastMessageTimestamp.toDate()),
          style: GoogleFonts.inter(
            fontSize: 12,
            color: hasUnread ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, {bool isSearch = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSearch ? CupertinoIcons.search : CupertinoIcons.group, size: 80, color: theme.colorScheme.onSurface.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(
              isSearch ? 'No Groups Found' : 'No Groups Yet',
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isSearch ? 'Try a different search term.' : 'Create a new group to start chatting with your friends.',
              style: GoogleFonts.inter(fontSize: 16, color: theme.colorScheme.onSurface.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
