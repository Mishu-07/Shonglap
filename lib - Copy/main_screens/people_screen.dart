import 'dart:async';
import 'package:first_app/models/user_model.dart';
import 'package:first_app/screens/other_user_profile_screen.dart';
import 'package:first_app/services/contact_service.dart';
import 'package:first_app/utilities/assets_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
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
      setState(() {
        _allContacts = cachedContacts;
        _filteredContacts = cachedContacts;
        _isLoading = false;
      });
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
    // This is the correct, reliable method to open the native add contact screen.
    await FlutterContacts.openExternalInsert();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildSearchBar(theme),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: () => _loadContacts(fromCache: false),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                children: [
                  _buildAddContactCard(theme),
                  // Correctly handle the empty state
                  if (_filteredContacts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 64.0),
                      child: _buildEmptyState(theme),
                    )
                  else
                  // Build the list of contact cards
                    ..._filteredContacts.map((user) => _buildContactCard(user, theme)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search contacts...',
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
          backgroundColor: theme.colorScheme.primary,
          child: const Icon(CupertinoIcons.person_add_solid, color: Colors.white),
        ),
        title: Text('Add New Contact', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
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
        onTap: () => _navigateToUserProfile(user),
        leading: CircleAvatar(
          radius: 25,
          // Use NetworkImage for Cloudinary URL, otherwise use the default asset image
          backgroundImage: hasProfilePic
              ? NetworkImage(user.profilePicUrl!)
              : const AssetImage(AssetsManager.userImage) as ImageProvider,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
        ),
        title: Text(user.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        subtitle: Text(user.phone, style: GoogleFonts.inter(color: theme.colorScheme.onSurface.withOpacity(0.7))),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: theme.colorScheme.onSurface.withOpacity(0.5),
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
