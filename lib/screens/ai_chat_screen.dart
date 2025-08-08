// lib/screens/ai_chat_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _chatHistory = [];
  bool _isLoading = false;

  // IMPORTANT: Replace with your actual AIMLAPI.com API Key
  final String _apiKey = "5b5d43ebaeea4114b7b9ca613635d009";

  // **NEW**: Function to clean up the API response.
  String _cleanResponse(String response) {
    return response.replaceAll('\\n', '\n').replaceAll('\\"', '"');
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _chatHistory.add({"role": "user", "content": userMessage});
      _isLoading = true;
    });

    // Prepare the message history for the API request
    final messages = _chatHistory.map((msg) {
      return {"role": msg["role"], "content": msg["content"]};
    }).toList();


    try {
      final response = await http.post(
        Uri.parse('https://api.aimlapi.com/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          "model": "google/gemma-3-4b-it",
          "messages": messages,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        final rawResponse = result['choices'][0]['message']['content'];
        // **FIX**: Clean the response before adding it to the chat history.
        final modelResponse = _cleanResponse(rawResponse);
        setState(() {
          _chatHistory.add({"role": "assistant", "content": modelResponse});
        });
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['message'] ?? 'An unknown error occurred.';
        setState(() {
          _chatHistory.add({"role": "assistant", "content": "Sorry, an error occurred: $errorMessage"});
        });
      }
    } catch (e) {
      setState(() {
        _chatHistory.add({"role": "assistant", "content": "An error occurred: ${e.toString()}"});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text("AI Assistant", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              reverse: true,
              itemCount: _chatHistory.length,
              itemBuilder: (context, index) {
                final message = _chatHistory.reversed.toList()[index];
                final isUser = message['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isUser ? theme.colorScheme.primary : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Text(
                      message['content']!,
                      style: GoogleFonts.inter(
                        color: isUser ? Colors.white : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          _buildMessageInputField(theme),
        ],
      ),
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
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Ask the AI anything...',
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                ),
                onSubmitted: (text) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              onPressed: _sendMessage,
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
