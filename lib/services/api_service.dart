import 'dart:convert';
import 'package:http/http.dart' as http;
import '../state/finance_state.dart';

class ApiService {
  // Production Backend on Vercel
  final String baseUrl = "https://fine-pocket.vercel.app/api"; 

   Future<String> getChatResponse(String userMessage, List<Map<String, dynamic>> chatHistory, FinanceState state) async {
  print("🚀 Fine Pocket Backend: Online");
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "message": userMessage,
        "history": chatHistory,
        "safeBalance": state.safeBalance,
        "goals": state.goals.map((g) => {"name": g.name, "target": g.targetAmount, "saved": g.savedAmount}).toList(),
        "monthlyPocketMoney": state.monthlyIncome,
        "recentSpends": state.recentActivity,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // This is the "reply" key we found in your Next.js code!
      return data['reply']; 
    } else {
      return "🚨 FinBot error: ${response.statusCode}";
    }
  } catch (e) {
    return "🔌 Connection failed. Check your IP address!";
  }
}

  Future<Map<String, dynamic>?> parseSms(String smsBody) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "message":
              'SYSTEM COMMAND: You are a strict data parser. Read this bank SMS. '
              'Extract the amount spent and the merchant name. '
              'Return ONLY a valid JSON object exactly like this: '
              '{"isExpense": true, "amount": 450.0, "merchant": "Swiggy"}. '
              'Do not include markdown blocks, greetings, or any conversational text. '
              'Here is the SMS: $smsBody',
          "history": [],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String replyStr = data['reply']?.toString() ?? '';
        print('🤖 RAW AI REPLY: $replyStr');

        // JSON Hunter — extracts the first {...} blob even if Gemini adds markdown
        final RegExp jsonRegExp = RegExp(r'\{.*\}', dotAll: true);
        final match = jsonRegExp.firstMatch(replyStr);
        if (match != null) {
          try {
            final cleanJson = match.group(0)!;
            final parsed = jsonDecode(cleanJson);
            if (parsed['amount'] != null && parsed['merchant'] != null) {
              final double amount = parsed['amount'] is num
                  ? (parsed['amount'] as num).toDouble()
                  : double.tryParse(
                          parsed['amount'].toString().replaceAll(RegExp(r'[^0-9.]'), '')) ??
                      0.0;
              return {
                "isExpense": true,
                "amount": amount,
                "merchant": parsed['merchant'].toString(),
              };
            }
          } catch (e) {
            print('❌ JSON Hunter parse error: $e | raw: ${match.group(0)}');
          }
        } else {
          print('⚠️ No JSON object found in AI reply');
        }
      } else {
        print('parseSms non-200: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print("Failed to parse SMS via API: $e");
    }
    return null;
  }

  Future<String> getRoast(FinanceState state) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/roast'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "safeBalance": state.safeBalance,
          "expenses": state.recentActivity,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['roast'] ?? data['reply'] ?? "I'm speechless. Your spending is too chaotic even for me.";
      } else {
        return "🚨 FinBot error: ${response.statusCode}";
      }
    } catch (e) {
      return "🔌 Connection failed. Ensure the Next.js server is running on $baseUrl!";
    }
  }

  /// Sends a base64-encoded image to /api/scan and returns {amount, title}
  Future<Map<String, dynamic>?> scanReceipt(String base64Image) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/scan'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"imageBase64": base64Image}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("🤖 GEMINI SEES: $data");

        // Grab whatever name the AI gave it
        String? extractedTitle = data['title'] ?? data['merchant'] ?? data['name'] ?? "Scanned Receipt";

        if (data['amount'] != null) {
          double parsedAmount = 0.0;
          if (data['amount'] is String) {
            String cleanAmount = data['amount'].replaceAll(RegExp(r'[^0-9.]'), '');
            parsedAmount = double.tryParse(cleanAmount) ?? 0.0;
          } else if (data['amount'] is num) {
            parsedAmount = (data['amount'] as num).toDouble();
          }

          return {
            "amount": parsedAmount,
            "title": extractedTitle,
          };
        }
      } else {
        print("❌ Server rejected: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print('🔥 SCAN API CRASH: $e');
    }
    return null;
  }
}