import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Service managing Google Mobile Ads initialization and ad unit configuration.
class AdService {
  AdService._();

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /// Android Production Banner Ad Unit ID provided by AdMob.
  static const String _prodBannerAdUnitIdAndroid =
      'ca-app-pub-2904067608447796/2439523085';

  /// Official Google Sample/Test Banner Ad Unit ID for Android.
  static const String _testBannerAdUnitIdAndroid =
      'ca-app-pub-3940256099942544/6300978111';

  /// Whether the current platform supports Mobile Ads SDK.
  static bool get isSupportedPlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Whether banner ads should be displayed for the given user role.
  /// Intentionally allows banner ads only for Student, CR, and SR roles.
  /// Explicitly excludes Faculty and any administrative roles.
  static bool shouldShowAdsForRole(dynamic role) {
    // Check against string representation or UserRole enum directly
    final roleStr = role?.toString().split('.').last.toLowerCase();
    return roleStr == 'student' || roleStr == 'cr' || roleStr == 'sr';
  }

  /// Banner Ad Unit ID based on the environment.
  /// Uses official Google test banner ID in debug/profile/test,
  /// and production ID strictly in release builds on Android.
  static String get bannerAdUnitId {
    if (kReleaseMode) {
      return _prodBannerAdUnitIdAndroid;
    }
    return _testBannerAdUnitIdAndroid;
  }

  static Future<void>? _initFuture;

  /// Initializes Google Mobile Ads SDK exactly once on supported platforms without blocking startup.
  static Future<void> initialize() {
    if (!isSupportedPlatform) {
      return Future.value();
    }
    if (_initFuture != null) {
      return _initFuture!;
    }

    _initFuture = _doInitialize();
    return _initFuture!;
  }

  static Future<void> _doInitialize() async {
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('[AdService] Mobile Ads SDK initialized successfully.');
    } catch (e) {
      debugPrint('[AdService] Mobile Ads initialization failed: $e');
    }
  }
}
