import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/theme.dart';
import '../services/alarm_service.dart';
import '../services/preference_service.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final PreferenceService _prefs = PreferenceService();
  bool _isLoading = true;
  bool _isAlarmEnabled = false;
  bool _hasOverlayPermission = false;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 22, minute: 0);
  String _timeRemaining = '';
  Timer? _timer;

  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _initializeApp();

    _floatController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -15, end: 15).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeApp() async {
    await _prefs.init();

    // Request permissions on startup
    await Permission.notification.request();
    if (await Permission.scheduleExactAlarm.isDenied) {
      // Android 12+ extra permission check if needed
      await Permission.scheduleExactAlarm.request();
    }

    final hasPermission = await FlutterOverlayWindow.isPermissionGranted();

    setState(() {
      _isAlarmEnabled = _prefs.isAlarmEnabled;
      _selectedTime = TimeOfDay(
        hour: _prefs.alarmHour,
        minute: _prefs.alarmMinute,
      );
      _hasOverlayPermission = hasPermission;
      _isLoading = false;
    });

    _updateTimeRemaining();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateTimeRemaining(),
    );
  }

  Future<void> _requestOverlayPermission() async {
    final granted = await FlutterOverlayWindow.requestPermission();
    if (granted == true) {
      setState(() => _hasOverlayPermission = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Izin overlay diberikan!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _updateTimeRemaining() async {
    if (!_isAlarmEnabled) {
      setState(() => _timeRemaining = 'Alarm tidak aktif');
      return;
    }

    final remaining = await AlarmService.getTimeRemainingAsync();
    setState(() {
      _timeRemaining = remaining != null
          ? 'Alarm dalam ${AlarmService.formatTimeRemaining(remaining)}'
          : 'Menghitung...';
    });
  }

  Future<void> _toggleAlarm(bool enabled) async {
    setState(() => _isAlarmEnabled = enabled);
    await _prefs.setAlarmEnabled(enabled);

    if (enabled) {
      final success = await AlarmService.scheduleAlarm(
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alarm diatur untuk ${_formatTime(_selectedTime)}'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } else {
      await AlarmService.cancelAlarm();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alarm dinonaktifkan'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
    }
    _updateTimeRemaining();
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked != null && picked != _selectedTime) {
      setState(() => _selectedTime = picked);
      await _prefs.setAlarmHour(picked.hour);
      await _prefs.setAlarmMinute(picked.minute);

      if (_isAlarmEnabled) {
        await AlarmService.cancelAlarm();
        await AlarmService.scheduleAlarm(
          hour: picked.hour,
          minute: picked.minute,
        );
        _updateTimeRemaining();
      }
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Header Row with History Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pengingat Tidur',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineLarge?.copyWith(fontSize: 28),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.accentPurple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.history_rounded,
                          color: Colors.white,
                        ),
                        tooltip: 'Riwayat Tidur',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HistoryScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Jaga pola tidur yang sehat',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

                const SizedBox(height: 40),

                // Moon animation
                AnimatedBuilder(
                  animation: _floatAnimation,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, _floatAnimation.value),
                    child: child,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        if (_isAlarmEnabled)
                          BoxShadow(
                            color: AppTheme.accentPurple.withValues(alpha: 0.4),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                      ],
                    ),
                    child: Text(
                      _isAlarmEnabled ? '🌙' : '🌑',
                      style: const TextStyle(fontSize: 80),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Time selector
                GestureDetector(
                  onTap: _selectTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _isAlarmEnabled
                            ? AppTheme.accentPurple.withValues(alpha: 0.5)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _formatTime(_selectedTime),
                          style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w300,
                            color: _isAlarmEnabled
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ketuk untuk ubah waktu',
                          style: TextStyle(
                            color: AppTheme.textSecondary.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Alarm toggle
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _isAlarmEnabled
                                  ? AppTheme.accentPurple.withValues(alpha: 0.2)
                                  : AppTheme.secondaryDark,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.alarm_rounded,
                              color: _isAlarmEnabled
                                  ? AppTheme.accentPurple
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alarm Tidur',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                _isAlarmEnabled ? 'Aktif' : 'Nonaktif',
                                style: TextStyle(
                                  color: _isAlarmEnabled
                                      ? AppTheme.success
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(value: _isAlarmEnabled, onChanged: _toggleAlarm),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Overlay permission card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _hasOverlayPermission
                        ? AppTheme.success.withValues(alpha: 0.2)
                        : AppTheme.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _hasOverlayPermission
                          ? AppTheme.success.withValues(alpha: 0.5)
                          : AppTheme.warning.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            _hasOverlayPermission
                                ? Icons.check_circle
                                : Icons.warning_amber_rounded,
                            color: _hasOverlayPermission
                                ? AppTheme.success
                                : AppTheme.warning,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _hasOverlayPermission
                                  ? 'Overlay aktif - alarm akan muncul full-screen'
                                  : 'Izin overlay diperlukan',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      if (!_hasOverlayPermission) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _requestOverlayPermission,
                            icon: const Icon(Icons.settings),
                            label: const Text('Berikan Izin Overlay'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.warning,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Time remaining
                if (_isAlarmEnabled)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accentPurple.withValues(alpha: 0.2),
                          AppTheme.accentBlue.withValues(alpha: 0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: AppTheme.accentBlue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _timeRemaining,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 40),

                // Test button
                TextButton.icon(
                  onPressed: () async {
                    final testTime = DateTime.now().add(
                      const Duration(seconds: 5),
                    );
                    final success = await AlarmService.scheduleAlarmAt(
                      testTime,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Test alarm dalam 5 detik... Minimize app!'
                                : 'Gagal',
                          ),
                          backgroundColor: success
                              ? AppTheme.warning
                              : Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.bug_report_outlined, size: 18),
                  label: const Text('Test Alarm (5 detik)'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
