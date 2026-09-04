import 'package:flutter/widgets.dart';
import '../../user_roles.dart';

class WhatsNewFeature {
  final String title;
  final String description;
  final IconData icon;
  final String? tag; // e.g., "NEW", "UPGRADED", "PERFORMANCE"
  final UserRole? roleTarget; // null if universal

  const WhatsNewFeature({
    required this.title,
    required this.description,
    required this.icon,
    this.tag,
    this.roleTarget,
  });
}

class WhatsNewRelease {
  final int buildNumber;
  final String versionName;
  final String heroTitle;
  final String heroSubtitle;
  final List<WhatsNewFeature> features;

  const WhatsNewRelease({
    required this.buildNumber,
    required this.versionName,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.features,
  });
}

