import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';

/// Singleton service that owns every Firestore read/write for user data.
///
/// • [syncUserToCloud]     – upserts a UserModel (merge: true).
/// • [streamUserStats]     – real-time stream for UI binding.
/// • [migrateLocalToCloud] – one-time migration from shared_preferences.
/// • [nukeUserData]        – deletes the user's Firestore document.
class FirestoreService {
  // ── Singleton boilerplate ────────────────────────────────────────────────
  FirestoreService._internal();
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;

  // ── Firebase references ──────────────────────────────────────────────────
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Convenience getter for the logged-in user's document reference.
  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  // ========================================================================
  // 1.  SYNC TO CLOUD  (Create / Update with merge)
  // ========================================================================

  /// Persists [user] to Firestore using `SetOptions(merge: true)` so that
  /// existing fields the caller did not include are preserved.
  Future<void> syncUserToCloud(UserModel user) async {
    final doc = _userDoc;
    if (doc == null) {
      debugPrint('🔴 FirestoreService.syncUserToCloud: No authenticated user.');
      return;
    }

    try {
      await doc.set(user.toMap(), SetOptions(merge: true));
      debugPrint('✅ FirestoreService: Data synced for uid=${user.uid}');
    } catch (e) {
      debugPrint('🔴 FirestoreService.syncUserToCloud error: $e');
      rethrow;
    }
  }

  // ========================================================================
  // 2.  STREAM USER STATS  (Real-time updates for UI)
  // ========================================================================

  /// Returns a real-time stream of the current user's [UserModel].
  ///
  /// Emits `null` when the document does not exist or the user is not
  /// logged in.  Bind this to a `StreamBuilder` in your UI so budget
  /// changes appear instantly.
  Stream<UserModel?> streamUserStats() {
    final doc = _userDoc;
    if (doc == null) {
      debugPrint('⚠️ FirestoreService.streamUserStats: No authenticated user.');
      return Stream.value(null);
    }

    return doc.snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return UserModel.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  // ========================================================================
  // 3.  LOCAL → CLOUD MIGRATION
  // ========================================================================

  /// Reads `baselineBudget` (stored as `monthlyIncome`) and `displayName`
  /// from shared_preferences.  If the user's Firestore document is empty
  /// (doesn't exist or has no `baselineBudget`), uploads the local data.
  ///
  /// Uses `SetOptions(merge: true)` so it never stomps on data that may
  /// already live in the cloud (e.g. if the user logged in on a second
  /// device first).
  ///
  /// **Call this once immediately after login.**
  Future<void> migrateLocalToCloud() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ migrateLocalToCloud: No authenticated user – skipping.');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // ── Gather local data ────────────────────────────────────────────────
      // FinanceState saves income under the key 'monthlyIncome'
      final double localBudget = prefs.getDouble('monthlyIncome') ?? 0.0;
      final double localBalance = prefs.getDouble('safeBalance') ?? 0.0;
      // GuestNameScreen writes 'guest_name'; older code also checks 'guestName'
      final String? localName =
          prefs.getString('guest_name') ?? prefs.getString('guestName');

      // Also check the Firebase user's displayName (set by Google Sign-In)
      final String? displayName = localName ?? user.displayName;

      final bool hasLocalData = localBudget > 0 || localBalance > 0;

      if (!hasLocalData) {
        debugPrint(
            'ℹ️ migrateLocalToCloud: No meaningful local data – nothing to migrate.');
        return;
      }

      // ── Check if cloud document already has data ─────────────────────────
      final docRef = _db.collection('users').doc(user.uid);
      final snapshot = await docRef.get();

      final bool cloudIsEmpty =
          !snapshot.exists || (snapshot.data()?['baselineBudget'] == null);

      if (!cloudIsEmpty) {
        debugPrint(
            'ℹ️ migrateLocalToCloud: Cloud already has data – skipping.');
        return;
      }

      // ── Build model and push ─────────────────────────────────────────────
      final userModel = UserModel(
        uid: user.uid,
        name: displayName,
        baselineBudget: localBudget,
        currentBalance: localBalance,
      );

      await docRef.set(userModel.toMap(), SetOptions(merge: true));
      debugPrint(
          '🚀 migrateLocalToCloud: Local data uploaded to Firestore.');
    } catch (e) {
      debugPrint('🔴 migrateLocalToCloud error: $e');
      // Intentionally don't rethrow – migration failure should not block
      // the user from using the app.
    }
  }

  // ========================================================================
  // 4.  NUKE  (Delete Firestore document – kept from old DatabaseService)
  // ========================================================================

  /// Deletes the entire Firestore document for the current user.
  Future<void> nukeUserData() async {
    final doc = _userDoc;
    if (doc == null) {
      debugPrint('🔴 FirestoreService.nukeUserData: No authenticated user.');
      return;
    }

    try {
      await doc.delete();
      debugPrint('☢️ FirestoreService: User data NUKED.');
    } catch (e) {
      debugPrint('🔴 FirestoreService.nukeUserData error: $e');
      rethrow;
    }
  }
}
