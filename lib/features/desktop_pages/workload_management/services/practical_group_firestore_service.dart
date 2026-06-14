import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/practical_group_setting.dart';
import 'package:academic_affairs_management/features/schedule_screen/services/firestore_cache_service.dart';
import 'practical_group_discovery_service.dart';

/// Persists lab group counts per college / program / level.
class PracticalGroupFirestoreService {
  PracticalGroupFirestoreService({
    FirebaseFirestore? firestore,
    PracticalGroupDiscoveryService? discovery,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _discovery = discovery ?? PracticalGroupDiscoveryService();

  final FirebaseFirestore _db;
  final PracticalGroupDiscoveryService _discovery;

  static const String collection = 'practical_group_settings';

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(collection);

  Future<Map<String, PracticalGroupSetting>> loadSettingsMap({
    required String collegeName,
    bool forceRefresh = false,
  }) async {
    final snap = await FirestoreCacheService.queryCachedFirst(
      _col.where('collegeName', isEqualTo: collegeName.trim()),
      forceRefresh: forceRefresh,
    );

    final out = <String, PracticalGroupSetting>{};
    for (final doc in snap.docs) {
      final s = PracticalGroupSetting.fromMap(doc.id, doc.data());
      out[doc.id] = s;
    }
    return out;
  }

  Future<List<ProgramLevelPracticalRow>> loadRows({
    required String collegeName,
    bool forceRefresh = false,
  }) async {
    final saved = await loadSettingsMap(
      collegeName: collegeName,
      forceRefresh: forceRefresh,
    );
    return _discovery.discoverRows(
      collegeName: collegeName,
      savedByDocId: saved,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> saveAll({
    required String collegeName,
    required List<ProgramLevelPracticalRow> rows,
  }) async {
    WriteBatch batch = _db.batch();
    var count = 0;

    Future<void> flush() async {
      if (count >= 400) {
        await batch.commit();
        batch = _db.batch();
        count = 0;
      }
    }

    for (final row in rows) {
      final docId = PracticalGroupSetting.docIdFor(
        collegeName: collegeName,
        programName: row.programName,
        level: row.level,
      );
      batch.set(_col.doc(docId), {
        'collegeName': collegeName.trim(),
        'programName': row.programName,
        'level': row.level,
        'groupCount': row.groupCount,
        'parallelGroupIndices': row.parallelGroupIndices,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      count++;
      await flush();
    }

    if (count > 0) {
      await batch.commit();
    }
  }

  Future<PracticalGroupSetting?> getSetting({
    required String collegeName,
    required String programName,
    required int level,
    bool forceRefresh = false,
  }) async {
    final docId = PracticalGroupSetting.docIdFor(
      collegeName: collegeName,
      programName: programName,
      level: level,
    );
    final doc = await FirestoreCacheService.docCachedFirst(
      _col.doc(docId),
      forceRefresh: forceRefresh,
    );
    if (!doc.exists || doc.data() == null) return null;
    return PracticalGroupSetting.fromMap(doc.id, doc.data()!);
  }
}
