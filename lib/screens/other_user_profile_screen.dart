import 'package:first_app/models/user_model.dart';
import 'package:first_app/utilities/assets_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class OtherUserProfileScreen extends StatelessWidget {
  final UserModel user;

  const OtherUserProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(theme),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('User Information', theme),
                  _buildInfoTile(
                    icon: CupertinoIcons.person_fill,
                    label: 'Name',
                    value: user.name,
                    theme: theme,
                  ),
                  if(user.gender != null)
                    _buildInfoTile(
                      icon: CupertinoIcons.heart_fill,
                      label: 'Gender',
                      value: user.gender![0].toUpperCase() + user.gender!.substring(1),
                      theme: theme,
                    ),
                  if(user.dob != null)
                    _buildInfoTile(
                      icon: CupertinoIcons.gift_fill,
                      label: 'Birthday',
                      value: DateFormat('MMMM dd, yyyy').format(user.dob!),
                      theme: theme,
                    ),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Contact Information', theme),
                  _buildInfoTile(
                    icon: CupertinoIcons.phone_fill,
                    label: 'Phone',
                    value: user.phone,
                    theme: theme,
                  ),
                  const SizedBox(height: 24),
                  if(user.about != null && user.about!.isNotEmpty)
                    _buildSectionHeader('About ${user.name.split(' ').first}', theme),
                  if(user.about != null && user.about!.isNotEmpty)
                    Text(
                      user.about!,
                      style: GoogleFonts.inter(fontSize: 16, height: 1.5),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildSendMessageButton(theme),
    );
  }

  Widget _buildSliverAppBar(ThemeData theme) {
    final hasProfilePic = user.profilePicUrl != null && user.profilePicUrl!.isNotEmpty;

    return SliverAppBar(
      expandedHeight: 250.0,
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      pinned: true,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, Color.lerp(theme.colorScheme.primary, Colors.black, 0.2)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white.withOpacity(0.9),
                    // Correctly display Cloudinary image or fallback to asset
                    backgroundImage: hasProfilePic
                        ? NetworkImage(user.profilePicUrl!)
                        : const AssetImage(AssetsManager.userImage) as ImageProvider,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name,
                    style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildInfoTile({required IconData icon, required String label, required String value, required ThemeData theme}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 24),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 14)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.inter(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendMessageButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            // TODO: Add navigation logic to the chat screen with this user
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 5,
            shadowColor: theme.colorScheme.primary.withOpacity(0.4),
          ),
          icon: const Icon(CupertinoIcons.chat_bubble_2_fill, color: Colors.white),
          label: Text(
            'Send Message',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
