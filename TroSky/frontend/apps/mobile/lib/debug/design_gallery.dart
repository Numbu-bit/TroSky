import 'package:flutter/material.dart';
import 'package:trosky_ui/trosky_ui.dart';

/// Debug-only page at `/_gallery` showing every trosky_ui component in every
/// state and every design token.
class DesignGallery extends StatelessWidget {
  const DesignGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Design gallery',
          style: TroskyTypography.heading17Bold.copyWith(
            color: TroskyColors.textPrimary,
          ),
        ),
      ),
      body: DefaultTextStyle(
        style: TroskyTypography.body12Regular.copyWith(
          color: TroskyColors.textPrimary,
        ),
        child: ListView(
          key: const ValueKey('gallery-list'),
          padding: const EdgeInsets.only(bottom: 48),
          children: const [
            _Section('Buttons', _Buttons()),
            _Section('Page dots', _Dots()),
            _Section('Skip', _Skip()),
            _Section('Chips', _Chips()),
            _Section('Section label', _Labels()),
            _Section('Logo', _Logos()),
            _Section('Decorative backdrops', _Backdrops()),
            _Section('Colours', _Colours()),
            _Section('Gradients', _Gradients()),
            _Section('Typography', _Typography()),
            _Section('Shadows', _Shadows()),
            _Section('Radii', _Radii()),
            _Section('Spacing', _Spacing()),
            _Section('Borders and opacity', _BordersOpacity()),
            _Section('Motion', _Motion(), key: ValueKey('gallery-motion')),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.child, {super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TroskyTypography.heading20ExtraBold.copyWith(
              color: TroskyColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Caption under a sample, in secondary text.
class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TroskyTypography.body11Regular.copyWith(
        color: TroskyColors.textSecondary,
      ),
    );
  }
}

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

// Components

class _Buttons extends StatelessWidget {
  const _Buttons();

  @override
  Widget build(BuildContext context) {
    final rows = <(String, TroskyButtonVariant, Gradient?, Widget?)>[
      (
        'onboardingLight · Onboarding 1',
        TroskyButtonVariant.onboardingLight,
        TroskyGradients.onboarding1,
        null,
      ),
      (
        'onboardingGreen · Onboarding 2',
        TroskyButtonVariant.onboardingGreen,
        TroskyGradients.onboarding2,
        null,
      ),
      (
        'amber · Onboarding 3',
        TroskyButtonVariant.amber,
        TroskyGradients.onboarding3,
        null,
      ),
      ('primary · Sign Up', TroskyButtonVariant.primary, null, null),
      (
        'outline · Sign Up',
        TroskyButtonVariant.outline,
        null,
        TroskyIcons.mail(color: TroskyColors.textPrimary),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (name, variant, gradient, leading) in rows) ...[
          _Caption(name),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: gradient,
              color: gradient == null ? TroskyColors.background : null,
              borderRadius: BorderRadius.circular(TroskyRadii.r16),
            ),
            child: Column(
              children: [
                TroskyButton(
                  label: 'Enabled',
                  variant: variant,
                  leading: leading,
                  onPressed: () {},
                ),
                const SizedBox(height: 16),
                TroskyButton(
                  label: 'Pressed',
                  variant: variant,
                  leading: leading,
                  pressed: true,
                  onPressed: () {},
                ),
                const SizedBox(height: 16),
                TroskyButton(
                  label: 'Disabled',
                  variant: variant,
                  leading: leading,
                  onPressed: null,
                ),
                const SizedBox(height: 16),
                TroskyButton(
                  label: 'Loading',
                  variant: variant,
                  loading: true,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _Dots extends StatefulWidget {
  const _Dots();

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final gradient = [
      TroskyGradients.onboarding1,
      TroskyGradients.onboarding2,
      TroskyGradients.onboarding3,
    ][_page];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Caption('Onboarding: tap to move to the next page'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _page = (_page + 1) % 3),
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(gradient: gradient),
            child: PageDots.onboarding(
              index: _page,
              inactiveColor: _page == 0
                  ? TroskyColors.whiteA30
                  : TroskyColors.whiteA25,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _Caption('Splash loading dots'),
        const SizedBox(height: 8),
        Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(gradient: TroskyGradients.splash),
          child: const PageDots.splash(),
        ),
      ],
    );
  }
}

class _Skip extends StatelessWidget {
  const _Skip();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(gradient: TroskyGradients.onboarding1),
          child: SkipText(onPressed: () {}),
        ),
        Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(gradient: TroskyGradients.onboarding2),
          child: SkipText(onPressed: () {}, color: TroskyColors.whiteA55),
        ),
      ],
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final color in TroskyChipColor.values)
          TroskyChip(label: color.name, color: color),
      ],
    );
  }
}

class _Labels extends StatelessWidget {
  const _Labels();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: SectionLabel('PHONE NUMBER'),
    );
  }
}

class _Logos extends StatelessWidget {
  const _Logos();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: TroskyGradients.splash),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
            decoration: BoxDecoration(
              color: TroskyColors.surface,
              borderRadius: BorderRadius.circular(TroskyRadii.r32),
              boxShadow: TroskyShadows.splashLogoCard,
            ),
            child: const TroskyLogo.bright(),
          ),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TroskyLogo.mark(height: 20),
              SizedBox(width: 16),
              TroskyLogo.mark(height: 28),
              SizedBox(width: 16),
              TroskyLogo.mark(height: 36),
            ],
          ),
        ],
      ),
    );
  }
}

class _Backdrops extends StatelessWidget {
  const _Backdrops();

  @override
  Widget build(BuildContext context) {
    final screens = <(String, Gradient, Widget?)>[
      ('Splash', TroskyGradients.splash, const DecorativeBackdrop.splash()),
      (
        'Onboarding 1',
        TroskyGradients.onboarding1,
        const DecorativeBackdrop.onboarding1(),
      ),
      (
        'Onboarding 2',
        TroskyGradients.onboarding2,
        const DecorativeBackdrop.onboarding2(),
      ),
      ('Onboarding 3', TroskyGradients.onboarding3, null),
    ];
    return SizedBox(
      height: 380,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: screens.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final (name, gradient, backdrop) = screens[i];
          return Column(
            children: [
              // The 312 x 686 design screen at half size.
              SizedBox(
                width: 156,
                height: 343,
                child: FittedBox(
                  child: SizedBox(
                    width: 312,
                    height: 686,
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: gradient),
                      child: backdrop,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _Caption(name),
            ],
          );
        },
      ),
    );
  }
}

// Tokens

class _Colours extends StatelessWidget {
  const _Colours();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 12,
      children: [
        for (final MapEntry(key: name, value: color)
            in TroskyColors.all.entries)
          SizedBox(
            width: 104,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkerboard-free: translucent colours sit on navy/white
                // halves so their alpha is visible.
                SizedBox(
                  height: 40,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ColoredBox(
                          color: TroskyColors.surface,
                          child: ColoredBox(color: color),
                        ),
                      ),
                      Expanded(
                        child: ColoredBox(
                          color: TroskyColors.navy,
                          child: ColoredBox(color: color),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(name, style: TroskyTypography.body10SemiBold),
                _Caption(_hex(color)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Gradients extends StatelessWidget {
  const _Gradients();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final MapEntry(key: name, value: gradient)
            in TroskyGradients.all.entries) ...[
          Container(
            height: 96,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(TroskyRadii.r12),
            ),
          ),
          const SizedBox(height: 4),
          _Caption(name),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _Typography extends StatelessWidget {
  const _Typography();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final MapEntry(key: name, value: style)
            in TroskyTypography.all.entries) ...[
          _Caption(name),
          Text(
            'Book a Seat, Not a Whole Car · ₵6.00',
            style: style.copyWith(color: TroskyColors.textPrimary),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _Shadows extends StatelessWidget {
  const _Shadows();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 24,
      children: [
        for (final MapEntry(key: name, value: shadow)
            in TroskyShadows.all.entries)
          Container(
            width: 150,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TroskyColors.surface,
              borderRadius: BorderRadius.circular(TroskyRadii.r14),
              boxShadow: shadow,
            ),
            child: _Caption(name),
          ),
      ],
    );
  }
}

class _Radii extends StatelessWidget {
  const _Radii();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final MapEntry(key: name, value: radius)
            in TroskyRadii.all.entries)
          Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: TroskyColors.greenLight,
                  border: Border.all(color: TroskyColors.green),
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
              _Caption(name),
            ],
          ),
      ],
    );
  }
}

class _Spacing extends StatelessWidget {
  const _Spacing();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final MapEntry(key: name, value: space)
            in TroskySpacing.all.entries)
          Row(
            children: [
              SizedBox(width: 56, child: _Caption(name)),
              Container(
                width: space.abs(),
                height: 10,
                color: space < 0 ? TroskyColors.red : TroskyColors.blue,
              ),
            ],
          ),
      ],
    );
  }
}

class _BordersOpacity extends StatelessWidget {
  const _BordersOpacity();

  @override
  Widget build(BuildContext context) {
    const widths = [
      TroskyBorders.w1,
      TroskyBorders.w1p5,
      TroskyBorders.w2,
      TroskyBorders.w2p5,
      TroskyBorders.w3,
      TroskyBorders.w4,
    ];
    const opacities = [
      TroskyOpacity.o15,
      TroskyOpacity.o30,
      TroskyOpacity.o50,
      TroskyOpacity.seatTaken,
      TroskyOpacity.disabled,
      TroskyOpacity.o90,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          children: [
            for (final width in widths)
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: TroskyColors.navy, width: width),
                  borderRadius: BorderRadius.circular(TroskyRadii.r12),
                ),
                child: _Caption('$width'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: [
            for (final opacity in opacities)
              Column(
                children: [
                  Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 48,
                      height: 48,
                      color: TroskyColors.green,
                    ),
                  ),
                  _Caption('$opacity'),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _Motion extends StatefulWidget {
  const _Motion();

  @override
  State<_Motion> createState() => _MotionState();
}

class _MotionState extends State<_Motion> with TickerProviderStateMixin {
  // Keyframe animations that loop 0% -> 50% -> 100% run each half with the
  // CSS timing function, which is a reversing controller in Flutter.
  late final _pulse = AnimationController(
    vsync: this,
    duration: TroskyMotion.pulseDuration ~/ 2,
  );
  late final _float = AnimationController(
    vsync: this,
    duration: TroskyMotion.floatDuration ~/ 2,
  );
  late final _slide = AnimationController(
    vsync: this,
    duration: TroskyMotion.slideUpDuration,
  );
  late final _price = AnimationController(
    vsync: this,
    duration: TroskyMotion.priceFlashDuration,
  );
  bool _toggled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _float.stop();
    } else {
      _pulse.repeat(reverse: true);
      _float.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _float.dispose();
    _slide.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pulse = CurvedAnimation(
      parent: _pulse,
      curve: TroskyMotion.easeInOut,
    );
    final float = CurvedAnimation(
      parent: _float,
      curve: TroskyMotion.easeInOut,
    );
    final slide = CurvedAnimation(
      parent: _slide,
      curve: TroskyMotion.slideUpCurve,
    );
    final price = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: TroskyMotion.ease)),
        weight: TroskyMotion.priceFlashPeak,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: TroskyMotion.ease)),
        weight: 1 - TroskyMotion.priceFlashPeak,
      ),
    ]).animate(_price);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Caption('pulse-dot · 2s ease-in-out infinite'),
        SizedBox(
          height: 48,
          child: Center(
            child: AnimatedBuilder(
              animation: pulse,
              builder: (context, _) => Transform.scale(
                scale: Tween(
                  begin: TroskyMotion.pulseScaleFrom,
                  end: TroskyMotion.pulseScaleTo,
                ).evaluate(pulse),
                child: Opacity(
                  opacity: Tween(
                    begin: TroskyMotion.pulseOpacityFrom,
                    end: TroskyMotion.pulseOpacityTo,
                  ).evaluate(pulse),
                  child: const DecorativeCircle.filled(
                    diameter: 14,
                    color: TroskyColors.green,
                  ),
                ),
              ),
            ),
          ),
        ),
        const _Caption('float · 3s ease-in-out infinite, 0 → -6 px'),
        SizedBox(
          height: 48,
          child: Center(
            child: AnimatedBuilder(
              animation: float,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, TroskyMotion.floatOffset * float.value),
                child: child,
              ),
              child: const TroskyLogo.mark(height: 32),
            ),
          ),
        ),
        const _Caption('slide-up · 0.4s cubic-bezier(0.16,1,0.3,1) · tap'),
        GestureDetector(
          onTap: () => _slide.forward(from: 0),
          child: SizedBox(
            height: 48,
            child: Center(
              child: AnimatedBuilder(
                animation: slide,
                builder: (context, child) => Opacity(
                  opacity: slide.value.clamp(0, 1),
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      TroskyMotion.slideUpOffset * (1 - slide.value),
                    ),
                    child: child,
                  ),
                ),
                child: const TroskyChip(
                  label: 'Slides up',
                  color: TroskyChipColor.green,
                ),
              ),
            ),
          ),
        ),
        const _Caption('price-flash · 0.5s ease · tap'),
        GestureDetector(
          onTap: () => _price.forward(from: 0),
          child: SizedBox(
            height: 48,
            child: Center(
              child: AnimatedBuilder(
                animation: price,
                builder: (context, _) => Transform.scale(
                  scale: 1 + (TroskyMotion.priceFlashScale - 1) * price.value,
                  child: Text(
                    '₵6.00',
                    style: TroskyTypography.heading22ExtraBold.copyWith(
                      color: Color.lerp(
                        TroskyColors.ink,
                        TroskyColors.green,
                        price.value,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const _Caption('Transitions (CSS ease) · tap'),
        GestureDetector(
          onTap: () => setState(() => _toggled = !_toggled),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final duration in [
                TroskyMotion.transition150,
                TroskyMotion.transition200,
                TroskyMotion.transition250,
                TroskyMotion.transition300,
                TroskyMotion.transition400,
              ])
                AnimatedContainer(
                  duration: duration,
                  curve: TroskyMotion.ease,
                  margin: EdgeInsets.only(left: _toggled ? 160 : 0, top: 4),
                  width: 120,
                  height: 16,
                  color: TroskyColors.blue,
                  child: _Caption('${duration.inMilliseconds} ms'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const _Caption(
          'spin-slow and ripple have no duration in the design, so they are '
          'not shown.',
        ),
      ],
    );
  }
}
