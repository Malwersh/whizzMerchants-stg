import 'package:flutter/material.dart';

class ModernFloatingActionButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String tooltip;
  final IconData icon;
  final String? label;
  final bool isExtended;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const ModernFloatingActionButton({
    super.key,
    this.onPressed,
    required this.tooltip,
    required this.icon,
    this.label,
    this.isExtended = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<ModernFloatingActionButton> createState() =>
      _ModernFloatingActionButtonState();
}

class _ModernFloatingActionButtonState extends State<ModernFloatingActionButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rippleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveBackgroundColor =
        widget.backgroundColor ?? colorScheme.primaryContainer;
    final effectiveForegroundColor =
        widget.foregroundColor ?? colorScheme.onPrimaryContainer;

    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _rippleAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Stack(
            children: [
              // Main FAB
              FloatingActionButton.extended(
                onPressed: widget.onPressed,
                tooltip: widget.tooltip,
                backgroundColor: effectiveBackgroundColor,
                foregroundColor: effectiveForegroundColor,
                elevation: 6,
                highlightElevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(widget.isExtended ? 24 : 16),
                ),
                icon: Icon(widget.icon, size: 24),
                label: widget.isExtended && widget.label != null
                    ? Text(
                        widget.label!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Ripple effect overlay
              if (_rippleAnimation.value > 0)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(widget.isExtended ? 24 : 16),
                      color: Colors.white.withValues(
                        alpha: 0.3 * (1 - _rippleAnimation.value),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class ModernFABWithMenu extends StatefulWidget {
  final List<FABMenuItem> menuItems;
  final IconData mainIcon;
  final String mainTooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const ModernFABWithMenu({
    super.key,
    required this.menuItems,
    required this.mainIcon,
    required this.mainTooltip,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<ModernFABWithMenu> createState() => _ModernFABWithMenuState();
}

class _ModernFABWithMenuState extends State<ModernFABWithMenu>
    with TickerProviderStateMixin {
  late AnimationController _menuController;
  late Animation<double> _menuAnimation;
  late Animation<double> _rotationAnimation;
  bool _isMenuOpen = false;

  @override
  void initState() {
    super.initState();

    _menuController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _menuAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _menuController,
      curve: Curves.easeOutBack,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125, // 45 degrees
    ).animate(CurvedAnimation(
      parent: _menuController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });

    if (_isMenuOpen) {
      _menuController.forward();
    } else {
      _menuController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // Backdrop when menu is open
        if (_isMenuOpen)
          GestureDetector(
            onTap: _toggleMenu,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),

        // Menu items
        ...widget.menuItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          return AnimatedBuilder(
            animation: _menuAnimation,
            builder: (context, child) {
              final offset = (index + 1) * 70.0 * _menuAnimation.value;

              return Positioned(
                bottom: 80 + offset,
                right: 16,
                child: Transform.scale(
                  scale: _menuAnimation.value,
                  child: Opacity(
                    opacity: _menuAnimation.value,
                    child: _buildMenuItem(item, colorScheme),
                  ),
                ),
              );
            },
          );
        }),

        // Main FAB
        Positioned(
          bottom: 16,
          right: 16,
          child: AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationAnimation.value * 2 * 3.14159,
                child: FloatingActionButton(
                  onPressed: _toggleMenu,
                  tooltip: widget.mainTooltip,
                  backgroundColor:
                      widget.backgroundColor ?? colorScheme.primaryContainer,
                  foregroundColor:
                      widget.foregroundColor ?? colorScheme.onPrimaryContainer,
                  elevation: 8,
                  child: Icon(
                    _isMenuOpen ? Icons.close : widget.mainIcon,
                    size: 24,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(FABMenuItem item, ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            item.label,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Mini FAB
        FloatingActionButton.small(
          onPressed: () {
            _toggleMenu();
            item.onTap();
          },
          tooltip: item.tooltip,
          backgroundColor:
              item.backgroundColor ?? colorScheme.secondaryContainer,
          foregroundColor:
              item.foregroundColor ?? colorScheme.onSecondaryContainer,
          child: Icon(item.icon, size: 20),
        ),
      ],
    );
  }
}

class FABMenuItem {
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const FABMenuItem({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.backgroundColor,
    this.foregroundColor,
  });
}
