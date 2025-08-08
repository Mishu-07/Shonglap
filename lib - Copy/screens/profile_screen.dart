import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _aboutController = TextEditingController();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _cloudinary = CloudinaryPublic('dwqu7l0jk', 'shonglap_unsigned', cache: false);

  String? _gender;
  DateTime? _dob;
  String? _profilePicUrl;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        _emailController.text = data['email'] ?? '';
        _aboutController.text = data['about'] ?? 'No bio yet.';
        if (mounted) {
          setState(() {
            _gender = data['gender'];
            _profilePicUrl = data['profilePicUrl'];
            if (data['dob'] != null) {
              _dob = (data['dob'] as Timestamp).toDate();
            }
          });
        }
      }
    } catch (e) {
      // Handle error
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
              toolbarTitle: 'Crop Image',
              toolbarColor: Theme.of(context).colorScheme.primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
              cropStyle: CropStyle.circle), // Correct placement
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioLockEnabled: true,
            cropStyle: CropStyle.circle, // Correct placement
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() => _isSaving = true);
        File imageFile = File(croppedFile.path);

        try {
          final user = _auth.currentUser!;
          final response = await _cloudinary.uploadFile(
            CloudinaryFile.fromFile(imageFile.path, resourceType: CloudinaryResourceType.Image),
          );

          final url = response.secureUrl;
          await _firestore.collection('users').doc(user.uid).update({'profilePicUrl': url});

          if(mounted) {
            setState(() => _profilePicUrl = url);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile picture updated!'), backgroundColor: Colors.green),
            );
          }
        } catch (e) {
          if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Image upload failed: $e'), backgroundColor: Colors.red),
            );
          }
        } finally {
          if(mounted) setState(() => _isSaving = false);
        }
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final user = _auth.currentUser!;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'about': _aboutController.text.trim(),
        'gender': _gender,
        'dob': _dob != null ? Timestamp.fromDate(_dob!) : null,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      // Handle error
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
        slivers: [
          _buildSliverAppBar(theme),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Personal Information', theme),
                  _buildInfoTile(
                    icon: CupertinoIcons.person_fill,
                    label: 'Name',
                    value: _nameController.text,
                    theme: theme,
                    onTap: () => _showEditDialog('Name', _nameController, theme),
                  ),
                  _buildInfoTile(
                    icon: CupertinoIcons.heart_fill,
                    label: 'Gender',
                    value: _gender != null ? _gender![0].toUpperCase() + _gender!.substring(1) : 'Not set',
                    theme: theme,
                    onTap: () => _showGenderPicker(theme),
                  ),
                  _buildInfoTile(
                    icon: CupertinoIcons.gift_fill,
                    label: 'Birthday',
                    value: _dob != null ? DateFormat('MMMM dd, yyyy').format(_dob!) : 'Not set',
                    theme: theme,
                    onTap: () => _showDatePicker(theme),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Contact Information', theme),
                  _buildInfoTile(
                    icon: CupertinoIcons.at,
                    label: 'Email',
                    value: _emailController.text.isNotEmpty ? _emailController.text : 'Not set',
                    theme: theme,
                    onTap: () => _showEditDialog('Email', _emailController, theme, keyboardType: TextInputType.emailAddress),
                  ),
                  _buildInfoTile(
                    icon: CupertinoIcons.phone_fill,
                    label: 'Phone',
                    value: _auth.currentUser?.phoneNumber ?? 'Not available',
                    isReadOnly: true,
                    theme: theme,
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader('About Me', theme),
                  _buildInfoTile(
                    icon: CupertinoIcons.info_circle_fill,
                    label: 'About',
                    value: _aboutController.text,
                    theme: theme,
                    onTap: () => _showEditDialog('About', _aboutController, theme, maxLines: 4),
                  ),
                  const SizedBox(height: 32),
                  _buildSaveButton(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(ThemeData theme) {
    final hasProfilePic = _profilePicUrl != null && _profilePicUrl!.isNotEmpty;
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
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white.withOpacity(0.9),
                        backgroundImage: hasProfilePic ? NetworkImage(_profilePicUrl!) : null,
                        child: !hasProfilePic
                            ? Icon(Icons.person, size: 60, color: theme.colorScheme.primary)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)],
                            ),
                            child: _isSaving
                                ? const CupertinoActivityIndicator()
                                : Icon(Icons.camera_alt, color: theme.colorScheme.primary, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _nameController.text,
                    style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    _emailController.text,
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.white.withOpacity(0.8)),
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

  Widget _buildInfoTile({required IconData icon, required String label, required String value, VoidCallback? onTap, bool isReadOnly = false, required ThemeData theme}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isReadOnly ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
              if (!isReadOnly) Icon(Icons.edit, color: theme.colorScheme.onSurface.withOpacity(0.7), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(String field, TextEditingController controller, ThemeData theme, {TextInputType? keyboardType, int maxLines = 1}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text('Edit $field'),
          content: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                setState(() {});
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showGenderPicker(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.male),
                title: const Text('Male'),
                onTap: () {
                  setState(() => _gender = 'male');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.female),
                title: const Text('Female'),
                onTap: () {
                  setState(() => _gender = 'female');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.transgender),
                title: const Text('Other'),
                onTap: () {
                  setState(() => _gender = 'other');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDatePicker(ThemeData theme) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime.now(),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      setState(() {
        _dob = pickedDate;
      });
    }
  }

  Widget _buildSaveButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 5,
          shadowColor: theme.colorScheme.primary.withOpacity(0.4),
        ),
        child: _isSaving
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0))
            : Text(
          'Save All Changes',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
