// lib/screens/group_chat_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:first_app/models/chat_message_model.dart';
import 'package:first_app/models/group_model.dart';
import 'package:first_app/screens/group_settings_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:uuid/uuid.dart';

class GroupChatScreen extends StatefulWidget {
  final GroupModel group;
  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _messageController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _cloudinary = CloudinaryPublic('dwqu7l0jk', 'shonglap_unsigned', cache: false);

  late User _currentUser;
  bool _isUploading = false;
  final Map<String, String> _userNamesCache = {};

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser!;
    _userNamesCache[_currentUser.uid] = 'You';
  }

  Future<void> _fetchUserNames(List<ChatMessageModel> messages) async {
    final idsToFetch = <String>{};
    for (var msg in messages) {
      if (!_userNamesCache.containsKey(msg.senderId)) {
        idsToFetch.add(msg.senderId);
      }
    }

    if (idsToFetch.isNotEmpty) {
      final snapshot = await _firestore.collection('users').where(FieldPath.documentId, whereIn: idsToFetch.toList()).get();
      for (var doc in snapshot.docs) {
        _userNamesCache[doc.id] = doc.data()['name'] ?? 'Unknown User';
      }
      if(mounted) setState(() {});
    }
  }

  Future<void> _sendMessage({String? text, String? mediaUrl, MessageType type = MessageType.text}) async {
    if (text == null && mediaUrl == null) return;
    _messageController.clear();

    final messageId = const Uuid().v4();
    final message = ChatMessageModel(
      id: messageId,
      senderId: _currentUser.uid,
      text: text,
      timestamp: Timestamp.now(),
      type: type,
      mediaUrl: mediaUrl,
    );

    await _firestore
        .collection('groups')
        .doc(widget.group.id)
        .collection('messages')
        .doc(messageId)
        .set(message.toJson());

    await _firestore.collection('groups').doc(widget.group.id).update({
      'lastMessage': type == MessageType.text ? text : 'New media message',
      'lastMessageTimestamp': Timestamp.now(),
    });
  }

  Future<void> _pickAndUploadMedia({required bool isVideo}) async {
    final picker = ImagePicker();
    final XFile? pickedFile = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile == null) return;
    if(mounted) setState(() => _isUploading = true);

    try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(pickedFile.path, resourceType: isVideo ? CloudinaryResourceType.Video : CloudinaryResourceType.Image),
      );
      await _sendMessage(mediaUrl: response.secureUrl, type: isVideo ? MessageType.video : MessageType.image);
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if(mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _onReactionSelected(ChatMessageModel message, String emoji) async {
    final docRef = _firestore.collection('groups').doc(widget.group.id).collection('messages').doc(message.id);
    final newReactions = Map<String, String>.from(message.reactions);

    if (newReactions[_currentUser.uid] == emoji) {
      newReactions.remove(_currentUser.uid);
    } else {
      newReactions[_currentUser.uid] = emoji;
    }

    await docRef.update({'reactions': newReactions});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // **FIX**: Use a StreamBuilder to get live updates for the group details.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('groups').doc(widget.group.id).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return AppBar(elevation: 0, backgroundColor: theme.scaffoldBackgroundColor); // Placeholder
            }
            final groupData = snapshot.data!.data() as Map<String, dynamic>?;
            final members = groupData?['members'] as List<dynamic>? ?? [];
            return _buildAppBar(theme, members.length);
          },
        ),
      ),
      body: Column(
        children: [
          if (_isUploading) const LinearProgressIndicator(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('groups')
                  .doc(widget.group.id)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No messages in this group yet.', style: GoogleFonts.inter()));
                }

                final messages = snapshot.data!.docs
                    .map((doc) => ChatMessageModel.fromFirestore(doc))
                    .toList();

                _fetchUserNames(messages);

                return GroupedListView<ChatMessageModel, DateTime>(
                  padding: const EdgeInsets.all(8),
                  reverse: true,
                  order: GroupedListOrder.DESC,
                  elements: messages,
                  groupBy: (message) => DateTime(message.timestamp.toDate().year, message.timestamp.toDate().month, message.timestamp.toDate().day),
                  groupHeaderBuilder: (message) => _buildDateSeparator(message.timestamp.toDate(), theme),
                  itemBuilder: (context, message) => _buildMessageBubble(message, theme),
                );
              },
            ),
          ),
          _buildMessageInputField(theme),
        ],
      ),
    );
  }

  AppBar _buildAppBar(ThemeData theme, int memberCount) {
    return AppBar(
      elevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            child: Icon(CupertinoIcons.group_solid, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.group.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
              // **FIX**: Display the live member count.
              Text(
                '$memberCount members',
                style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GroupSettingsScreen(group: widget.group))),
          icon: const Icon(CupertinoIcons.ellipsis_vertical),
        ),
      ],
    );
  }

  Widget _buildDateSeparator(DateTime date, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Card(
          color: theme.colorScheme.surface.withOpacity(0.8),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              DateFormat.yMMMd().format(date),
              style: GoogleFonts.inter(color: theme.colorScheme.onSurface.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message, ThemeData theme) {
    final isMyMessage = message.senderId == _currentUser.uid;
    return GestureDetector(
      onLongPress: () => _showReactionMenu(message, theme),
      child: Align(
        alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 1,
              shadowColor: Colors.black.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isMyMessage ? const Radius.circular(20) : const Radius.circular(4),
                  bottomRight: isMyMessage ? const Radius.circular(4) : const Radius.circular(20),
                ),
              ),
              color: isMyMessage ? theme.colorScheme.primary : theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMyMessage)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          _userNamesCache[message.senderId] ?? '...',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 14),
                        ),
                      ),
                    _buildMessageContent(message, isMyMessage, theme),
                  ],
                ),
              ),
            ),
            if (message.reactions.isNotEmpty) _buildReactionsDisplay(message.reactions, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionsDisplay(Map<String, String> reactions, ThemeData theme) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    final reactionCounts = <String, int>{};
    for (var emoji in reactions.values) {
      reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 8.0, right: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reactionCounts.entries.map((entry) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5))
            ),
            child: Row(
              children: [
                Text(entry.key),
                const SizedBox(width: 4),
                Text(
                  entry.value.toString(),
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showReactionMenu(ChatMessageModel message, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(12),
          child: Card(
            color: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['👍', '❤️', '😂', '😮', '�', '🙏'].map((emoji) {
                  return IconButton(
                    icon: Text(emoji, style: const TextStyle(fontSize: 28)),
                    onPressed: () {
                      _onReactionSelected(message, emoji);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageContent(ChatMessageModel message, bool isMyMessage, ThemeData theme) {
    switch (message.type) {
      case MessageType.text:
        return Text(
          message.text!,
          style: GoogleFonts.inter(color: isMyMessage ? Colors.white : theme.colorScheme.onSurface, fontSize: 16),
        );
      case MessageType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            message.mediaUrl!,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Padding(padding: EdgeInsets.all(32.0), child: CupertinoActivityIndicator());
            },
          ),
        );
      case MessageType.video:
        return Container(
          width: 200,
          height: 120,
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Icon(CupertinoIcons.play_circle_fill, color: Colors.white, size: 40)),
        );
      case MessageType.deleted:
        return Text(
          "Message unsent",
          style: GoogleFonts.inter(fontStyle: FontStyle.italic, color: theme.colorScheme.onSurface.withOpacity(0.7)),
        );
    }
  }

  Widget _buildMessageInputField(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [BoxShadow(offset: const Offset(0, -2), blurRadius: 10, color: Colors.black.withOpacity(0.05))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(CupertinoIcons.paperclip, color: theme.colorScheme.onSurface.withOpacity(0.7)),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => SafeArea(
                    child: Wrap(
                      children: <Widget>[
                        ListTile(
                          leading: const Icon(CupertinoIcons.photo_on_rectangle),
                          title: const Text('Photo'),
                          onTap: () {
                            Navigator.pop(context);
                            _pickAndUploadMedia(isVideo: false);
                          },
                        ),
                        ListTile(
                          leading: const Icon(CupertinoIcons.video_camera_solid),
                          title: const Text('Video'),
                          onTap: () {
                            Navigator.pop(context);
                            _pickAndUploadMedia(isVideo: true);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                ),
                onSubmitted: (text) => _sendMessage(text: text.trim()),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              onPressed: () => _sendMessage(text: _messageController.text.trim()),
              mini: true,
              backgroundColor: theme.colorScheme.primary,
              elevation: 1,
              child: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
