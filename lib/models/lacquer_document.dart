enum LacquerDocumentKind { word, excel, presentation, pdf, other }

class LacquerDocument {
  const LacquerDocument({
    required this.id,
    required this.title,
    required this.kind,
    required this.status,
    required this.uploadedAt,
  });

  factory LacquerDocument.fromJson(Map<String, dynamic> json) {
    return LacquerDocument(
      id: json['id'].toString(),
      title: json['title'] as String,
      kind: _kindFrom(json['kind'] as String?),
      status: json['status'] as String? ?? 'ready',
      uploadedAt: DateTime.tryParse(json['uploaded_at'] as String? ?? ''),
    );
  }

  final String id;
  final String title;
  final LacquerDocumentKind kind;
  final String status;
  final DateTime? uploadedAt;

  bool get isReady => status == 'ready';

  bool get isFailed => status == 'failed';

  static LacquerDocumentKind _kindFrom(String? value) {
    return switch (value) {
      'word' => LacquerDocumentKind.word,
      'excel' => LacquerDocumentKind.excel,
      'pptx' => LacquerDocumentKind.presentation,
      'pdf' => LacquerDocumentKind.pdf,
      _ => LacquerDocumentKind.other,
    };
  }
}
