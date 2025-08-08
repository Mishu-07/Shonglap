// lib/main_screens/home_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:first_app/main_screens/chats_list_screen.dart';
import 'package:first_app/main_screens/groups_screen.dart';
import 'package:first_app/main_screens/people_screen.dart';
import 'package:first_app/main_screens/settings_screen.dart';
import 'package:first_app/screens/profile_screen.dart';
import 'package:first_app/screens/select_contact_screen.dart';
import 'package:first_app/utilities/assets_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  String? _profilePicUrl;
  bool _isUserDataLoading = true;
  int _totalUnreadGroupMessages = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (mounted) {
      setState(() => _isUserDataLoading = true);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted && doc.exists) {
          setState(() {
            _profilePicUrl = doc.data()?['profilePicUrl'];
          });
        }
      } catch (e) {
        // Handle error
      } finally {
        if (mounted) {
          setState(() => _isUserDataLoading = false);
        }
      }
    } else {
      if (mounted) {
        setState(() => _isUserDataLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  void _handleMenuSelection(String value) async {
    switch (value) {
      case 'settings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
        break;
      case 'profile':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
        _loadUserData();
        break;
      case 'logout':
        _logout();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                children: const [
                  ChatsListScreen(),
                  GroupsScreen(),
                  PeopleScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SelectContactScreen()),
          );
        },
        // **FIX**: Use the dynamic theme color.
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.edit, color: Colors.white, size: 28),
      ),
      bottomNavigationBar: _buildBottomNavBar(theme),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final hasProfilePic = _profilePicUrl != null && _profilePicUrl!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Shonglap',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            offset: const Offset(0, 50),
            elevation: 2,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              _buildPopupMenuItem('My Profile', CupertinoIcons.person_fill, 'profile', theme),
              _buildPopupMenuItem('Settings', CupertinoIcons.settings, 'settings', theme),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.square_arrow_left_fill, color: Colors.red),
                    const SizedBox(width: 12),
                    Text('Logout', style: GoogleFonts.inter(color: Colors.red)),
                  ],
                ),
              ),
            ],
            child: CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.surface,
              backgroundImage: hasProfilePic
                  ? CachedNetworkImageProvider(_profilePicUrl!)
                  : const AssetImage(AssetsManager.userImage) as ImageProvider,
              child: _isUserDataLoading ? const CupertinoActivityIndicator() : null,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(String title, IconData iconData, String value, ThemeData theme) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(iconData, color: theme.colorScheme.onSurface.withOpacity(0.7)),
          const SizedBox(width: 12),
          Text(title, style: GoogleFonts.inter(color: theme.colorScheme.onSurface)),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.transparent,
        elevation: 0,
        // **FIX**: Use the dynamic theme color.
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(),
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(CupertinoIcons.chat_bubble_2), activeIcon: Icon(CupertinoIcons.chat_bubble_2_fill), label: 'Chats'),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text(_totalUnreadGroupMessages.toString()),
              isLabelVisible: _totalUnreadGroupMessages > 0,
              child: const Icon(CupertinoIcons.group),
            ),
            activeIcon: Badge(
              label: Text(_totalUnreadGroupMessages.toString()),
              isLabelVisible: _totalUnreadGroupMessages > 0,
              child: const Icon(CupertinoIcons.group_solid),
            ),
            label: 'Groups',
          ),
          const BottomNavigationBarItem(icon: Icon(CupertinoIcons.person_2), activeIcon: Icon(CupertinoIcons.person_2_fill), label: 'People'),
        ],
      ),
    );
  }
}
