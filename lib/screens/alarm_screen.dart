import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../config/theme.dart';
import '../services/alarm_service.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with TickerProviderStateMixin {
  double _sliderValue = 0.0;
  bool _isDismissing = false;
  late AnimationController _pulseController;
  late AnimationController _moonController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _moonAnimation;
  Timer? _timeTimer;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();

    // Keep screen awake
    WakelockPlus.enable();

    // Hide system UI for full immersion
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Pulse animation for the alarm text
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Moon floating animation
    _moonController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _moonAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _moonController, curve: Curves.easeInOut),
    );

    // Update current time
    _updateTime();
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _moonController.dispose();
    _timeTimer?.cancel();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _dismissAlarm() async {
    if (_isDismissing) return;

    setState(() {
      _isDismissing = true;
    });

    // Stop the alarm
    await AlarmService.cancelAlarm();

    // Reschedule for tomorrow
    final alarm = await AlarmService.getScheduledTime();
    if (alarm != null) {
      await AlarmService.scheduleAlarm(hour: alarm.hour, minute: alarm.minute);
    }

    // Navigate back
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent back button from closing the alarm
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: AppTheme.alarmGradient),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 1),

                // Moon animation
                AnimatedBuilder(
                  animation: _moonAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _moonAnimation.value),
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentPurple.withValues(alpha: 0.3),
                          blurRadius: 60,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                    child: const Text('🌙', style: TextStyle(fontSize: 100)),
                  ),
                ),

                const SizedBox(height: 30),

                // Current time
                Text(
                  _currentTime,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 80,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 4,
                  ),
                ),

                const SizedBox(height: 20),

                // Alarm message with pulse animation
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Text(
                    'Waktunya Tidur!',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppTheme.accentPink,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Matikan gadget dan istirahat yang cukup',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(flex: 2),

                // Stars decoration
                const _StarsDecoration(),

                const Spacer(flex: 1),

                // Slide to dismiss
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      Text(
                        'Geser untuk mematikan alarm',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SliderDismiss(
                        value: _sliderValue,
                        onChanged: (value) {
                          setState(() {
                            _sliderValue = value;
                          });
                        },
                        onDismiss: _dismissAlarm,
                        isLoading: _isDismissing,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SliderDismiss extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback onDismiss;
  final bool isLoading;

  const _SliderDismiss({
    required this.value,
    required this.onChanged,
    required this.onDismiss,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(35),
        border: Border.all(
          color: AppTheme.accentPurple.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Progress fill
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            height: 70,
            width: (MediaQuery.of(context).size.width - 80) * value,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentPurple.withValues(alpha: 0.5),
                  AppTheme.accentBlue.withValues(alpha: 0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(35),
            ),
          ),

          // Slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 66,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: AppTheme.accentPurple,
              thumbShape: const _CustomThumbShape(),
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: value,
              onChanged: isLoading ? null : onChanged,
              onChangeEnd: (val) {
                if (val >= 0.95) {
                  onDismiss();
                } else {
                  onChanged(0);
                }
              },
            ),
          ),

          // Center text
          if (value < 0.3)
            Positioned.fill(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isLoading ? 'Mematikan...' : 'Saya akan tidur',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CustomThumbShape extends SliderComponentShape {
  const _CustomThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(60, 60);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // Gradient for thumb
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [AppTheme.accentPurple, AppTheme.accentBlue],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: 28));

    // Shadow
    canvas.drawCircle(
      center.translate(0, 2),
      28,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Main circle
    canvas.drawCircle(center, 28, paint);

    // Icon
    final iconPainter = TextPainter(
      text: const TextSpan(text: '😴', style: TextStyle(fontSize: 24)),
      textDirection: TextDirection.ltr,
    )..layout();

    iconPainter.paint(
      canvas,
      center.translate(-iconPainter.width / 2, -iconPainter.height / 2),
    );
  }
}

class _StarsDecoration extends StatefulWidget {
  const _StarsDecoration();

  @override
  State<_StarsDecoration> createState() => _StarsDecorationState();
}

class _StarsDecorationState extends State<_StarsDecoration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final offset = (index - 2) * 0.2;
              final opacity =
                  0.3 + 0.7 * ((_controller.value + offset) % 1.0).abs();
              return Opacity(opacity: opacity.clamp(0.3, 1.0), child: child);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '⭐',
                style: TextStyle(fontSize: 16 + (index == 2 ? 8 : 0)),
              ),
            ),
          );
        }),
      ),
    );
  }
}
