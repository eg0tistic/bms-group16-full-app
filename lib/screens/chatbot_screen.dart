import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/chatbot_service.dart';
import '../utils/app_strings.dart';
import '../utils/logger.dart';
import '../widgets/app_drawer.dart';

// ── Message model ─────────────────────────────────────────────────────────────

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _thinking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isArabic = context.read<AppState>().isArabic;
      setState(() {
        _messages.add(
          _ChatMessage(
            text: ChatbotService.welcomeMessage(isArabic),
            isUser: false,
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _thinking) return;

    // Capture context-dependent values before any await
    final state = context.read<AppState>();
    final isAdmin = state.isAdmin;
    final isArabic = state.isArabic;

    _inputCtrl.clear();
    setState(() {
      _messages.add(_ChatMessage(text: trimmed, isUser: true));
      _thinking = true;
    });
    _scrollToBottom();

    String reply;
    try {
      reply = await ChatbotService.getReply(
        message: trimmed,
        isAdmin: isAdmin,
        isArabic: isArabic,
      );
    } catch (e, st) {
      logError('chatbot reply', e, st);
      reply = AppStrings.get('operation_failed', isArabic ? 'ar' : 'en');
    }

    if (!mounted) return;
    setState(() {
      _thinking = false;
      _messages.add(_ChatMessage(text: reply, isUser: false));
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.language;
    final isArabic = state.isArabic;
    String s(String k) => AppStrings.get(k, lang);
    final cs = Theme.of(context).colorScheme;

    final chips = isArabic
        ? const [
            'دخل اليوم',
            'الفواتير غير المدفوعة',
            'أكثر المنتجات',
            'أكثر العملاء مديونية',
            'كيف أعمل فاتورة؟',
          ]
        : const [
            'Today revenue',
            'Unpaid invoices',
            'Top products',
            'Top customers',
            'How to create invoice?',
          ];

    return Scaffold(
      appBar: AppBar(
        title: Text(s('chatbot_title')),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.rule_outlined, size: 12, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  s('chatbot_rule_based'),
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Message list
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _messages.length + (_thinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _ThinkingBubble(cs: cs);
                }
                final msg = _messages[index];
                return msg.isUser
                    ? _UserBubble(text: msg.text, cs: cs)
                    : _BotBubble(text: msg.text, cs: cs);
              },
            ),
          ),

          // Suggestion chips
          Container(
            color: cs.surfaceContainerLow,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s('suggested_questions'),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: cs.outline),
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: chips
                        .map(
                          (chip) => Padding(
                            padding: const EdgeInsetsDirectional.only(end: 6),
                            child: ActionChip(
                              label: Text(
                                chip,
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: _thinking
                                  ? null
                                  : () => _sendMessage(chip),
                              backgroundColor: cs.secondaryContainer.withValues(
                                alpha: 0.7,
                              ),
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 0,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),

          // Input bar
          Container(
            color: cs.surface,
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 12),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                      enabled: !_thinking,
                      decoration: InputDecoration(
                        hintText: s('chatbot_hint'),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    onPressed: _thinking
                        ? null
                        : () => _sendMessage(_inputCtrl.text),
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(14),
                    ),
                    child: const Icon(Icons.send_rounded, size: 20),
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

// ── Bubble widgets ────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final String text;
  final ColorScheme cs;

  const _UserBubble({required this.text, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsetsDirectional.only(
          start: 64,
          end: 16,
          top: 4,
          bottom: 4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(16),
            topEnd: Radius.circular(4),
            bottomStart: Radius.circular(16),
            bottomEnd: Radius.circular(16),
          ),
        ),
        child: Text(text, style: TextStyle(color: cs.onPrimary, height: 1.4)),
      ),
    );
  }
}

class _BotBubble extends StatelessWidget {
  final String text;
  final ColorScheme cs;

  const _BotBubble({required this.text, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, top: 4),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: cs.primaryContainer,
              child: Icon(
                Icons.smart_toy_outlined,
                size: 16,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          Flexible(
            child: Container(
              margin: const EdgeInsetsDirectional.only(
                start: 6,
                end: 64,
                top: 4,
                bottom: 4,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(4),
                  topEnd: Radius.circular(16),
                  bottomStart: Radius.circular(16),
                  bottomEnd: Radius.circular(16),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(color: cs.onSurface, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  final ColorScheme cs;

  const _ThinkingBubble({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, top: 4),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: cs.primaryContainer,
              child: Icon(
                Icons.smart_toy_outlined,
                size: 16,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsetsDirectional.only(
              start: 6,
              top: 4,
              bottom: 4,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: const BorderRadiusDirectional.only(
                topStart: Radius.circular(4),
                topEnd: Radius.circular(16),
                bottomStart: Radius.circular(16),
                bottomEnd: Radius.circular(16),
              ),
            ),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
