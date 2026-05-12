/// Data model representing a FinePocket user's core financial profile.
///
/// Used for serialising / deserialising between Firestore documents and Dart
/// objects.  Only the fields that need cloud-sync are modelled here;
/// transient or device-only data (e.g. SMS permissions) stays in
/// shared_preferences.
class UserModel {
  final String uid;
  final String? name;
  final double baselineBudget;
  final double currentBalance;

  UserModel({
    required this.uid,
    this.name,
    required this.baselineBudget,
    required this.currentBalance,
  });

  // Convert Firestore Map → Object
  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      uid: id,
      name: data['name'],
      baselineBudget: (data['baselineBudget'] ?? 0.0).toDouble(),
      currentBalance: (data['currentBalance'] ?? 0.0).toDouble(),
    );
  }

  // Convert Object → Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'baselineBudget': baselineBudget,
      'currentBalance': currentBalance,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }
}
