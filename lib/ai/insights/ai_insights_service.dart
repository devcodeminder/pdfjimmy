enum DocCategory {
  invoice,
  receipt,
  businessCard,
  idCard,
  note,
  utilityBill,
  unknown,
}

enum EntityType { email, phone, url, date, amount }

class AiEntity {
  final EntityType type;
  final String value;

  AiEntity(this.type, this.value);
}

class AiInsightsService {
  // Singleton
  static final AiInsightsService _instance = AiInsightsService._internal();
  factory AiInsightsService() => _instance;
  AiInsightsService._internal();

  /// Classifies the document based on text content
  DocCategory classifyDocument(String text) {
    if (text.isEmpty) return DocCategory.unknown;
    final lower = text.toLowerCase();

    if (lower.contains('invoice') ||
        lower.contains('bill to') ||
        lower.contains('tax invoice')) {
      return DocCategory.invoice;
    }
    if (lower.contains('receipt') ||
        lower.contains('total') && lower.contains('cash')) {
      return DocCategory.receipt;
    }
    if ((lower.contains('phone') || lower.contains('tel')) &&
        lower.contains('@') &&
        text.length < 300) {
      return DocCategory.businessCard;
    }
    if (lower.contains('identity') ||
        lower.contains('licence') ||
        lower.contains('passport')) {
      return DocCategory.idCard;
    }
    if (lower.contains('utility') ||
        lower.contains('electricity') ||
        lower.contains('water bill')) {
      return DocCategory.utilityBill;
    }

    return DocCategory.note;
  }

  /// Extracts actionable entities from text
  List<AiEntity> extractEntities(String text) {
    List<AiEntity> entities = [];

    // Email Regex
    final emailRegex = RegExp(r'\b[\w\.-]+@[\w\.-]+\.\w{2,4}\b');
    entities.addAll(
      emailRegex
          .allMatches(text)
          .map((m) => AiEntity(EntityType.email, m.group(0)!)),
    );

    // Phone Regex (Simple)
    final phoneRegex = RegExp(
      r'\b(?:\+?\d{1,3}[- ]?)?\(?\d{3}\)?[- ]?\d{3}[- ]?\d{4}\b',
    );
    entities.addAll(
      phoneRegex
          .allMatches(text)
          .map((m) => AiEntity(EntityType.phone, m.group(0)!)),
    );

    // URL Regex
    final urlRegex = RegExp(r'https?://(?:[-\w.]|(?:%[\da-fA-F]{2}))+');
    entities.addAll(
      urlRegex
          .allMatches(text)
          .map((m) => AiEntity(EntityType.url, m.group(0)!)),
    );

    // Amount Regex Example (Currency)
    final amountRegex = RegExp(r'[\$€£₹]\s?\d+(?:,\d{3})*(?:\.\d{2})?');
    entities.addAll(
      amountRegex
          .allMatches(text)
          .map((m) => AiEntity(EntityType.amount, m.group(0)!)),
    );

    return entities;
  }
}
