// lib/screens/select_contact_screen.dart

import 'dart:async';
import 'package:first_app/models/user_model.dart';
import 'package:first_app/screens/chat_conversation_screen.dart';
import 'package:first_app/screens/create_group_screen.dart';
import 'package:first_app/screens/other_user_profile_screen.dart';
import 'package:first_app/services/contact_service.dart';
import 'package:first_app/utilities/assets_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class SelectContactScreen extends StatefulWidget {
  const SelectContactScreen({super.key});

  @override
  State<SelectContactScreen> createState() => _SelectContactScreenState();
}

class _SelectContactScreenState extends State<SelectContactScreen> {
  final ContactService _contactService = ContactService();
  List<UserModel> _allContacts = [];
  List<UserModel> _filteredContacts = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if(!mounted) {
        timer.cancel();
        return;
      }
      _loadContacts(fromCache: false);
    });
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts({bool fromCache = true}) async {
    if (fromCache && mounted) {
      if (_allContacts.isEmpty) {
        setState(() => _isLoading = true);
      }
      final cachedContacts = await _contactService.getCachedContacts();
      if(mounted){
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
        return user.name.toLowerCase().contains(query) ||
            user.phone.contains(query);
      }).toList();
    });
  }

  void _navigateToUserProfile(UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtherUserProfileScreen(user: user),
      ),
    );
  }

  Future<void> _openAddContact() async {
    await FlutterContacts.openExternalInsert();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('New Conversation', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or number...',
                prefixIcon: const Icon(CupertinoIcons.search),
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: () => _loadContacts(fromCache: false),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                children: [
                  _buildAddContactCard(theme),
                  _buildNewGroupCard(theme),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Divider(),
                  ),
                  if (_filteredContacts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 64.0),
                      child: _buildEmptyState(theme),
                    )
                  else
                    ..._filteredContacts.map((user) => _buildContactCard(user, theme)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddContactCard(ThemeData theme) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surface,
      child: ListTile(
        onTap: _openAddContact,
        leading: CircleAvatar(
          radius: 25,
          // **FIX**: Use the dynamic theme color.
          backgroundColor: theme.colorScheme.primary,
          child: const Icon(CupertinoIcons.person_add_solid, color: Colors.white),
        ),
        title: Text('Add New Contact', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
      ),
    );
  }

  Widget _buildNewGroupCard(ThemeData theme) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surface,
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
          );
        },
        leading: CircleAvatar(
          radius: 25,
          // **FIX**: Use the dynamic theme color.
          backgroundColor: theme.colorScheme.primary,
          child: const Icon(CupertinoIcons.group_solid, color: Colors.white),
        ),
        title: Text('New Group', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
      ),
    );
  }

  Widget _buildContactCard(UserModel user, ThemeData theme) {
    final hasProfilePic = user.profilePicUrl != null && user.profilePicUrl!.isNotEmpty;
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
              builder: (context) => ChatConversationScreen(otherUser: user),
            ),
          );
        },
        leading: GestureDetector(
          onTap: () => _navigateToUserProfile(user),
          child: CircleAvatar(
            radius: 25,
            backgroundImage: hasProfilePic
                ? NetworkImage(user.profilePicUrl!)
                : const AssetImage(AssetsManager.userImage) as ImageProvider,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          ),
        ),
        title: Text(user.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        subtitle: Text(user.phone, style: GoogleFonts.inter(color: theme.colorScheme.onSurface.withOpacity(0.7))),
        trailing: Icon(
          CupertinoIcons.chevron_forward,
          size: 18,
          color: theme.colorScheme.onSurface.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.person_3, size: 80, color: theme.colorScheme.onSurface.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty ? 'No Contacts Found' : 'No results found',
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isEmpty
                  ? 'None of your phone contacts are on Shonglap. Pull down or wait to refresh.'
                  : 'Try a different search term.',
              style: GoogleFonts.inter(fontSize: 16, color: theme.colorScheme.onSurface.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
