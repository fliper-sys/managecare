// lib/data/models/gym_trainer_model.dart

class Trainer {
  final String id;
  final String name;
  final String specialty;

  Trainer({required this.id, required this.name, this.specialty = ''});

  Trainer copyWith({String? id, String? name, String? specialty}) {
    return Trainer(
      id: id ?? this.id,
      name: name ?? this.name,
      specialty: specialty ?? this.specialty,
    );
  }

  factory Trainer.fromJson(Map<String, dynamic> json) {
    return Trainer(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      specialty: json['specialty'] ?? json['skill'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'specialty': specialty,
    };
  }
}

