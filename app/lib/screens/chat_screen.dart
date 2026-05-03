import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../models/saved_location.dart';
import '../services/backend_api.dart';
import '../state/app_state.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_plot_view.dart';

/// Conversational interface to the historical weather archive.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = <ChatMessage>[];
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final auth = context.read<AuthState>();
    if (!auth.isSignedIn) {
      setState(() => _error = 'Sign in (top-right of home) to use chat.');
      return;
    }
    final app = context.read<AppState>();
    final SavedLocation? defaultLoc =
        app.locations.isEmpty ? null : app.effectiveLocation;

    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, content: text));
      _controller.clear();
      _sending = true;
      _error = null;
    });
    _scrollToEnd();

    try {
      // Send everything *except* the just-added user turn — server appends it itself.
      final history = _messages.sublist(0, _messages.length - 1);
      final reply = await BackendApi(auth).postChat(
        message: text,
        history: history,
        location: defaultLoc,
      );
      setState(() {
        _messages.add(ChatMessage(
          role: ChatRole.assistant,
          content: reply.reply,
          plots: reply.plots,
          toolCalls: reply.toolCalls,
        ));
      });
    } catch (e) {
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToEnd();
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask the archive'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? const _EmptyChat()
                  : ListView.separated(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: _messages.length + (_sending ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        if (i >= _messages.length) {
                          return const _Thinking();
                        }
                        return _MessageBubble(message: _messages[i]);
                      },
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            _Composer(
              controller: _controller,
              onSend: _send,
              sending: _sending,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = WeatherTokens.of(context);
    final isUser = message.role == ChatRole.user;
    final bubbleColor = isUser ? tokens.pillSurfaceHigh : tokens.pillSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.content.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isUser ? 20 : 6),
                    bottomRight: Radius.circular(isUser ? 6 : 20),
                  ),
                ),
                child: Text.rich(
                  _renderInlineMarkdown(message.content, theme.textTheme.bodyLarge),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            for (final plot in message.plots) ...[
              const SizedBox(height: 8),
              ChatPlotView(plot: plot),
            ],
            if (!isUser && message.toolCalls.isNotEmpty) ...[
              const SizedBox(height: 6),
              _ToolTrace(calls: message.toolCalls),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolTrace extends StatelessWidget {
  const _ToolTrace({required this.calls});

  final List<ChatToolCall> calls;

  @override
  Widget build(BuildContext context) {
    final tokens = WeatherTokens.of(context);
    final theme = Theme.of(context);
    final labels = <String>{};
    for (final c in calls) {
      labels.add(c.ok ? _friendlyToolLabel(c.name) : '${_friendlyToolLabel(c.name)} (failed)');
    }
    if (labels.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.travel_explore_rounded, size: 14, color: tokens.mutedText),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Looked up: ${labels.join(', ')}',
              style: theme.textTheme.labelSmall?.copyWith(color: tokens.mutedText),
            ),
          ),
        ],
      ),
    );
  }
}

String _friendlyToolLabel(String name) {
  switch (name) {
    case 'aggregate':
    case 'get_daily':
      return 'weather archive';
    case 'plot':
      return 'chart';
    default:
      return name;
  }
}

/// Render `**bold**` and `*italic*` markdown spans inline.
/// Kept minimal: chat replies are capped at ≤4 sentences server-side.
TextSpan _renderInlineMarkdown(String text, TextStyle? base) {
  final spans = <TextSpan>[];
  // Match **bold** (greedy non-empty) or *italic* (single asterisk, non-empty, no asterisks inside).
  final pattern = RegExp(r'\*\*(.+?)\*\*|\*([^*\n]+?)\*');
  var cursor = 0;
  for (final m in pattern.allMatches(text)) {
    if (m.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, m.start)));
    }
    if (m.group(1) != null) {
      spans.add(TextSpan(
        text: m.group(1),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ));
    } else if (m.group(2) != null) {
      spans.add(TextSpan(
        text: m.group(2),
        style: const TextStyle(fontStyle: FontStyle.italic),
      ));
    }
    cursor = m.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor)));
  }
  return TextSpan(style: base, children: spans);
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    final tokens = WeatherTokens.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: tokens.pillSurface,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text('Thinking…', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.sending,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final tokens = WeatherTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Material(
        color: tokens.pillSurface,
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !sending,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    hintText: 'Ask about historical weather…',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              _SendButton(onSend: onSend, sending: sending),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onSend, required this.sending});

  final VoidCallback onSend;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final tokens = WeatherTokens.of(context);
    final enabled = !sending;
    final bg = enabled ? tokens.accent : tokens.pillSurfaceHigh;
    final fg = enabled ? const Color(0xFF1B1300) : tokens.mutedText;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Material(
        color: bg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        child: InkWell(
          onTap: enabled ? onSend : null,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: sending
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg,
                      ),
                    )
                  : Icon(Icons.arrow_upward_rounded, size: 20, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = WeatherTokens.of(context);
    final examples = [
      'How hot was July in Lisbon, on average over the last 30 years?',
      'Top 5 wettest days in London in the last 10 years.',
      'Was 10 February colder than usual here over the last decade?',
      'Plot daily max temperature for the last 30 days.',
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      children: [
        Icon(
          Icons.auto_awesome_rounded,
          size: 56,
          color: theme.colorScheme.onSurface,
        ),
        const SizedBox(height: 16),
        Text(
          'Ask the archive',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Multi-year stats, top-N rankings, and charts — your saved location is the default.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: tokens.mutedText),
        ),
        const SizedBox(height: 24),
        for (final e in examples) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: tokens.pillSurface,
              borderRadius: const BorderRadius.all(Radius.circular(18)),
            ),
            child: Text(e, style: theme.textTheme.bodyMedium),
          ),
        ],
      ],
    );
  }
}
