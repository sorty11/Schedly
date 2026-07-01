import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:schedly/theme/theme.dart';

class AnimatedNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AnimatedNavigationDestination> destinations;
  final Color? backgroundColor;

  const AnimatedNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? theme.colorScheme.surface.withValues(alpha: 0.8),
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(destinations.length, (index) {
                  return Expanded(
                    child: AnimatedNavigationItem(
                      destination: destinations[index],
                      isSelected: selectedIndex == index,
                      onTap: () {
                        if (selectedIndex != index) {
                          onDestinationSelected(index);
                        }
                      },
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedNavigationDestination {
  final Widget icon;
  final Widget? selectedIcon;
  final String label;

  const AnimatedNavigationDestination({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });
}

class AnimatedNavigationItem extends StatefulWidget {
  final AnimatedNavigationDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  const AnimatedNavigationItem({
    super.key,
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<AnimatedNavigationItem> createState() => _AnimatedNavigationItemState();
}

class _AnimatedNavigationItemState extends State<AnimatedNavigationItem> with TickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressScaleAnimation;
  
  late AnimationController _hoverController;

  @override
  void initState() {
    super.initState();
    
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 400),
    );

    _pressScaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic, reverseCurve: Curves.elasticOut),
    );

    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    _hoverController.dispose();
    super.dispose();
  }

  void _handleTapDown(_) {
    HapticFeedback.lightImpact();
    _pressController.forward();
  }

  void _handleTapUp(_) {
    _pressController.reverse();
  }
  
  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = widget.isSelected;
    
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.onSurfaceVariant;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hoverController.forward(),
      onExit: (_) => _hoverController.reverse(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_pressController, _hoverController]),
          builder: (context, child) {
            final hoverScale = 1.0 + (_hoverController.value * 0.05);
            final currentScale = _pressScaleAnimation.value * hoverScale;
            
            final targetColor = isSelected ? activeColor : inactiveColor;
            
            return Transform.scale(
              scale: currentScale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? activeColor.withValues(alpha: 0.15)
                        : activeColor.withValues(alpha: 0.05 * _hoverController.value),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: IconTheme.merge(
                      data: IconThemeData(
                        color: targetColor,
                        size: 26,
                      ),
                      child: (isSelected && widget.destination.selectedIcon != null)
                          ? widget.destination.selectedIcon!
                          : widget.destination.icon,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? activeColor : Colors.transparent, // Fade text in/out
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      height: isSelected ? 16 : 0, // Spring expand label
                      child: Text(widget.destination.label),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
