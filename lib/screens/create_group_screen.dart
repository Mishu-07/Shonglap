import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:first_app/models/group_model.dart';
import 'package:first_app/models/user_model.dart';
import 'package:first_app/screens/group_chat_screen.dart';
import 'package:first_app/services/contact_service.dart';
import 'package:first_app/utilities/assets_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final ContactService _contactService = ContactService();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<UserModel> _allContacts = [];
  List<UserModel> _filteredContacts = [];
  final List<UserModel> _selectedContacts = [];

  bool _isLoading = true;
  bool _isCreatingGroup = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _loadContacts(fromCache: false);
      } else {
        timer.cancel();
      }
    });
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts({bool fromCache = true}) async {
    if (fromCache && mounted) {
      if (_allContacts.isEmpty) setState(() => _isLoading = true);
      final cachedContacts = await _contactService.getCachedContacts();
      if (mounted) {
        setState(() {
          _allContacts = cachedContacts;
          _filteredContacts = cachedContacts;
          _isLoading = false;
        });
      }
    }
    final freshContacts = await _contactService.fetchAndCacheContacts();
    if (mounted) {
      setState(() {
        _allContacts = freshContacts;
        _filterContacts();
      });
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredContacts = _allContacts.where((user) {
        return user.name.toLowerCase().contains(query) || user.phone.contains(query);
      }).toList();
    });
  }

  void _onContactSelected(UserModel user) {
    setState(() {
      if (_selectedContacts.contains(user)) {
        _selectedContacts.remove(user);
      } else {
        _selectedContacts.add(user);
      }
    });
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a group name.')));
      return;
    }
    if (_selectedContacts.length < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one member.')));
      return;
    }

    setState(() => _isCreatingGroup = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Not logged in.')));
      setState(() => _isCreatingGroup = false);
      return;
    }

    final firestore = FirebaseFirestore.instance;

    try {
      final List<String> memberIds = _selectedContacts.map((user) => user.uid).toList();
      memberIds.add(currentUser.uid);

      final groupId = const Uuid().v4();
      final now = Timestamp.now();
      final groupDoc = {
        'groupId': groupId,
        'groupName': _groupNameController.text.trim(),
        'members': memberIds,
        'createdBy': currentUser.uid,
        'createdAt': now,
        'lastMessage': '${currentUser.displayName ?? 'Someone'} created the group.',
        'lastMessageTimestamp': now,
      };

      await firestore.collection('groups').doc(groupId).set(groupDoc);

      final batch = firestore.batch();
      for (var memberId in memberIds) {
        final userDocRef = firestore.collection('users').doc(memberId);
        batch.update(userDocRef, {'groups': FieldValue.arrayUnion([groupId])});
      }
      await batch.commit();

      final newGroup = GroupModel(
        id: groupId,
        name: _groupNameController.text.trim(),
        lastMessage: groupDoc['lastMessage'] as String,
        lastMessageTimestamp: now,
        members: _selectedContacts,
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => GroupChatScreen(group: newGroup),
        ),
            (route) => route.isFirst,
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create group: $e')));
    } finally {
      if (mounted) {
        setState(() => _isCreatingGroup = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('New Group', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildGroupInfoSection(theme),
          _buildSearchBar(theme),
          _buildSelectedContactsList(theme),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredContacts.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              itemCount: _filteredContacts.length,
              itemBuilder: (context, index) {
                final user = _filteredContacts[index];
                final isSelected = _selectedContacts.contains(user);
                return _buildContactTile(user, isSelected, theme);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedContacts.isNotEmpty
          ? FloatingActionButton(
        onPressed: _isCreatingGroup ? null : _createGroup,
        backgroundColor: theme.colorScheme.primary,
        child: _isCreatingGroup
            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)
            : const Icon(Icons.check, color: Colors.white),
      )
          : null,
    );
  }

  Widget _buildGroupInfoSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            child: Icon(CupertinoIcons.group_solid, size: 30, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                hintText: 'Group Name',
                border: InputBorder.none,
              ),
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search contacts to add...',
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

  Widget _buildSelectedContactsList(ThemeData theme) {
    if (_selectedContacts.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedContacts.length,
        itemBuilder: (context, index) {
          final user = _selectedContacts[index];
          return Container(
            width: 70,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundImage: user.profilePicUrl != null && user.profilePicUrl!.isNotEmpty
                          ? NetworkImage(user.profilePicUrl!)
                          : const AssetImage(AssetsManager.userImage) as ImageProvider,
                    ),
                    Positioned(
                      top: -5,
                      right: -5,
                      child: InkWell(
                        onTap: () => _onContactSelected(user),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.grey,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.name.split(' ').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContactTile(UserModel user, bool isSelected, ThemeData theme) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surface,
      child: ListTile(
        onTap: () => _onContactSelected(user),
        leading: CircleAvatar(
          radius: 25,
          backgroundImage: user.profilePicUrl != null && user.profilePicUrl!.isNotEmpty
              ? NetworkImage(user.profilePicUrl!)
              : const AssetImage(AssetsManager.userImage) as ImageProvider,
        ),
        title: Text(user.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        subtitle: Text(user.phone, style: GoogleFonts.inter(color: theme.colorScheme.onSurface.withOpacity(0.7))),
        trailing: Checkbox(
          value: isSelected,
          onChanged: (bool? value) => _onContactSelected(user),
          shape: const CircleBorder(),
          activeColor: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          'No contacts found.',
          style: GoogleFonts.inter(fontSize: 16, color: theme.colorScheme.onSurface.withOpacity(0.7)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
