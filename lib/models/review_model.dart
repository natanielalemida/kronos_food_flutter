class ReviewModel {
  final String id;
  final String orderId;
  final String merchantId;
  final double overallRating;
  final double deliveryRating;
  final double foodRating;
  final String? comment;
  final DateTime createdAt;
  final List<String> tags;
  final bool answered;
  final ReviewAnswerModel? answer;

  ReviewModel({
    required this.id,
    required this.orderId,
    required this.merchantId,
    required this.overallRating,
    required this.deliveryRating,
    required this.foodRating,
    this.comment,
    required this.createdAt,
    this.tags = const [],
    this.answered = false,
    this.answer,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] ?? '',
      orderId: json['orderId'] ?? '',
      merchantId: json['merchantId'] ?? '',
      overallRating: json['overallRating']?.toDouble() ?? 0.0,
      deliveryRating: json['deliveryRating']?.toDouble() ?? 0.0,
      foodRating: json['foodRating']?.toDouble() ?? 0.0,
      comment: json['comment'],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      answered: json['answered'] ?? false,
      answer: json['answer'] != null 
          ? ReviewAnswerModel.fromJson(json['answer']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'orderId': orderId,
      'merchantId': merchantId,
      'overallRating': overallRating,
      'deliveryRating': deliveryRating,
      'foodRating': foodRating,
      'createdAt': createdAt.toIso8601String(),
      'tags': tags,
      'answered': answered,
    };
    
    if (comment != null) {
      data['comment'] = comment;
    }
    
    if (answer != null) {
      data['answer'] = answer!.toJson();
    }
    
    return data;
  }
}

class ReviewAnswerModel {
  final String id;
  final String text;
  final DateTime createdAt;

  ReviewAnswerModel({
    required this.id,
    required this.text,
    required this.createdAt,
  });

  factory ReviewAnswerModel.fromJson(Map<String, dynamic> json) {
    return ReviewAnswerModel(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

// Modelo de estatísticas de avaliação
class ReviewStatisticsModel {
  final String merchantId;
  final double averageRating;
  final Map<int, int> ratingDistribution;
  final int totalReviews;
  final DateTime lastUpdated;

  ReviewStatisticsModel({
    required this.merchantId,
    required this.averageRating,
    required this.ratingDistribution,
    required this.totalReviews,
    required this.lastUpdated,
  });

  factory ReviewStatisticsModel.fromJson(Map<String, dynamic> json) {
    Map<int, int> distribution = {};
    if (json['ratingDistribution'] != null) {
      json['ratingDistribution'].forEach((key, value) {
        distribution[int.parse(key)] = value;
      });
    }

    return ReviewStatisticsModel(
      merchantId: json['merchantId'] ?? '',
      averageRating: json['averageRating']?.toDouble() ?? 0.0,
      ratingDistribution: distribution,
      totalReviews: json['totalReviews'] ?? 0,
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.parse(json['lastUpdated']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, int> distribution = {};
    ratingDistribution.forEach((key, value) {
      distribution[key.toString()] = value;
    });

    return {
      'merchantId': merchantId,
      'averageRating': averageRating,
      'ratingDistribution': distribution,
      'totalReviews': totalReviews,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
} 