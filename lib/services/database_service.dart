import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ──────────────────────────────────────────────
  // 1. Save Baseline Data
  // ──────────────────────────────────────────────
  Future<void> saveUserBaseline(Map<String, dynamic> baselineData) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      debugPrint("🔴 Cannot save baseline: User is not logged in.");
      return;
    }

    try {
      // Merge true ensures we don't overwrite existing fields we aren't updating
      await _db
          .collection('users')
          .doc(user.uid)
          .set(baselineData, SetOptions(merge: true));
      debugPrint("✅ Baseline successfully synced to cloud.");
    } catch (e) {
      debugPrint("🔴 Error saving baseline to cloud: $e");
    }
  }

  // ──────────────────────────────────────────────
  // 2. Fetch Baseline Data
  // ──────────────────────────────────────────────
  Future<Map<String, dynamic>?> getUserBaseline() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      debugPrint("🔴 Cannot fetch baseline: User is not logged in.");
      return null;
    }

    try {
      final docSnapshot = await _db.collection('users').doc(user.uid).get();

      if (docSnapshot.exists) {
        debugPrint("✅ Cloud baseline fetched successfully.");
        return docSnapshot.data();
      } else {
        debugPrint("⚠️ No cloud baseline found for user.");
        return null;
      }
    } catch (e) {
      debugPrint("🔴 Error fetching baseline from cloud: $e");
      return null;
    }
  }

  // ──────────────────────────────────────────────
  // 3. NUKE User Data
  // ──────────────────────────────────────────────
  Future<void> nukeUserData() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      debugPrint("🔴 Cannot nuke data: User is not logged in.");
      return;
    }

    try {
      // This wipes the entire Firestore document for the user
      await _db.collection('users').doc(user.uid).delete();
      debugPrint("☢️ User data successfully NUKED from cloud.");
    } catch (e) {
      debugPrint("🔴 Error nuking data from cloud: $e");
      // Rethrow if you want the UI to catch and show a snackbar
      rethrow; 
    }
  }
}
