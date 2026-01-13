class FAQ {
  final int id;
  final String question;
  final String answer;
  final String category;
  final String categoryDisplay;
  final int order;
  final DateTime createdAt;

  FAQ({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    required this.categoryDisplay,
    required this.order,
    required this.createdAt,
  });

  factory FAQ.fromJson(Map<String, dynamic> json) {
    return FAQ(
      id: json['id'] ?? 0,
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
      category: json['category'] ?? 'general',
      categoryDisplay: json['category_display'] ?? 'General',
      order: json['order'] ?? 0,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'answer': answer,
      'category': category,
      'category_display': categoryDisplay,
      'order': order,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class SupportTicket {
  final int id;
  final int? userId;
  final String? userUsername;
  final String? userEmail;
  final String subject;
  final String message;
  final String status;
  final String statusDisplay;
  final String? adminResponse;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupportTicket({
    required this.id,
    this.userId,
    this.userUsername,
    this.userEmail,
    required this.subject,
    required this.message,
    required this.status,
    required this.statusDisplay,
    this.adminResponse,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] ?? 0,
      userId: json['user'],
      userUsername: json['user_username'],
      userEmail: json['user_email'],
      subject: json['subject'] ?? '',
      message: json['message'] ?? '',
      status: json['status'] ?? 'open',
      statusDisplay: json['status_display'] ?? 'Abierto',
      adminResponse: json['admin_response'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': userId,
      'user_username': userUsername,
      'user_email': userEmail,
      'subject': subject,
      'message': message,
      'status': status,
      'status_display': statusDisplay,
      'admin_response': adminResponse,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper para obtener color según estado
  String getStatusColor() {
    switch (status) {
      case 'open':
        return '#2196F3'; // Azul
      case 'in_progress':
        return '#FF9800'; // Naranja
      case 'resolved':
        return '#4CAF50'; // Verde
      case 'closed':
        return '#9E9E9E'; // Gris
      default:
        return '#757575';
    }
  }
}
