const fs = require('fs');

let code = fs.readFileSync('lib/services/notification_service.dart', 'utf8');

// Add import
if (!code.includes("import 'topic_subscription_service.dart';")) {
    code = code.replace(
        "import 'package:shared_preferences/shared_preferences.dart';",
        "import 'package:shared_preferences/shared_preferences.dart';\nimport 'topic_subscription_service.dart';"
    );
}

// Replace updateDivisionSubscription
code = code.replace(/static Future<void> updateDivisionSubscription[\s\S]*?\}\n  \}/, `static Future<void> updateDivisionSubscription(String newDivision) async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? 'student';
    final batch = prefs.getString('selected_batch');
    await TopicSubscriptionService.updateSubscriptions(newDivision, role, batch: batch);
  }`);

// Update clearTokenOnLogout
code = code.replace(/static Future<void> clearTokenOnLogout[\s\S]*?\}\n  \}/, `static Future<void> clearTokenOnLogout() async {
    await TopicSubscriptionService.clearAllSubscriptions();
    try {
      final String? token = await messaging.getToken();
      final user = FirebaseAuth.instance.currentUser;
      if (token != null && user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('fcm_tokens')
            .doc(token)
            .delete();
      }
    } catch (e) {
      debugPrint('Failed to delete token on logout: $e');
    }
  }`);

fs.writeFileSync('lib/services/notification_service.dart', code);
console.log('Updated notification_service.dart');
