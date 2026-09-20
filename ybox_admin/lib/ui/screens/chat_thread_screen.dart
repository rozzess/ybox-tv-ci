import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../services/admin_state.dart';
import '../../theme.dart';

/// Messenger-style thread between the admin and one user — realtime via a
/// Firestore snapshot stream (SPEC 6.3). The admin always sees the full
/// history, regardless of the user clearing their side.
class ChatThreadScreen extends StatefulWidget {
  final String uid;
  final String username;

  const ChatThreadScreen({
    super.key,
    required this.uid,
    required this.username,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  StreamSubscription<List<ChatMessage>>? _sub;
  List<ChatMessage> _messages = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    AdminState.instance.markThreadRead(widget.uid);
    _sub = AdminState.instance
        .threadStream(widget.uid, widget.username)
        .listen((messages) {
      if (!mounted) return;
      final grew = messages.length > _messages.length;
      setState(() => _messages = messages);
      if (grew) {
        AdminState.instance.markThreadRead(widget.uid);
        _jumpToEnd();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    HapticFeedback.lightImpact();
    _input.clear();
    await AdminState.instance
        .sendAdminMessage(widget.uid, widget.username, text);
    if (mounted) setState(() => _sending = false);
    _jumpToEnd();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleTextStyle: YText.section,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: YColors.accentSoft(0.2),
              child: Text(
                widget.username.isEmpty
                    ? '?'
                    : widget.username[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  color: YColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: YSpace.s),
            Text(widget.username),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        'No messages yet — say hi!',
                        style: YText.caption,
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(YSpace.m),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) =>
                          _Bubble(message: _messages[index]),
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                  YSpace.m, YSpace.s, YSpace.m, YSpace.m),
              decoration: BoxDecoration(
                color: YColors.surface,
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.06)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      style: TextStyle(color: YColors.text(0.9)),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Message…',
                      ),
                    ),
                  ),
                  const SizedBox(width: YSpace.s),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: YColors.accent,
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;

  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final fromAdmin = message.fromAdmin;
    return Align(
      alignment: fromAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: YSpace.s),
        padding: const EdgeInsets.symmetric(
            horizontal: YSpace.m, vertical: YSpace.s + 2),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: fromAdmin ? YColors.accent : YColors.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fromAdmin ? 16 : 4),
            bottomRight: Radius.circular(fromAdmin ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 15,
                color: fromAdmin ? Colors.white : YColors.text(0.9),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message.timeLabel,
              style: TextStyle(
                fontSize: 10,
                color: fromAdmin
                    ? Colors.white.withOpacity(0.7)
                    : YColors.text(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
