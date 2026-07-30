import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  /// Checks if the device has an active internet connection.
  static Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      // In some cases, it might return [none, wifi] if wifi is connected but no internet, 
      // but usually none means no active network interface.
      // Actually, if 'none' is the ONLY result, then we are offline.
      if (connectivityResult.length == 1) {
        return false;
      }
    }
    return connectivityResult.isNotEmpty;
  }
}
