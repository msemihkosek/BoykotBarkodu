import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../services/chat/chat_models.dart';
import '../../services/chat/chat_service.dart';

class ChatScreen extends StatefulWidget {
  /// Doluysa ekran açılır açılmaz bu soru otomatik sorulur (ör. sonuç kartından)
  final String? initialQuestion;

  const ChatScreen({super.key, this.initialQuestion});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isThinking = false;

  static const List<String> _suggestions = [
    'Ariel neden boykotta?',
    'Nescafe yerine ne alabilirim?',
    'Erikli boykot mu?',
    '729 barkod ne demek?',
  ];

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuestion;
    if (q != null && q.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(q));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _isThinking) return;

    final history = List<ChatMessage>.from(_messages);
    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, text: q));
      _isThinking = true;
      _controller.clear();
    });
    _scrollToEnd();

    final reply = await _chatService.ask(q, history);
    if (!mounted) return;
    setState(() {
      _messages.add(reply);
      _isThinking = false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Boykot Asistanı',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      itemCount: _messages.length + (_isThinking ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == _messages.length) return _buildTyping(isDark);
                        return _buildBubble(_messages[i], isDark);
                      },
                    ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Cevaplar Boykot Dedektifi ve Boykot.co kaynaklı verilerden gelir. Kaynağı kontrol edin.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.neutralGray),
              ),
            ),
            _buildInput(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.forum_rounded, color: AppColors.primaryLight, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'Boykot hakkında sorun',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bir markanın boykot durumunu, gerekçesini ve yerli alternatiflerini sorabilirsiniz. '
            'Boykot dışındaki konulara cevap vermem.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.neutralGray),
          ),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: _suggestions
                .map((s) => ActionChip(
                      label: Text(s),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
                      labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      onPressed: () => _send(s),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage m, bool isDark) {
    final isUser = m.isUser;
    final bg = isUser
        ? AppColors.primary
        : m.isNotice
            ? AppColors.warnAmber.withValues(alpha: 0.12)
            : (isDark ? AppColors.surfaceDark : Colors.white);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: m.isNotice
                      ? AppColors.warnAmberBorder
                      : (isDark ? const Color(0xFF334155) : AppColors.borderLight),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              m.text,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isUser ? Colors.white : null,
              ),
            ),
            if (m.sources.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: m.sources
                    .map((s) => ActionChip(
                          avatar: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: Text(s.label),
                          visualDensity: VisualDensity.compact,
                          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          onPressed: () => _open(s.url),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTyping(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
        ),
      ),
    );
  }

  Widget _buildInput(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : AppColors.borderLight,
                ),
              ),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Örn: Lipton neden boykotta?',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _isThinking ? null : () => _send(_controller.text),
            icon: const Icon(Icons.send_rounded),
            style: IconButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
