import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/admin_state.dart';
import '../../theme.dart';
import '../widgets/entrance.dart';
import '../widgets/pressable_tile.dart';
import '../widgets/ybox_widgets.dart';
import 'chat_thread_screen.dart';

/// Admin Chat tab (SPEC 6.3): realtime conversation list across all users,
/// with a search field matching message text or usernames fleet-wide.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  List<ChatMessage> _results = [];
  bool _searching = false;
  bool _searchBusy = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final query = _search.text.trim();
      if (query.isEmpty) {
        if (mounted) {
          setState(() {
            _searching = false;
            _results = [];
          });
        }
        return;
      }
      setState(() {
        _searching = true;
        _searchBusy = true;
      });
      final results = await AdminState.instance.searchMessages(query);
      if (mounted && _search.text.trim() == query) {
        setState(() {
          _results = results;
          _searchBusy = false;
        });
      }
    });
  }

  void _openThread(String uid, String username) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatThreadScreen(uid: uid, username: username),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding:
                EdgeInsets.fromLTRB(YSpace.l, YSpace.l, YSpace.l, YSpace.m),
            child: Row(
              children: [
                Expanded(child: Text('Chat', style: YText.title)),
                LiveIndicator(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: YSpace.l),
            child: TextField(
              controller: _search,
              style: TextStyle(color: YColors.text(0.9)),
              decoration: InputDecoration(
                hintText: 'Search all messages or users…',
                prefixIcon: Icon(Icons.search, color: YColors.text(0.4)),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close, color: YColors.text(0.4)),
                        onPressed: () => _search.clear(),
                      ),
              ),
            ),
          ),
          const SizedBox(height: YSpace.m),
          Expanded(
            child: _searching ? _buildResults() : _buildConversations(),
          ),
        ],
      ),
    );
  }

  Widget _buildConversations() {
    return AnimatedBuilder(
      animation: AdminState.instance,
      builder: (context, _) {
        final conversations = AdminState.instance.conversations;
        if (conversations.isEmpty) {
          return const EmptyState(
            icon: Icons.chat_bubble_outline,
            title: 'No conversations yet',
            message: 'When users message you from their YBOX TV app, their '
                'threads appear here instantly.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(YSpace.l, 0, YSpace.l, YSpace.xl),
          itemCount: conversations.length,
          separatorBuilder: (_, __) => const SizedBox(height: YSpace.m),
          itemBuilder: (context, index) {
            final convo = conversations[index];
            return Entrance(
              index: index,
              child: PressableTile(
                onTap: () => _openThread(convo.uid, convo.username),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: YColors.accentSoft(0.2),
                      child: Text(
                        convo.username.isEmpty
                            ? '?'
                            : convo.username[0].toUpperCase(),
                        style: const TextStyle(
                          color: YColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: YSpace.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            convo.username,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: YColors.text(0.95),
                            ),
                          ),
                          const SizedBox(height: YSpace.xs),
                          Text(
                            '${convo.lastFromAdmin ? 'You: ' : ''}'
                            '${convo.lastMessage}',
                            style: YText.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: YSpace.s),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(convo.timeLabel, style: YText.caption),
                        const SizedBox(height: YSpace.xs),
                        if (convo.unreadByAdmin > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: YColors.accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${convo.unreadByAdmin}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildResults() {
    if (_searchBusy) {
      return const Center(
        child: CircularProgressIndicator(color: YColors.accent),
      );
    }
    if (_results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'No matches',
        message: 'No messages match that search.',
      );
    }
    // Map usernames back to uids for opening threads from results.
    final uidByUsername = {
      for (final c in AdminState.instance.conversations) c.username: c.uid,
    };
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(YSpace.l, 0, YSpace.l, YSpace.xl),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: YSpace.s),
      itemBuilder: (context, index) {
        final msg = _results[index];
        return PressableTile(
          onTap: () {
            final uid = uidByUsername[msg.username];
            if (uid != null) _openThread(uid, msg.username);
          },
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                msg.fromAdmin ? Icons.support_agent : Icons.person,
                size: 18,
                color: YColors.text(0.4),
              ),
              const SizedBox(width: YSpace.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg.fromAdmin ? 'You → ${msg.username}' : msg.username,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: YColors.accent.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      msg.text,
                      style: YText.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: YSpace.s),
              Text(msg.timeLabel, style: YText.caption),
            ],
          ),
        );
      },
    );
  }
}
