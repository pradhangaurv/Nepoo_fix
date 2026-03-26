import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/chat_service.dart';

class ChatPage extends StatefulWidget {
  final String requestId;
  final String customerId;
  final String providerId;
  final String currentUserId;
  final String currentUserRole;
  final String otherUserName;
  final String otherUserPhone;
  final String requestStatus;

  const ChatPage({
    super.key,
    required this.requestId,
    required this.customerId,
    required this.providerId,
    required this.currentUserId,
    required this.currentUserRole,
    required this.otherUserName,
    required this.otherUserPhone,
    required this.requestStatus,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messageSubscription;

  bool _sending = false;
  bool _initializing = true;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      await _chatService.ensureChatExists(
        requestId: widget.requestId,
        customerId: widget.customerId,
        providerId: widget.providerId,
      );

      await _chatService.markMessagesAsRead(
        requestId: widget.requestId,
        currentUserId: widget.currentUserId,
      );

      _messageSubscription = _chatService
          .streamMessages(requestId: widget.requestId)
          .listen((_) async {
        await _chatService.markMessagesAsRead(
          requestId: widget.requestId,
          currentUserId: widget.currentUserId,
        );
      });

      if (!mounted) return;

      setState(() {
        _initializing = false;
        _initError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _initializing = false;
        _initError = 'Failed to open chat: $e';
      });
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _canSend => _chatService.canChatForStatus(widget.requestStatus);

  String _formatTime(dynamic value) {
    if (value is! Timestamp) return '';
    final dt = value.toDate();
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> _sendMessage() async {
    if (!_canSend || _sending) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      setState(() => _sending = true);

      await _chatService.sendMessage(
        requestId: widget.requestId,
        customerId: widget.customerId,
        providerId: widget.providerId,
        senderId: widget.currentUserId,
        senderRole: widget.currentUserRole,
        text: text,
      );

      _messageController.clear();

      if (!mounted) return;

      setState(() => _sending = false);

      Future.delayed(const Duration(milliseconds: 150), () {
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _sending = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  void _showPhoneDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            widget.otherUserName.isEmpty ? 'Phone Number' : widget.otherUserName,
          ),
          content: Text(
            widget.otherUserPhone.isEmpty
                ? 'Phone number not available'
                : widget.otherUserPhone,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> data) {
    final senderId = data['senderId']?.toString() ?? '';
    final text = data['text']?.toString() ?? '';
    final createdAt = data['createdAt'];
    final isMine = senderId == widget.currentUserId;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMine ? Colors.blue : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isMine ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(createdAt),
              style: TextStyle(
                fontSize: 11,
                color: isMine ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    if (!_canSend) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.10),
          border: Border(
            top: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: const Text(
          'Chat is available only during accepted and active service stages.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _sending ? null : _sendMessage,
              child: _sending
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
    widget.otherUserName.isEmpty ? 'Chat' : widget.otherUserName;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: _showPhoneDialog,
            icon: const Icon(Icons.call),
            tooltip: 'Show phone number',
          ),
        ],
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _initError != null
          ? Center(child: Text(_initError!))
          : Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _chatService.streamMessages(
                requestId: widget.requestId,
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snap.hasError) {
                  return Center(
                    child: Text('Error: ${snap.error}'),
                  );
                }

                final docs = snap.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!_scrollController.hasClients) return;
                  _scrollController.jumpTo(
                    _scrollController.position.maxScrollExtent,
                  );
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(docs[index].data());
                  },
                );
              },
            ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }
}