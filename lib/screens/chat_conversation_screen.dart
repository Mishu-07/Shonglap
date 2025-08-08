// lib/screens/chat_conversation_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:first_app/models/chat_message_model.dart';
import 'package:first_app/models/user_model.dart';
import 'package:first_app/screens/conversation_details_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:uuid/uuid.dart';

class ChatConversationScreen extends StatefulWidget {
  final UserModel otherUser;
  const ChatConversationScreen({super.key, required this.otherUser});

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final _messageController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _cloudinary = CloudinaryPublic('dwqu7l0jk', 'shonglap_unsigned', cache: false);

  late String _chatRoomId;
  late User _currentUser;
  bool _isUploading = false;
  bool _isBlockedByMe = false;
  bool _isBlockedByOther = false;
  StreamSubscription? _blockStatusSubscription;

  // For grammar check feature
  Timer? _debounce;
  String? _correctedText;
  bool _isCheckingGrammar = false;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser!;
    _chatRoomId = _getChatRoomId(_currentUser.uid, widget.otherUser.uid);
    _listenToBlockStatus();
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _blockStatusSubscription?.cancel();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      if (_messageController.text.trim().length > 3) { // Only check sentences with more than 3 chars
        _checkGrammar(_messageController.text.trim());
      } else {
        setState(() {
          _correctedText = null;
        });
      }
    });
  }

  Future<void> _checkGrammar(String text) async {
    setState(() {
      _isCheckingGrammar = true;
      _correctedText = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://api.languagetool.org/v2/check'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'text': text,
          'language': 'en-US',
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final List<dynamic> matches = result['matches'];

        if (matches.isNotEmpty) {
          String correctedSentence = text;
          // **FIX**: Iterate over matches in reverse to apply all corrections
          // without messing up the character indices of subsequent errors.
          for (var match in matches.reversed) {
            if (match['replacements'] != null && (match['replacements'] as List).isNotEmpty) {
              final offset = match['offset'];
              final length = match['length'];
              final replacement = match['replacements'][0]['value'];
              correctedSentence = correctedSentence.replaceRange(offset, offset + length, replacement);
            }
          }

          if (correctedSentence != text) {
            setState(() {
              _correctedText = correctedSentence;
            });
          }
        }
      }
    } catch (e) {
      // Fail silently
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingGrammar = false;
        });
      }
    }
  }


  void _listenToBlockStatus() {
    _firestore.collection('users').doc(_currentUser.uid).snapshots().listen((doc) {
      if (!mounted) return;
      final List<dynamic> blockedList = doc.data()?['blockedUsers'] ?? [];
      setState(() {
        _isBlockedByMe = blockedList.contains(widget.otherUser.uid);
      });
    });

    _firestore.collection('users').doc(widget.otherUser.uid).snapshots().listen((doc) {
      if (!mounted) return;
      final List<dynamic> blockedList = doc.data()?['blockedUsers'] ?? [];
      setState(() {
        _isBlockedByOther = blockedList.contains(_currentUser.uid);
      });
    });
  }

  String _getChatRoomId(String userId1, String userId2) {
    return userId1.compareTo(userId2) > 0 ? '$userId1\_$userId2' : '$userId2\_$userId1';
  }

  Future<void> _sendMessage({String? text, String? mediaUrl, MessageType type = MessageType.text}) async {
    if (_isBlockedByMe || _isBlockedByOther) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot send messages. This user is blocked.')));
      return;
    }
    if ((text == null || text.trim().isEmpty) && mediaUrl == null) return;
    _messageController.clear();
    setState(() {
      _correctedText = null;
    });

    final messageId = const Uuid().v4();
    final message = ChatMessageModel(
      id: messageId,
      senderId: _currentUser.uid,
      text: text,
      timestamp: Timestamp.now(),
      type: type,
      mediaUrl: mediaUrl,
      status: 'sent',
    );

    final chatRoomRef = _firestore.collection('chats').doc(_chatRoomId);

    await chatRoomRef.set({
      'participants': [_currentUser.uid, widget.otherUser.uid],
      'lastMessage': type == MessageType.text ? text : 'Sent a file',
      'lastMessageTimestamp': message.timestamp,
    }, SetOptions(merge: true));

    await chatRoomRef.collection('messages').doc(messageId).set(message.toJson());
  }

  Future<void> _deleteMessage(ChatMessageModel message) async {
    final docRef = _firestore.collection('chats').doc(_chatRoomId).collection('messages').doc(message.id);
    await docRef.update({'type': 'deleted', 'text': null, 'mediaUrl': null});
  }

  Future<void> _deleteMessageForMe(ChatMessageModel message) async {
    final docRef = _firestore.collection('chats').doc(_chatRoomId).collection('messages').doc(message.id);
    await docRef.update({
      'deletedFor': FieldValue.arrayUnion([_currentUser.uid])
    });
  }

  Future<void> _pickAndUploadMedia({required bool isVideo}) async {
    final picker = ImagePicker();
    final XFile? pickedFile = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile == null) return;
    if (mounted) setState(() => _isUploading = true);

    try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(pickedFile.path, resourceType: isVideo ? CloudinaryResourceType.Video : CloudinaryResourceType.Image),
      );
      await _sendMessage(mediaUrl: response.secureUrl, type: isVideo ? MessageType.video : MessageType.image);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _markMessagesAsSeen(List<ChatMessageModel> messages) {
    final batch = _firestore.batch();
    for (var msg in messages) {
      if (msg.senderId == widget.otherUser.uid && msg.status != 'seen') {
        final docRef = _firestore.collection('chats').doc(_chatRoomId).collection('messages').doc(msg.id);
        batch.update(docRef, {'status': 'seen', 'seenAt': Timestamp.now()});
      }
    }
    batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: _buildAppBar(theme),
      body: Column(
        children: [
          if (_isUploading) const LinearProgressIndicator(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(_chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(theme);
                }

                final messages = snapshot.data!.docs
                    .map((doc) => ChatMessageModel.fromFirestore(doc))
                    .where((msg) => !msg.deletedFor.contains(_currentUser.uid))
                    .toList();

                if (messages.isEmpty) {
                  return _buildEmptyState(theme);
                }

                _markMessagesAsSeen(messages);

                return GroupedListView<ChatMessageModel, DateTime>(
                  padding: const EdgeInsets.all(8),
                  reverse: true,
                  order: GroupedListOrder.ASC,
                  elements: messages,
                  groupBy: (message) => DateTime(message.timestamp.toDate().year, message.timestamp.toDate().month, message.timestamp.toDate().day),
                  groupComparator: (date1, date2) => date2.compareTo(date1),
                  groupHeaderBuilder: (message) => _buildDateSeparator(message.timestamp.toDate(), theme),
                  itemBuilder: (context, message) => _buildMessageBubble(message, theme),
                );
              },
            ),
          ),
          if (_isBlockedByOther) _buildBlockedBanner('You have been blocked by this user.')
          else if (_isBlockedByMe) _buildBlockedBanner('You have blocked this user.')
          else _buildMessageInputField(theme),
        ],
      ),
    );
  }

  AppBar _buildAppBar(ThemeData theme) {
    return AppBar(
      elevation: 1,
      backgroundColor: theme.scaffoldBackgroundColor,
      title: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ConversationDetailsScreen(otherUser: widget.otherUser)),
          );
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: widget.otherUser.profilePicUrl != null && widget.otherUser.profilePicUrl!.isNotEmpty
                  ? NetworkImage(widget.otherUser.profilePicUrl!)
                  : null,
              child: widget.otherUser.profilePicUrl == null || widget.otherUser.profilePicUrl!.isEmpty
                  ? const Icon(Icons.person)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(widget.otherUser.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message, ThemeData theme) {
    final isMyMessage = message.senderId == _currentUser.uid;
    return GestureDetector(
      onLongPress: () => _showActionMenu(message, theme),
      child: Align(
        alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          margin: const EdgeInsets.symmetric(vertical: 4),
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
                color: message.type == MessageType.deleted
                    ? theme.colorScheme.surface
                    : isMyMessage
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildMessageContent(message, isMyMessage, theme),
                ),
              ),
              if (message.type != MessageType.deleted)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(DateFormat.jm().format(message.timestamp.toDate()), style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                      if (isMyMessage) ...[const SizedBox(width: 4), _buildStatusIcon(message)],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRichText(String text, TextStyle style) {
    List<TextSpan> spans = [];
    final RegExp boldPattern = RegExp(r'\*\*(.*?)\*\*');

    text.splitMapJoin(
      boldPattern,
      onMatch: (Match match) {
        spans.add(TextSpan(
          text: match.group(1),
          style: style.copyWith(fontWeight: FontWeight.bold),
        ));
        return '';
      },
      onNonMatch: (String nonMatch) {
        spans.add(TextSpan(text: nonMatch, style: style));
        return '';
      },
    );

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildMessageContent(ChatMessageModel message, bool isMyMessage, ThemeData theme) {
    final onPrimaryColor = theme.colorScheme.onPrimary;
    final onSurfaceColor = theme.colorScheme.onSurface;

    switch (message.type) {
      case MessageType.deleted:
        return Text(
          "Message unsent",
          style: GoogleFonts.inter(fontStyle: FontStyle.italic, color: onSurfaceColor.withOpacity(0.7)),
        );
      case MessageType.text:
        final style = GoogleFonts.inter(color: isMyMessage ? onPrimaryColor : onSurfaceColor, fontSize: 16);
        return _buildRichText(message.text!, style);
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
          child: Center(child: Icon(CupertinoIcons.play_circle_fill, color: onPrimaryColor, size: 40)),
        );
    }
  }

  void _showActionMenu(ChatMessageModel message, ThemeData theme) {
    final isMyMessage = message.senderId == _currentUser.uid;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              if (message.type == MessageType.text)
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Copy Text'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.text!));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                  },
                ),
              if (!isMyMessage && message.type != MessageType.deleted)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete for Me', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessageForMe(message);
                  },
                ),
              if (isMyMessage && message.type != MessageType.deleted)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Unsend Message', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(message);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageInputField(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [BoxShadow(offset: const Offset(0, -2), blurRadius: 10, color: Colors.black.withOpacity(0.05))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grammar suggestion widget.
            if (_correctedText != null)
              GestureDetector(
                onTap: () {
                  _messageController.text = _correctedText!;
                  _messageController.selection = TextSelection.fromPosition(TextPosition(offset: _messageController.text.length));
                  setState(() {
                    _correctedText = null;
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                  child: Text(
                    _correctedText!,
                    style: GoogleFonts.inter(
                      color: Colors.green,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.green,
                    ),
                  ),
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: Icon(CupertinoIcons.paperclip, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                  onPressed: () => _pickAndUploadMedia(isVideo: false),
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
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade700,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(color: Colors.white, fontStyle: FontStyle.italic),
      ),
    );
  }

  Icon _buildStatusIcon(ChatMessageModel message) {
    switch (message.status) {
      case 'seen':
        return const Icon(Icons.done_all, size: 16, color: Colors.blueAccent);
      case 'delivered':
        return const Icon(Icons.done_all, size: 16, color: Colors.grey);
      default:
        return const Icon(Icons.done, size: 16, color: Colors.grey);
    }
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

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.chat_bubble_2, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text('No messages yet!', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Send a message to start the conversation.', style: GoogleFonts.inter(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
