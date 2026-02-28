class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final double? flexFundAmount;
  final bool isSystem;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.flexFundAmount,
    this.isSystem = false,
  });
}
