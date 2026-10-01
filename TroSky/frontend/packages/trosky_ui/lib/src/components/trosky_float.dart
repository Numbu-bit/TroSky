import 'dart:async';

import 'package:flutter/widgets.dart';

import '../tokens/trosky_motion.dart';

/// `.anim-float`: moves [child] up [TroskyMotion.floatOffset] and back over
/// [TroskyMotion.floatDuration], ease-in-out each way, forever.
///
/// Like CSS `animation-delay`, the child rests in place for [delay] before the
/// first cycle. With reduce motion on it doesn't move.
class TroskyFloat extends StatefulWidget {
  const TroskyFloat({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<TroskyFloat> createState() => _TroskyFloatState();
}

class _TroskyFloatState extends State<TroskyFloat>
    with SingleTickerProviderStateMixin {
  // One half of the keyframes (0% → 50%); reversing gives the other half.
  late final AnimationController _half = AnimationController(
    vsync: this,
    duration: TroskyMotion.floatDuration ~/ 2,
  );
  late final Animation<double> _offset = CurvedAnimation(
    parent: _half,
    curve: TroskyMotion.easeInOut,
  );
  Timer? _delay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _delay?.cancel();
      _delay = null;
      _half.value = 0;
    } else if (!_half.isAnimating && _delay == null) {
      _delay = Timer(widget.delay, () => _half.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _half.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offset,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, TroskyMotion.floatOffset * _offset.value),
        child: child,
      ),
      child: widget.child,
    );
  }
}
