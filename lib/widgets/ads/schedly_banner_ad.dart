import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../services/ad_service.dart';
import '../../app_settings.dart';
import '../../theme/theme.dart';

/// Isolated, reusable AdMob banner ad widget for Schedly.
/// Gracefully handles failure by collapsing to [SizedBox.shrink],
/// ensures safe disposal, and never executes Mobile Ads on Web.
class SchedlyBannerAd extends StatefulWidget {
  final AdSize adSize;
  final EdgeInsetsGeometry? margin;

  const SchedlyBannerAd({
    super.key,
    this.adSize = AdSize.banner,
    this.margin,
  });

  @override
  State<SchedlyBannerAd> createState() => _SchedlyBannerAdState();
}

class _SchedlyBannerAdState extends State<SchedlyBannerAd> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _hasFailed = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[SchedlyBannerAd] initState called (key: ${widget.key}, adUnitId: ${AdService.bannerAdUnitId}, role: ${AppSettings.currentRole})');
    _loadAd();
  }

  Future<void> _loadAd() async {
    if (!AdService.isSupportedPlatform) {
      debugPrint('[SchedlyBannerAd] Not supported platform, skipping load.');
      return;
    }

    if (!AdService.shouldShowAdsForRole(AppSettings.currentRole)) {
      debugPrint('[SchedlyBannerAd] Ads not enabled for role ${AppSettings.currentRole}, skipping load.');
      return;
    }

    // Ensure SDK initialization has finished in the background before requesting an ad
    await AdService.initialize();
    if (!mounted) return;

    debugPrint('[SchedlyBannerAd] Initiating BannerAd creation and load()...');
    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: widget.adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          final banner = ad as BannerAd;
          debugPrint('[SchedlyBannerAd] onAdLoaded fired successfully! Size: ${banner.size.width}x${banner.size.height}');
          if (!mounted) {
            debugPrint('[SchedlyBannerAd] Widget unmounted before onAdLoaded completed, disposing ad.');
            ad.dispose();
            return;
          }
          setState(() {
            _isAdLoaded = true;
            _hasFailed = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[SchedlyBannerAd] onAdFailedToLoad fired! Code: ${error.code}, Domain: ${error.domain}, Message: ${error.message}, ResponseInfo: ${error.responseInfo}');
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _isAdLoaded = false;
            _hasFailed = true;
          });
        },
        onAdOpened: (ad) => debugPrint('[SchedlyBannerAd] onAdOpened'),
        onAdClosed: (ad) => debugPrint('[SchedlyBannerAd] onAdClosed'),
        onAdImpression: (ad) => debugPrint('[SchedlyBannerAd] onAdImpression recorded!'),
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdService.isSupportedPlatform ||
        !AdService.shouldShowAdsForRole(AppSettings.currentRole) ||
        _hasFailed ||
        !_isAdLoaded ||
        _bannerAd == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sem = Theme.of(context).extension<AppSemanticColors>();

    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2l,
        vertical: AppSpacing.sm,
      ),
      alignment: Alignment.center,
      child: Container(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: sem?.borderSubtle ?? Colors.grey.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
