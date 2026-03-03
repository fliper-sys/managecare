import 'package:flutter/material.dart';

/// Mobile optimization utilities for responsive design
class MobileOptimization {
  /// Get screen size category
  static ScreenCategory getScreenCategory(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 360) {
      return ScreenCategory.small;
    } else if (width < 600) {
      return ScreenCategory.medium;
    } else if (width < 900) {
      return ScreenCategory.large;
    } else {
      return ScreenCategory.xlarge;
    }
  }

  /// Check if device is in landscape
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Check if device is in portrait
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  /// Get safe area padding
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// Get responsive padding
  static double getResponsivePadding(BuildContext context) {
    final category = getScreenCategory(context);
    switch (category) {
      case ScreenCategory.small:
        return 8;
      case ScreenCategory.medium:
        return 12;
      case ScreenCategory.large:
        return 16;
      case ScreenCategory.xlarge:
        return 20;
    }
  }

  /// Get responsive font size
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    final category = getScreenCategory(context);
    switch (category) {
      case ScreenCategory.small:
        return baseSize * 0.85;
      case ScreenCategory.medium:
        return baseSize * 0.9;
      case ScreenCategory.large:
        return baseSize;
      case ScreenCategory.xlarge:
        return baseSize * 1.1;
    }
  }

  /// Get responsive icon size
  static double getResponsiveIconSize(BuildContext context,
      {double small = 20, double medium = 24, double large = 28}) {
    final category = getScreenCategory(context);
    switch (category) {
      case ScreenCategory.small:
        return small;
      case ScreenCategory.medium:
        return medium;
      case ScreenCategory.large:
        return large;
      case ScreenCategory.xlarge:
        return large * 1.1;
    }
  }

  /// Get cross axis count for grid
  static int getCrossAxisCount(BuildContext context) {
    final category = getScreenCategory(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    switch (category) {
      case ScreenCategory.small:
        return isLandscape ? 3 : 2;
      case ScreenCategory.medium:
        return isLandscape ? 4 : 2;
      case ScreenCategory.large:
        return isLandscape ? 4 : 3;
      case ScreenCategory.xlarge:
        return isLandscape ? 6 : 4;
    }
  }

  /// Get button height based on screen size
  static double getButtonHeight(BuildContext context) {
    final category = getScreenCategory(context);
    switch (category) {
      case ScreenCategory.small:
        return 40;
      case ScreenCategory.medium:
        return 44;
      case ScreenCategory.large:
        return 48;
      case ScreenCategory.xlarge:
        return 52;
    }
  }

  /// Get card border radius
  static double getCardBorderRadius(BuildContext context) {
    final category = getScreenCategory(context);
    switch (category) {
      case ScreenCategory.small:
        return 8;
      case ScreenCategory.medium:
        return 12;
      case ScreenCategory.large:
        return 16;
      case ScreenCategory.xlarge:
        return 20;
    }
  }

  /// Get optimal list item height
  static double getListItemHeight(BuildContext context) {
    final category = getScreenCategory(context);
    switch (category) {
      case ScreenCategory.small:
        return 60;
      case ScreenCategory.medium:
        return 70;
      case ScreenCategory.large:
        return 80;
      case ScreenCategory.xlarge:
        return 90;
    }
  }

  /// Check if should show side-by-side layout
  static bool shouldShowSideLayout(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 900;
  }

  /// Get optimal grid spacing
  static double getGridSpacing(BuildContext context) {
    final category = getScreenCategory(context);
    switch (category) {
      case ScreenCategory.small:
        return 8;
      case ScreenCategory.medium:
        return 10;
      case ScreenCategory.large:
        return 12;
      case ScreenCategory.xlarge:
        return 16;
    }
  }
}

enum ScreenCategory {
  small, // < 360
  medium, // 360 - 599
  large, // 600 - 899
  xlarge, // >= 900
}

/// Responsive widget builder
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext) smallScreen;
  final Widget Function(BuildContext) mediumScreen;
  final Widget Function(BuildContext)? largeScreen;
  final Widget Function(BuildContext)? xlargeScreen;

  const ResponsiveBuilder({
    super.key,
    required this.smallScreen,
    required this.mediumScreen,
    this.largeScreen,
    this.xlargeScreen,
  });

  @override
  Widget build(BuildContext context) {
    final category = MobileOptimization.getScreenCategory(context);

    switch (category) {
      case ScreenCategory.small:
        return smallScreen(context);
      case ScreenCategory.medium:
        return mediumScreen(context);
      case ScreenCategory.large:
        return largeScreen?.call(context) ?? mediumScreen(context);
      case ScreenCategory.xlarge:
        return xlargeScreen?.call(context) ??
            largeScreen?.call(context) ??
            mediumScreen(context);
    }
  }
}

/// Adaptive column that switches to row on large screens
class AdaptiveColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  const AdaptiveColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    if (MobileOptimization.shouldShowSideLayout(context)) {
      return Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: children
            .asMap()
            .entries
            .map((entry) => Expanded(child: entry.value))
            .toList(),
      );
    }

    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }
}

/// Safe area with responsive padding
class ResponsiveSafeArea extends StatelessWidget {
  final Widget child;
  final bool left;
  final bool right;
  final bool top;
  final bool bottom;

  const ResponsiveSafeArea({
    super.key,
    required this.child,
    this.left = true,
    this.right = true,
    this.top = true,
    this.bottom = true,
  });

  @override
  Widget build(BuildContext context) {
    final padding = MobileOptimization.getResponsivePadding(context);

    return Padding(
      padding: EdgeInsets.only(
        left: left ? padding : 0,
        right: right ? padding : 0,
        top: top ? padding : 0,
        bottom: bottom ? padding : 0,
      ),
      child: child,
    );
  }
}

/// Touch-friendly button with minimum tap area
class TouchFriendlyButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final double? elevation;

  const TouchFriendlyButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final buttonHeight = MobileOptimization.getButtonHeight(context);
    final finalPadding = padding ?? const EdgeInsets.symmetric(horizontal: 16);

    return Padding(
      padding: finalPadding,
      child: SizedBox(
        height: buttonHeight,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            elevation: elevation ?? 2,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Touch-friendly icon button
class TouchFriendlyIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String tooltip;
  final Color? color;

  const TouchFriendlyIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color?.withOpacity(0.1),
          ),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Tooltip(
                message: tooltip,
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Adaptive spacing widget
class AdaptiveSpacing extends StatelessWidget {
  final double smallHeight;
  final double? mediumHeight;
  final double? largeHeight;

  const AdaptiveSpacing({
    super.key,
    this.smallHeight = 12,
    this.mediumHeight,
    this.largeHeight,
  });

  @override
  Widget build(BuildContext context) {
    final category = MobileOptimization.getScreenCategory(context);
    double height = smallHeight;

    switch (category) {
      case ScreenCategory.small:
        height = smallHeight;
        break;
      case ScreenCategory.medium:
        height = mediumHeight ?? smallHeight;
        break;
      case ScreenCategory.large:
        height = largeHeight ?? mediumHeight ?? smallHeight;
        break;
      case ScreenCategory.xlarge:
        height = largeHeight ?? mediumHeight ?? smallHeight;
        break;
    }

    return SizedBox(height: height);
  }
}

