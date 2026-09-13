import 'package:cloud_firestore/cloud_firestore.dart';

class ContactModel {
  final String id;
  final String name;
  final String relation;
  final String phone;
  final String type; // 'family' or 'bhw'

  ContactModel({
    required this.id,
    required this.name,
    required this.relation,
    required this.phone,
    required this.type,
  });

  factory ContactModel.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ContactModel(
      id: doc.id,
      name: data['full_name'] ?? '',
      relation: data['relationship'] ?? '',
      phone: data['contact_num'] ?? '',
      type: data['contact_type'] ?? 'family',
    );
  }

  /// Two-letter initials generated from the name, e.g. "Juan Santos" -> "JS".
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class MedicineModel {
  final String id;
  final String name;
  final String time;
  final String status; // 'Upcoming' or 'Notified'

  MedicineModel({
    required this.id,
    required this.name,
    required this.time,
    required this.status,
  });

  factory MedicineModel.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MedicineModel(
      id: doc.id,
      name: data['medicine_name'] ?? '',
      time: data['reminder_time'] ?? '',
      status: data['status'] ?? 'Upcoming',
    );
  }
}

class AlertModel {
  final String id;
  final String type; // 'emergency', 'medicine', 'battery', 'system'
  final String title;
  final String time;
  final List<String> lines;

  AlertModel({
    required this.id,
    required this.type,
    required this.title,
    required this.time,
    required this.lines,
  });

  factory AlertModel.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AlertModel(
      id: doc.id,
      type: data['type'] ?? 'system',
      title: data['title'] ?? '',
      time: data['time'] ?? '',
      lines: List<String>.from(data['lines'] ?? const []),
    );
  }
}
