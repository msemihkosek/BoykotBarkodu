class ChatSource {
  final String label;
  final String url;

  const ChatSource({required this.label, required this.url});
}

enum ChatRole { user, assistant }

class ChatMessage {
  final ChatRole role;
  final String text;
  final List<ChatSource> sources;
  final DateTime createdAt;

  /// Konu dışı soru reddi veya "bulunamadı" gibi bilgi içermeyen cevaplar için true
  final bool isNotice;

  ChatMessage({
    required this.role,
    required this.text,
    this.sources = const [],
    this.isNotice = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isUser => role == ChatRole.user;
}
