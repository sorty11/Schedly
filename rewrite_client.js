const fs = require('fs');

const code = `import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class NotificationApiClient {
  // Render free tier URL
  static const String _baseUrl = 'https://schedly-backend.onrender.com/api';

  static Future<void> wakeUpWorker() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final idToken = await user.getIdToken();
      if (idToken == null) return;

      await http.get(
        Uri.parse('\$_baseUrl/wake'),
        headers: {
          'Authorization': 'Bearer \$idToken',
        },
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      // Silently ignore ping failures. Worker will pick up next time it wakes.
      // Firestore batch already committed.
    }
  }

  // Obsolete - just a stub in case main.dart still calls it
  static Future<void> initOfflineQueue() async {
    // No longer needed
  }
}
`;

fs.writeFileSync('lib/services/notification_api_client.dart', code);
console.log('Rewrote notification_api_client.dart');
