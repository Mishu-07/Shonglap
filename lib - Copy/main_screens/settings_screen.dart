import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:first_app/screens/profile_screen.dart';
import 'package:first_app/theme/theme_notifier.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  bool _areNotificationsOn = true;

  @override
  void initState() {
    super.initState();
    AdaptiveTheme.getThemeMode().then((theme) {
      if (mounted) {
        setState(() {
          _isDarkMode = theme == AdaptiveThemeMode.dark;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Get the ThemeNotifier to update the color.
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader('Account', theme),
          _buildSettingsCard(
            theme: theme,
            children: [
              _buildSettingsTile(
                icon: CupertinoIcons.person_fill,
                title: 'My Profile',
                theme: theme,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionHeader('Appearance', theme),
          _buildSettingsCard(
            theme: theme,
            children: [
              SwitchListTile(
                title: Text('Dark Mode', style: GoogleFonts.inter()),
                secondary: Icon(_isDarkMode ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill),
                value: _isDarkMode,
                onChanged: (value) {
                  setState(() {
                    _isDarkMode = value;
                  });
                  if (value) {
                    AdaptiveTheme.of(context).setDark();
                  } else {
                    AdaptiveTheme.of(context).setLight();
                  }
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Accent Color", style: GoogleFonts.inter(fontSize: 16)),
                    const SizedBox(height: 16),
                    _buildColorPicker(themeNotifier),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionHeader('Notifications', theme),
          _buildSettingsCard(
            theme: theme,
            children: [
              SwitchListTile(
                title: Text('Push Notifications', style: GoogleFonts.inter()),
                secondary: const Icon(CupertinoIcons.bell_fill),
                value: _areNotificationsOn,
                onChanged: (value) {
                  setState(() {
                    _areNotificationsOn = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the row of selectable color circles.
  Widget _buildColorPicker(ThemeNotifier notifier) {
    final List<Color> colors = [
      const Color(0xFF4A3AFF), // Default Purple
      Colors.blue,
      Colors.teal,
      Colors.green,
      Colors.orange,
      Colors.pink,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: colors.map((color) {
        bool isSelected = notifier.primaryColor.value == color.value;
        return GestureDetector(
          onTap: () => notifier.setPrimaryColor(color),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8), width: 3)
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 24)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
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

  Widget _buildSettingsCard({required List<Widget> children, required ThemeData theme}) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, Color? titleColor, VoidCallback? onTap, required ThemeData theme}) {
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.onSurface.withOpacity(0.7)),
      title: Text(title, style: GoogleFonts.inter(color: titleColor)),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.7)),
      onTap: onTap,
    );
  }
}
