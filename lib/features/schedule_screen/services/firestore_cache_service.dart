import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Central Firestore offline/cache helpers to reduce billed document reads.
///
/// Reads served from the local cache are not counted toward the Firestore quota.
/// Pattern: try [Source.cache] first, then fall back to [Source.serverAndCache].
class FirestoreCacheService {
  FirestoreCacheService._();

  static const GetOptions cacheOnly =
      GetOptions(source: Source.cache);
  static const GetOptions serverAndCache =
      GetOptions(source: Source.serverAndCache);

  static Future<void> configure() async {
    // Persistent disk cache on mobile/desktop reduces repeat reads across sessions.
    // On web we rely on the SDK session cache + cache-first reads below (see web note).
    if (!kIsWeb) {
      final firestore = FirebaseFirestore.instance;
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 100 * 1024 * 1024, // 100 MB — enough for plans + timetables
      );
    }
  }

  /// Runs a query: cache first unless [forceRefresh], then server+cache.
  static Future<QuerySnapshot<Map<String, dynamic>>> queryCachedFirst(
    Query<Map<String, dynamic>> query, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      try {
        final cached = await query.get(cacheOnly);
        if (cached.docs.isNotEmpty) {
          return cached;
        }
      } catch (_) {
        // Cache miss or unavailable — fall through to network.
      }
    }
    return query.get(serverAndCache);
  }

  /// Reads a document: cache first unless [forceRefresh], then server+cache.
  static Future<DocumentSnapshot<Map<String, dynamic>>> docCachedFirst(
    DocumentReference<Map<String, dynamic>> ref, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      try {
        final cached = await ref.get(cacheOnly);
        if (cached.exists) {
          return cached;
        }
      } catch (_) {
        // Ignore and fetch from server.
      }
    }
    return ref.get(serverAndCache);
  }

  /// Reads a subcollection with cache-first semantics.
  static Future<QuerySnapshot<Map<String, dynamic>>> collectionCachedFirst(
    CollectionReference<Map<String, dynamic>> col, {
    bool forceRefresh = false,
  }) {
    return queryCachedFirst(col, forceRefresh: forceRefresh);
  }
}
