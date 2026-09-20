import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/tv_focusable.dart';

/// Messenger-style conversation with the admin.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ChatScreen(),
    ));
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  int _lastCount = -1;

  @override
  void initState() {
    super.initState();
    // Messages arrive live over the cloud stream; just mark them read.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppScope.read(context).openChatRefresh();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    HapticFeedback.selectionClick();
    final ok = await AppScope.read(context).sendChat(text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _input.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not send — check your internet connection.')));
    }
  }

  Future<void> _confirmClear() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Ybox.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Ybox.radius)),
        title: const Text('Delete conversation?',
            style: TextStyle(color: Ybox.textHigh)),
        content: Text(
          'This clears the conversation on your device. You can keep '
          'chatting with the admin afterwards.',
          style: TextStyle(color: Ybox.textDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep', style: TextStyle(color: Ybox.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Ybox.danger)),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      final ok = await AppScope.read(context).clearChat();
      if (mounted && !ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not delete — try again when connected.')));
      }
    }
  }

  String _fmtTime(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    final sameDay =
        d.year == now.year && d.month == now.month && d.day == now.day;
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    if (sameDay) return '$hh:$mm';
    return '${d.day}/${d.month} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final messages = state.chat.messages;

    // Auto-scroll when new messages arrive.
    if (messages.length != _lastCount) {
      _lastCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      appBar: AppBar(
        titleTextStyle: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, color: Ybox.textHigh),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Ybox.accent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent_rounded,
                  color: Ybox.accent, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Admin'),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: state.adminSync.connected ? Ybox.accent : Ybox.textDim,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            color: Ybox.card,
            icon: const Icon(Icons.more_vert_rounded, color: Ybox.textHigh),
            onSelected: (v) {
              if (v == 'clear') _confirmClear();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Text('Delete conversation',
                    style: TextStyle(color: Ybox.danger)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Say hello',
                    message:
                        'Messages you send here go straight to your admin. '
                        'Ask about your subscription or report a problem.',
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (context, i) =>
                        _Bubble(message: messages[i], fmtTime: _fmtTime),
                  ),
          ),
          // Input bar in the thumb zone
          Container(
            color: Ybox.surface,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Message the admin…',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TvFocusable(
                    borderRadius: BorderRadius.circular(999),
                    onTap: _send,
                    child: GestureDetector(
                      onTap: _send,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _sending ? Ybox.card : Ybox.accent,
                          shape: BoxShape.circle,
                          boxShadow: _sending ? null : Ybox.glow(0.3),
                        ),
                        child: _sending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Ybox.accent),
                              )
                            : const Icon(Icons.send_rounded,
                                color: Colors.black, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final String Function(int) fmtTime;

  const _Bubble({required this.message, required this.fmtTime});

  @override
  Widget build(BuildContext context) {
    final fromAdmin = message.fromAdmin;
    return Align(
      alignment: fromAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: fromAdmin ? Ybox.card : Ybox.accent,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(fromAdmin ? 4 : 18),
            bottomRight: Radius.circular(fromAdmin ? 18 : 4),
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
                height: 1.3,
                color: fromAdmin ? Ybox.textHigh : Colors.black,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              fmtTime(message.ts),
              style: TextStyle(
                fontSize: 10,
                color:
                    fromAdmin ? Ybox.textDim : Colors.black.withOpacity(0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
