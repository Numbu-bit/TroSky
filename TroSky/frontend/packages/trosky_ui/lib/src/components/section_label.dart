import 'package:flutter/widgets.dart';

import '../tokens/trosky_colors.dart';
import '../tokens/trosky_typography.dart';

/// Small upper-case field label, "PHONE NUMBER" on Sign Up: Inter 12/600,
/// letter-spacing 0.04em, secondary text colour. The design writes the text
/// in capitals, so pass it that way.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TroskyTypography.body12SemiBoldLs4.copyWith(
        color: TroskyColors.textSecondary,
      ),
    );
  }
}
