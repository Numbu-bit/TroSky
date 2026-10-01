import 'package:flutter/widgets.dart';

import 'page_dots.dart';

/// The splash dots ([PageDots.splash]) used as a loading indicator: the white
/// dot steps from the first dot to the last, one step every [step], and
/// starts over.
///
/// The design draws the dots still, with the first one white. With reduce
/// motion on (`MediaQuery.disableAnimations`) they stay that way.
class LoadingDots extends StatefulWidget {
  const LoadingDots({
    super.key,
    required this.step,
    required this.semanticsLabel,
    this.count = 3,
  });

  /// Time the white dot stays on each dot.
  final Duration step;

  /// What a screen reader announces, e.g. "Loading".
  final String semanticsLabel;

  final int count;

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: widget.step * widget.count,
  )..addListener(_onTick);

  int _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(LoadingDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cycle.duration = widget.step * widget.count;
    _syncMotion();
  }

  void _syncMotion() {
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reset the index first so the listener has nothing to rebuild: this
      // runs during build. Setting the value also stops the controller.
      _index = 0;
      _cycle.value = 0;
    } else if (!_cycle.isAnimating) {
      _cycle.repeat();
    }
  }

  void _onTick() {
    final index = (_cycle.value * widget.count).floor().clamp(
      0,
      widget.count - 1,
    );
    if (index != _index) setState(() => _index = index);
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticsLabel,
      excludeSemantics: true,
      child: PageDots.splash(count: widget.count, index: _index),
    );
  }
}
