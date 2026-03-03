import 'egg_record.dart';

class AnimalGroup {
  final String id;
  String type; // poultry, cattle, sheep, goats, pigs, rabbits, fish, bees, etc.
  String name;
  int count;
  int ageWeeks;
  int maturityWeek; // expected maturity week
  double feedPerAnimalGrams; // feed per animal per day in grams
  String emoji; // emoji icon for group (e.g., 🐔, 🐄)
  List<EggRecord> eggRecords;
  List<Map<String, dynamic>> feedRecords; // track feed usage
  List<Map<String, dynamic>> healthRecords; // track health events
  DateTime createdAt;
  DateTime updatedAt;

  AnimalGroup({
    required this.id,
    required this.type,
    required this.name,
    required this.count,
    this.ageWeeks = 0,
    this.maturityWeek = 20,
    this.feedPerAnimalGrams = 100.0,
    this.emoji = '🐔',
    List<EggRecord>? eggRecords,
    List<Map<String, dynamic>>? feedRecords,
    List<Map<String, dynamic>>? healthRecords,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : eggRecords = eggRecords ?? [],
        feedRecords = feedRecords ?? [],
        healthRecords = healthRecords ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Get emoji for group type
  static String getEmojiForType(String type) {
    const typeEmojis = {
      'poultry': '🐔',
      'chicken': '🐔',
      'cattle': '🐄',
      'cow': '🐄',
      'sheep': '🐑',
      'goats': '🐐',
      'goat': '🐐',
      'pigs': '🐷',
      'pig': '🐷',
      'rabbits': '🐰',
      'rabbit': '🐰',
      'fish': '🐟',
      'bees': '🐝',
      'horses': '🐴',
      'horse': '🐴',
      'ducks': '🦆',
      'duck': '🦆',
      'turkeys': '🦃',
      'turkey': '🦃',
      'geese': '🦢',
      'goose': '🦢',
      'guinea_fowl': '🐦',
      'quail': '🐤',
    };
    return typeEmojis[type.toLowerCase()] ?? '🐾';
  }

  /// Feed calculation based on group type
  double calculateDailyFeedKg({required String feedType}) {
    // feedType: 'starter', 'grower', 'layer', 'maintenance'
    final baseGrams = feedPerAnimalGrams;
    final factor = switch (feedType.toLowerCase()) {
      'starter' => 1.2,
      'grower' => 1.0,
      'layer' => 0.9,
      'maintenance' => 0.85,
      _ => 1.0,
    };
    return (count * baseGrams * factor) / 1000.0;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'name': name,
        'count': count,
        'ageWeeks': ageWeeks,
        'maturityWeek': maturityWeek,
        'feedPerAnimalGrams': feedPerAnimalGrams,
        'emoji': emoji,
        'eggRecords': eggRecords.map((e) => e.toMap()).toList(),
        'feedRecords': feedRecords,
        'healthRecords': healthRecords,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AnimalGroup.fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String? ?? 'poultry';
    return AnimalGroup(
      id: map['id'] as String? ?? '',
      type: type,
      name: map['name'] as String? ?? '',
      count: (map['count'] as num?)?.toInt() ?? 0,
      ageWeeks: (map['ageWeeks'] as num?)?.toInt() ?? 0,
      maturityWeek: (map['maturityWeek'] as num?)?.toInt() ?? 20,
      feedPerAnimalGrams: (map['feedPerAnimalGrams'] as num?)?.toDouble() ?? 100.0,
      emoji: map['emoji'] as String? ?? getEmojiForType(type),
      eggRecords: (map['eggRecords'] as List<dynamic>?)
              ?.map((e) => EggRecord.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      feedRecords: List<Map<String, dynamic>>.from(
          (map['feedRecords'] as List<dynamic>?) ?? []),
      healthRecords: List<Map<String, dynamic>>.from(
          (map['healthRecords'] as List<dynamic>?) ?? []),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }

  double dailyFeedKg() => (count * feedPerAnimalGrams) / 1000.0;

  int weeksToMaturity() =>
      (maturityWeek - ageWeeks) > 0 ? (maturityWeek - ageWeeks) : 0;

  double averageEggsPerDay({int days = 7}) {
    if (eggRecords.isEmpty) return 0;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final recent = eggRecords.where((r) => r.date.isAfter(cutoff)).toList();
    if (recent.isEmpty) return 0;
    final sum = recent.fold<int>(0, (p, e) => p + e.count);
    return sum / days;
  }

  /// Add feed record to history
  void addFeedRecord(double kgFed, {String? feedType, String? notes}) {
    feedRecords.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'date': DateTime.now().toIso8601String(),
      'kgFed': kgFed,
      'feedType': feedType ?? 'general',
      'notes': notes ?? '',
    });
    updatedAt = DateTime.now();
  }

  /// Add health record
  void addHealthRecord(String eventType, {String? description}) {
    healthRecords.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'date': DateTime.now().toIso8601String(),
      'eventType': eventType,
      'description': description ?? '',
    });
    updatedAt = DateTime.now();
  }
}

// Backward compatibility alias
typedef LivestockGroup = AnimalGroup;

