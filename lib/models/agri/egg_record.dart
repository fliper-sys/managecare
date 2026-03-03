class EggRecord {
  final DateTime date;
  final int count;
  final String? note;

  EggRecord({required this.date, required this.count, this.note});

  Map<String, dynamic> toMap() =>
      {'date': date.toIso8601String(), 'count': count, 'note': note};

  factory EggRecord.fromMap(Map<String, dynamic> map) => EggRecord(
      date: DateTime.parse(map['date']),
      count: (map['count'] as num).toInt(),
      note: map['note']);
}

