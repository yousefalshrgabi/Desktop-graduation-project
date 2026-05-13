import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProgramTrack {
  final String trackId;
  final String nameAr;
  final String nameEn;
  final int startsAtLevel;

  ProgramTrack({
    required this.trackId,
    required this.nameAr,
    required this.nameEn,
    required this.startsAtLevel,
  });

  Map<String, dynamic> toMap() {
    return {
      'track_id': trackId,
      'name_ar': nameAr,
      'name_en': nameEn,
      'starts_at_level': startsAtLevel,
    };
  }

  factory ProgramTrack.fromMap(Map<String, dynamic> map) {
    return ProgramTrack(
      trackId: map['track_id'] ?? '',
      nameAr: map['name_ar'] ?? '',
      nameEn: map['name_en'] ?? '',
      startsAtLevel: map['starts_at_level'] ?? 1,
    );
  }
}

class ProgramModel {
  String id;
  String nameAr;
  String nameEn;
  int totalLevels;
  String status;
  List<ProgramTrack> tracks;
  bool isSynced;
  DateTime createdAt;

  ProgramModel({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.totalLevels,
    required this.status,
    required this.tracks,
    this.isSynced = false,
    required this.createdAt,
  });

  // To Firestore Map
  Map<String, dynamic> toFirestoreMap() {
    return {
      'name_ar': nameAr,
      'name_en': nameEn,
      'total_levels': totalLevels,
      'status': status,
      'tracks': tracks.map((t) => t.toMap()).toList(),
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  // From Firestore Map
  factory ProgramModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    List<dynamic> tracksData = data['tracks'] ?? [];
    return ProgramModel(
      id: doc.id,
      nameAr: data['name_ar'] ?? '',
      nameEn: data['name_en'] ?? '',
      totalLevels: data['total_levels'] ?? 4,
      status: data['status'] ?? 'active',
      tracks: tracksData.map((t) => ProgramTrack.fromMap(t)).toList(),
      isSynced: true,
      createdAt: (data['created_at'] != null && data['created_at'] is Timestamp)
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // To SQLite Map
  Map<String, dynamic> toSQLiteMap() {
    return {
      'id': id,
      'name_ar': nameAr,
      'name_en': nameEn,
      'total_levels': totalLevels,
      'status': status,
      'tracks': jsonEncode(tracks.map((t) => t.toMap()).toList()),
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // From SQLite Map
  factory ProgramModel.fromSQLite(Map<String, dynamic> map) {
    List<dynamic> tracksData = [];
    if (map['tracks'] != null && map['tracks'].toString().isNotEmpty) {
      try {
        tracksData = jsonDecode(map['tracks']);
      } catch (e) {
        // Handle parsing error if needed
      }
    }

    return ProgramModel(
      id: map['id'],
      nameAr: map['name_ar'] ?? '',
      nameEn: map['name_en'] ?? '',
      totalLevels: map['total_levels'] ?? 4,
      status: map['status'] ?? 'active',
      tracks: tracksData.map((t) => ProgramTrack.fromMap(t)).toList(),
      isSynced: map['is_synced'] == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }
}
