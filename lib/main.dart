import 'dart:async';
import 'dart:io';
import 'package:alarm/alarm.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'config/theme.dart';
import 'services/alarm_service.dart';
import 'services/database_service.dart';
import 'screens/home_screen.dart';
import 'screens/alarm_screen.dart';
import 'screens/splash_screen.dart';

// Global navigator key for navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Method channel for native communication
const MethodChannel _channel = MethodChannel(
  'com.example.aplikasi_pengingat_tidur/alarm',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.primaryDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await AlarmService.init();

  // Listen for alarm ring events from alarm package
  Alarm.ringStream.stream.listen((alarmSettings) async {
    debugPrint('🔔 ALARM RING from Flutter! ID: ${alarmSettings.id}');
    await _showAlarmOverlay();
  });

  runApp(const SleepReminderApp());
}

/// Show alarm overlay
Future<void> _showAlarmOverlay() async {
  debugPrint('🖥️ Showing alarm overlay...');

  try {
    final hasOverlayPermission =
        await FlutterOverlayWindow.isPermissionGranted();
    debugPrint('📱 Overlay permission: $hasOverlayPermission');

    if (hasOverlayPermission) {
      debugPrint('🪟 Opening overlay window...');
      await FlutterOverlayWindow.shareData('RESET');
      await FlutterOverlayWindow.showOverlay(
        enableDrag: false,
        height: WindowSize.fullCover,
        width: WindowSize.fullCover,
        alignment: OverlayAlignment.center,
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
      );
      debugPrint('✅ Overlay shown');
    } else {
      debugPrint('⚠️ No overlay permission, showing in-app screen');
      _showInAppAlarmScreen();
    }
  } catch (e) {
    debugPrint('❌ Overlay error: $e');
    _showInAppAlarmScreen();
  }
}

void _showInAppAlarmScreen() {
  debugPrint('📱 Showing in-app alarm screen');
  final context = navigatorKey.currentContext;
  if (context != null) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AlarmScreen(),
        fullscreenDialog: true,
      ),
    );
  } else {
    Future.delayed(const Duration(milliseconds: 300), _showInAppAlarmScreen);
  }
}

class SleepReminderApp extends StatefulWidget {
  const SleepReminderApp({super.key});

  @override
  State<SleepReminderApp> createState() => _SleepReminderAppState();
}

class _SleepReminderAppState extends State<SleepReminderApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Check for alarm immediately after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForRingingAlarm();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('📱 Lifecycle: $state');
    if (state == AppLifecycleState.resumed) {
      // Check for alarm when app comes to foreground
      _checkForRingingAlarm();
    }
  }

  Future<void> _checkForRingingAlarm() async {
    debugPrint('🔍 Checking for ringing alarms...');

    final alarms = await Alarm.getAlarms();
    debugPrint('📋 Found ${alarms.length} alarms');

    for (final alarm in alarms) {
      final now = DateTime.now();
      final diff = now.difference(alarm.dateTime);

      debugPrint(
        '🕒 Check Alarm: ${alarm.dateTime}, Now: $now, Diff: ${diff.inSeconds}s',
      );

      // Alarm is considered ringing if we are within valid window:
      // -1 minute (scheduled slightly in future) to 15 minutes past
      if (diff.inMinutes >= -1 && diff.inMinutes < 15) {
        debugPrint('⏰ Ringing alarm found: ${alarm.dateTime}');
        await _showAlarmOverlay();
        return;
      }
    }

    debugPrint('✅ No ringing alarms');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Pengingat Tidur',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}

// =====================================================
// OVERLAY ENTRY POINT
// =====================================================
@pragma("vm:entry-point")
void overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Alarm.init();

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const OverlayAlarmWidget(),
    ),
  );
}

class OverlayAlarmWidget extends StatefulWidget {
  const OverlayAlarmWidget({super.key});

  @override
  State<OverlayAlarmWidget> createState() => _OverlayAlarmWidgetState();
}

class _OverlayAlarmWidgetState extends State<OverlayAlarmWidget> {
  double _sliderValue = 0.0;
  bool _isProcessing = false;
  bool _isSoundStopped = false;
  String _currentTime = '';
  Timer? _timeUpdateTimer;
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timeUpdateTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateTime(),
    );

    // Listen for RESET signal to handle view reuse
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data == 'RESET') {
        debugPrint('🔄 Received RESET signal in Overlay');
        _resetState();
      }
    });

    _startAutoCloseTimer();
  }

  void _resetState() {
    if (mounted) {
      setState(() {
        _isSoundStopped = false;
        _isProcessing = false;
        _sliderValue = 0.0;
      });
    }
    _startAutoCloseTimer();
  }

  void _startAutoCloseTimer() {
    _autoCloseTimer?.cancel();
    debugPrint('⏳ Starting auto-close timer (60s)');

    // User requested 60s for testing
    _autoCloseTimer = Timer(const Duration(seconds: 120), () async {
      debugPrint('⏰ Timer finished, closing overlay...');
      try {
        await DatabaseService().insertLog('Sesi Tidur Selesai');
        await FlutterOverlayWindow.closeOverlay();
        debugPrint('✅ FlutterOverlayWindow.closeOverlay() called');
      } catch (e) {
        debugPrint('❌ Error closing overlay: $e');
      }

      // Fallback: Kill the process/view to ensure it closes
      try {
        if (Platform.isAndroid) {
          await SystemNavigator.pop();
        }
        exit(0);
      } catch (e) {
        debugPrint('❌ Error forcing exit: $e');
      }
    });
  }

  @override
  void dispose() {
    _timeUpdateTimer?.cancel();
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _stopAlarmSound() async {
    if (_isProcessing || _isSoundStopped) return;
    setState(() => _isProcessing = true);

    debugPrint('🔇 Stopping alarm sound only...');

    try {
      await Alarm.stop(1);
      // Also stop secondary alarm
      try {
        await AndroidAlarmManager.cancel(777);
      } catch (_) {}

      debugPrint('✅ Alarm sound stopped');

      await DatabaseService().insertLog('Suara Alarm Dimatikan');

      if (mounted) {
        setState(() {
          _isSoundStopped = true;
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error stopping alarm: $e');
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.alarmGradient),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Moon
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentPurple.withValues(alpha: 0.4),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
                child: const Text('🌙', style: TextStyle(fontSize: 100)),
              ),

              const SizedBox(height: 40),

              // Time
              Text(
                _currentTime,
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                _isSoundStopped ? 'Mode Tidur Aktif' : 'Waktunya Tidur!',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentPink,
                ),
              ),

              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _isSoundStopped
                      ? 'Layar akan tetap menyala selama 1 jam.\nSelamat tidur! 💤'
                      : 'Matikan gadget dan istirahat yang cukup',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const Spacer(),

              // Controls
              if (!_isSoundStopped)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      // Slider
                      Container(
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
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(35),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 50),
                                    width:
                                        (MediaQuery.of(context).size.width -
                                            80) *
                                        _sliderValue,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.accentPurple.withValues(
                                            alpha: 0.5,
                                          ),
                                          AppTheme.accentBlue.withValues(
                                            alpha: 0.5,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 70,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 28,
                                ),
                                overlayShape: SliderComponentShape.noOverlay,
                                activeTrackColor: Colors.transparent,
                                inactiveTrackColor: Colors.transparent,
                                thumbColor: AppTheme.accentPurple,
                              ),
                              child: Slider(
                                value: _sliderValue,
                                onChanged: _isProcessing
                                    ? null
                                    : (value) {
                                        setState(() => _sliderValue = value);
                                      },
                                onChangeEnd: (value) {
                                  if (value >= 0.85) {
                                    _stopAlarmSound();
                                  } else {
                                    setState(() => _sliderValue = 0);
                                  }
                                },
                              ),
                            ),
                            if (_sliderValue < 0.3 && !_isProcessing)
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 60),
                                  Icon(
                                    Icons.volume_off_rounded,
                                    color: AppTheme.textSecondary,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Geser Matikan Suara',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            if (_isProcessing)
                              const CircularProgressIndicator(
                                color: AppTheme.accentPurple,
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _stopAlarmSound,
                        icon: const Icon(Icons.volume_off_rounded),
                        label: const Text('Matikan Suara'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Text(
                    'Jangan main HP ya! 😴',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
