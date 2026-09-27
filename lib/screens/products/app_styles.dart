import 'package:flutter/material.dart';

class AppStyles {
  AppStyles._();

  // Colors
  static const Color primaryColor = Colors.indigo;
  static const Color successColor = Colors.green;
  static const Color warningColor = Colors.orange;
  static const Color errorColor = Colors.red;
  static const Color backgroundColor = Color(0xfff5f6fa);
  static const Color cardColor = Colors.white;

  // Spacing
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 20.0;
  static const double spacingXxl = 24.0;

  // Border Radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 10.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;
  static const double radiusXxl = 18.0;

  // Card Elevation
  static const double elevationSm = 2.0;
  static const double elevationMd = 3.0;
  static const double elevationLg = 5.0;

  // Font Sizes
  static const double fontSizeXs = 11.0;
  static const double fontSizeSm = 12.0;
  static const double fontSizeMd = 13.0;
  static const double fontSizeLg = 14.0;
  static const double fontSizeXl = 18.0;
  static const double fontSizeXxl = 22.0;

  // Icon Sizes
  static const double iconSizeSm = 16.0;
  static const double iconSizeMd = 18.0;
  static const double iconSizeLg = 24.0;
  static const double iconSizeXl = 50.0;

  // Button Heights
  static const double buttonHeightSm = 36.0;
  static const double buttonHeightMd = 40.0;
  static const double buttonHeightLg = 48.0;

  // Input Field Heights
  static const double inputFieldHeight = 56.0;

  // Dialog Widths
  static const double dialogWidthSm = 420.0;
  static const double dialogWidthMd = 560.0;
  static const double dialogWidthLg = 600.0;

  // Card Aspect Ratios
  static const double cardAspectRatio = 0.78;

  // Table Dimensions
  static const double tableRowHeightMin = 48.0;
  static const double tableRowHeightMax = 52.0;
  static const double tableHeadingHeight = 42.0;
  static const double tableColumnSpacing = 16.0;
  static const double tableHorizontalMargin = 8.0;
  static const double tableDividerThickness = 0.5;

  // Grid Spacing
  static const double gridCrossAxisSpacing = 12.0;
  static const double gridMainAxisSpacing = 12.0;
  static const int gridCrossAxisCount = 2;

  // Animation Durations
  static const Duration animationDurationFast = Duration(milliseconds: 150);
  static const Duration animationDurationNormal = Duration(milliseconds: 200);
  static const Duration animationDurationSlow = Duration(milliseconds: 300);

  // Common Box Shadows
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get elevatedCardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  // Common InputDecoration
  static InputDecoration inputDecoration({
    required String labelText,
    required IconData prefixIcon,
    String? hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: Icon(prefixIcon),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: errorColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacingLg,
        vertical: spacingMd,
      ),
    );
  }

  // Common Card Decoration
  static BoxDecoration cardDecoration({
    Color? color,
    double? borderRadius,
    double? elevation,
  }) {
    return BoxDecoration(
      color: color ?? cardColor,
      borderRadius: BorderRadius.circular(borderRadius ?? radiusXl),
      boxShadow: elevation != null && elevation > elevationMd
          ? elevatedCardShadow
          : cardShadow,
    );
  }

  // Common Chip Decoration
  static BoxDecoration chipDecoration({
    required bool isSelected,
  }) {
    return BoxDecoration(
      color: isSelected ? primaryColor.withValues(alpha: 0.1) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(radiusXl),
      border: Border.all(
        color: isSelected ? primaryColor : Colors.grey.shade300,
        width: isSelected ? 2 : 1,
      ),
    );
  }
}
