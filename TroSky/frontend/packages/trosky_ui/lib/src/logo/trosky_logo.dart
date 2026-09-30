import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The TroSky logo, from the SVGs in design/assets.
///
/// The Figma Make code shows the logo from two raster images:
/// `troSkyLogoBright` (the full logo on the white splash card) and
/// `troSkyLogo` (the pin mark on its own, e.g. inside the QR code). This
/// widget draws the vector versions of both.
class TroskyLogo extends StatelessWidget {
  /// Full logo: pin mark, "TroSky" wordmark and tagline. Figma's
  /// `troSkyLogoBright`; the splash card shows it 200 px wide.
  const TroskyLogo.bright({super.key, this.width = 200, this.height})
    : _asset = 'assets/logo/trosky-logo.svg';

  /// Pin mark only. Figma's `troSkyLogo`, shown 20–36 px tall.
  const TroskyLogo.mark({super.key, required double this.height})
    : width = null,
      _asset = 'assets/logo/trosky-icon.svg';

  final double? width;
  final double? height;
  final String _asset;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _asset,
      package: 'trosky_ui',
      width: width,
      height: height,
      semanticsLabel: 'TroSky',
    );
  }
}
