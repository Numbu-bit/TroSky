import 'package:flutter/widgets.dart';

/// The TroSky logo, from the raster images in the Figma Make file (the
/// official logo; see docs/design-decisions.md).
///
/// TODO(logo): replace with designer-exported SVG.
class TroskyLogo extends StatelessWidget {
  /// Full logo on a white background. Figma's `troSkyLogoBright`
  /// (`Screenshot_2026-08-02_124000.png`); the splash card shows it 200 px
  /// wide.
  const TroskyLogo.bright({super.key, double this.width = 200})
    : height = null,
      _asset = brightAsset,
      _aspectRatio = _brightAspectRatio;

  /// Full logo on its dark background. Figma's `troSkyLogo`
  /// (`WhatsApp_Image_2026-07-29_at_16.20.47.jpeg`), shown 20–36 px tall.
  const TroskyLogo.mark({super.key, required double this.height})
    : width = null,
      _asset = smallAsset,
      _aspectRatio = _smallAspectRatio;

  /// Asset key of the bright logo, inside this package.
  static const String brightAsset = 'assets/logo/trosky_logo_bright.png';

  /// Asset key of the small logo, inside this package.
  static const String smallAsset = 'assets/logo/trosky_logo_small.jpg';

  static const String package = 'trosky_ui';

  // Pixel sizes of the images: 611 x 277 and 853 x 271. The box is sized
  // from these so the layout doesn't jump when the image finishes decoding.
  static const double _brightAspectRatio = 611 / 277;
  static const double _smallAspectRatio = 853 / 271;

  final double? width;
  final double? height;
  final String _asset;
  final double _aspectRatio;

  @override
  Widget build(BuildContext context) {
    final w = width ?? height! * _aspectRatio;
    final h = height ?? width! / _aspectRatio;
    return Image.asset(
      _asset,
      package: package,
      width: w,
      height: h,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'TroSky',
    );
  }
}
