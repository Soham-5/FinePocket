import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  // Replace this with your actual Vercel URL (see Step 3 below)
  final String _baseUrl = 'https://fine-pocket.vercel.app/api/chat';

  Future<String> sendMessage(String message, List<Map<String, dynamic>> history) async {
    try {
      // Get the current user's UID from Firebase
      final String? uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) return "Error: User not logged in.";

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'history': history,
          'uid': uid, // This is the "Secret Sauce" for your Next.js logic
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'];
      } else {
        return "FinBot is having trouble thinking right now.";
      }
    } catch (e) {
      return "Connection error: $e";
    }
  }
}