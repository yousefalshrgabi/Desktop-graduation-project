import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/timetable_entry.dart';

/// Uploads and replaces the whole timetable collection in Firestore.
class TimetableFirestoreService {
  TimetableFirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// One document per activity (CSV row).
  static const String collectionName = 'timetable_activities';

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(collectionName);

  /// Replaces/deletes only what's necessary to avoid massive writes.
  Future<void> replaceAll(List<TimetableEntry> entries) async {
    final currentSnap = await _col
        .limit(2000)
        .get(const GetOptions(source: Source.serverAndCache));
    final existingDocs = currentSnap.docs;

    WriteBatch batch = _db.batch();
    int batchCount = 0;

    Future<void> commitBatchIfLimit() async {
      if (batchCount >= 400) {
        await batch.commit();
        batch = _db.batch();
        batchCount = 0;
      }
    }

    final newDocs = <String, Map<String, dynamic>>{};
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final docId = _docIdFor(e, i);
      newDocs[docId] = e.toFirestoreMap();
    }

    // 1. Delete removed, Update changed
    for (final existing in existingDocs) {
      final eId = existing.id;
      if (!newDocs.containsKey(eId)) {
        batch.delete(existing.reference);
        batchCount++;
      } else {
        final existingData = existing.data();
        final newData = newDocs[eId]!;
        if (existingData.toString() != newData.toString()) {
          batch.set(existing.reference, newData);
          batchCount++;
        }
        newDocs.remove(eId);
      }
      await commitBatchIfLimit();
    }

    // 2. Add remaining (entirely new)
    for (final newEntry in newDocs.entries) {
      batch.set(_col.doc(newEntry.key), newEntry.value);
      batchCount++;
      await commitBatchIfLimit();
    }

    if (batchCount > 0) {
      await batch.commit();
    }
  }

  String _docIdFor(TimetableEntry e, int index) {
    var base = e.id.trim();
    if (base.isEmpty) base = 'entry';
    base = base.replaceAll('/', '_');
    base = base.replaceAll(RegExp(r'[\[\]\\*]'), '_');
    if (base.length > 200) base = base.substring(0, 200);
    return '${base}_$index';
  }

  Future<List<TimetableEntry>> getAllCachedFirst() async {
    try {
      final snap =
          await _col.limit(2000).get(const GetOptions(source: Source.cache));
      if (snap.docs.isNotEmpty) {
        return snap.docs
            .map((d) => TimetableEntry.fromFirestoreMap(
                  d.data(),
                ))
            .toList();
      }
    } catch (_) {
      // Ignore cache failure, fallback to server
    }

    final snap = await _col
        .limit(2000)
        .get(const GetOptions(source: Source.serverAndCache));
    return snap.docs
        .map((d) => TimetableEntry.fromFirestoreMap(d.data()))
        .toList();
  }

  Future<List<TimetableEntry>> fetchAll() async {
    final snap = await _col.limit(2000).get();
    return snap.docs
        .map((d) => TimetableEntry.fromFirestoreMap(d.data()))
        .toList();
  }
}
