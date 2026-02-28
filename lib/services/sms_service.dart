import 'package:flutter/foundation.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../state/finance_state.dart';

class SmsService {
  final Telephony telephony = Telephony.instance;
  final ApiService _apiService = ApiService();

  // Callback wired to FinanceState.addManualSpend
  Function(double amount, String title)? onExpenseFound;

  void initialize(FinanceState state) {
    onExpenseFound = state.addManualSpend;
  }

  Future<bool> requestPermissions() async {
    bool? result = await telephony.requestPhoneAndSmsPermissions;
    debugPrint('SMS Permission result: $result');
    return result ?? false;
  }

  Future<bool> hasPermissions() async {
    bool? result = await telephony.requestPhoneAndSmsPermissions;
    return result ?? false;
  }

  /// Called on app start — checks if user has SMS sync enabled, and if so, starts listening
  Future<void> initSmsListener(FinanceState state) async {
    final prefs = await SharedPreferences.getInstance();
    final isSmsEnabled = prefs.getBool('isSmsEnabled') ?? false;
    if (!isSmsEnabled) return;

    initialize(state);
    listenToSms();
    debugPrint('📱 SMS Listener activated');
  }

  /// Keyword list: only process messages that look like bank debits
  bool _looksLikeBankSms(String body) {
    final lower = body.toLowerCase();
    return lower.contains('debited') ||
        lower.contains('spent') ||
        lower.contains('inr') ||
        lower.contains('rs.') ||
        lower.contains('₹') ||
        lower.contains('debit') ||
        lower.contains('withdrawn') ||
        lower.contains('payment of');
  }

  void listenToSms() {
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        final body = message.body;
        if (body == null) return;

        print("📩 SMS RECEIVED: $body");

        // Pre-filter: only send bank-looking messages to the AI parser
        if (!_looksLikeBankSms(body)) {
          print('⏭️ Not a bank SMS — skipping');
          return;
        }

        print("🏦 BANK SMS DETECTED! Sending to API...");
        final parsedData = await _apiService.parseSms(body);
        print("🧠 AI PARSED RESULT: $parsedData");

        if (parsedData != null && onExpenseFound != null) {
          // Explicitly extract and coerce values before calling state
          final rawAmount = parsedData['amount'];
          final double amount = rawAmount is num
              ? rawAmount.toDouble()
              : double.tryParse(rawAmount.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

          final String merchant =
              parsedData['merchant']?.toString().isNotEmpty == true
                  ? parsedData['merchant'].toString()
                  : 'Bank Debit';

          if (amount > 0) {
            print('💸 Auto-logging: ₹$amount at $merchant');
            onExpenseFound!(amount, merchant); // calls state.addManualSpend
          } else {
            print('⚠️ Parsed amount was 0 — skipping spend log');
          }
        } else {
          print('❌ AI could not parse this SMS');
        }
      },
      listenInBackground: false,
    );
  }

  Future<List<SmsMessage>> getRecentSms() async {
    try {
      List<SmsMessage> messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY],
      );
      return messages;
    } catch (e) {
      debugPrint("Failed to get SMS: $e");
      return [];
    }
  }
}
