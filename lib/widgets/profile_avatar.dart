import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/profile_photo_service.dart';
import '../theme/theme.dart';

class ProfileAvatar extends StatefulWidget {
  final String initial;
  final double size;
  final VoidCallback? onPhotoChanged;

  const ProfileAvatar({
    super.key,
    required this.initial,
    this.size = 80.0,
    this.onPhotoChanged,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  bool _isUploading = false;
  String? _currentPhotoUrl;

  @override
  void initState() {
    super.initState();
    _currentPhotoUrl = ProfilePhotoService.currentPhotoUrl;
    _syncPhoto();
  }

  Future<void> _syncPhoto() async {
    final remoteUrl = await ProfilePhotoService.fetchPhotoUrl();
    if (mounted && remoteUrl != _currentPhotoUrl) {
      setState(() => _currentPhotoUrl = remoteUrl);
    }
  }

  Future<void> _openPhotoOptions(BuildContext context) async {
    HapticFeedback.lightImpact();
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final hasPhoto = _currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: sem.surfaceElevated,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.x2l),
            ),
            border: Border.all(color: sem.borderSubtle, width: 1),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.x2l,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: sem.onSurfaceMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),

                // Title
                Text(
                  'Change Profile Photo',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Choose an option to update your avatar',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: sem.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // 1. Choose from Gallery
                _PhotoOptionTile(
                  icon: Icons.photo_library_rounded,
                  title: 'Choose from Gallery',
                  colorScheme: colorScheme,
                  sem: sem,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickPhoto(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),

                // 2. Take Photo
                _PhotoOptionTile(
                  icon: Icons.camera_alt_rounded,
                  title: 'Take Photo',
                  colorScheme: colorScheme,
                  sem: sem,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickPhoto(ImageSource.camera);
                  },
                ),

                // 3. Remove Photo (Only when a photo exists)
                if (hasPhoto) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _PhotoOptionTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Remove Photo',
                    isDestructive: true,
                    colorScheme: colorScheme,
                    sem: sem,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _deletePhoto();
                    },
                  ),
                ],

                const SizedBox(height: AppSpacing.md),

                // 4. Cancel
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.onSurface,
                      side: BorderSide(color: sem.borderSubtle),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _isUploading = true);
    try {
      final newUrl = await ProfilePhotoService.pickAndUploadPhoto(
        source: source,
      );
      if (mounted) {
        if (newUrl != null) {
          setState(() => _currentPhotoUrl = newUrl);
          widget.onPhotoChanged?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo updated successfully.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deletePhoto() async {
    setState(() => _isUploading = true);
    try {
      await ProfilePhotoService.removePhoto();
      if (mounted) {
        setState(() => _currentPhotoUrl = null);
        widget.onPhotoChanged?.call();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo removed.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove profile photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Widget _buildAvatarContent(ColorScheme colorScheme, AppSemanticColors sem) {
    final photoUrl = _currentPhotoUrl;

    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('data:image')) {
        try {
          final base64Part = photoUrl.split(',')[1];
          final Uint8List bytes = base64Decode(base64Part);
          return Image.memory(
            bytes,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _buildFallbackInitial(colorScheme, sem),
          );
        } catch (_) {
          return _buildFallbackInitial(colorScheme, sem);
        }
      }

      return Image.network(
        photoUrl,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackInitial(colorScheme, sem),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
          );
        },
      );
    }

    return _buildFallbackInitial(colorScheme, sem);
  }

  Widget _buildFallbackInitial(ColorScheme colorScheme, AppSemanticColors sem) {
    return Center(
      child: Text(
        widget.initial.isNotEmpty ? widget.initial.toUpperCase() : 'U',
        style: GoogleFonts.outfit(
          fontSize: widget.size * 0.42,
          fontWeight: FontWeight.w700,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Circular Avatar Container
          GestureDetector(
            onTap: _isUploading ? null : () => _openPhotoOptions(context),
            child: AnimatedContainer(
              duration: AppDuration.standard,
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? sem.surfaceElevated2
                    : colorScheme.primary.withValues(alpha: 0.08),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.22),
                  width: 2.0,
                ),
              ),
              child: ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildAvatarContent(colorScheme, sem),

                    // Loading overlay
                    if (_isUploading)
                      Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Edit / Camera Badge Overlay (bottom-right)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _isUploading ? null : () => _openPhotoOptions(context),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary,
                  border: Border.all(color: sem.surfaceElevated, width: 2.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDestructive;
  final ColorScheme colorScheme;
  final AppSemanticColors sem;
  final VoidCallback onTap;

  const _PhotoOptionTile({
    required this.icon,
    required this.title,
    this.isDestructive = false,
    required this.colorScheme,
    required this.sem,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = isDestructive ? colorScheme.error : colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isDestructive
                  ? colorScheme.error.withValues(alpha: 0.25)
                  : sem.borderSubtle,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? colorScheme.error.withValues(alpha: 0.1)
                      : colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isDestructive
                      ? colorScheme.error
                      : colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: itemColor,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: sem.onSurfaceMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
