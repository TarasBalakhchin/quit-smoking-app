import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'timer_channel_2', 
        channelName: 'Таймер сигарет',
        channelDescription: 'Уведомления о том, что пора курить',
        defaultColor: const Color(0xFF00BFA5),
        importance: NotificationImportance.Max, 
        playSound: true,
        enableVibration: true,
        criticalAlerts: true, 
      )
    ],
  );

  final prefs = await SharedPreferences.getInstance();
  final isActive = prefs.getBool('is_active') ?? false;
  final declaredAmount = prefs.getInt('declared_amount') ?? 10;
  
  runApp(QuitSmokingApp(isActive: isActive, declaredAmount: declaredAmount));
}

class QuitSmokingApp extends StatelessWidget {
  final bool isActive;
  final int declaredAmount;

  const QuitSmokingApp({super.key, required this.isActive, required this.declaredAmount});

  @override
  Widget build(BuildContext context) {
    final plan = generateQuitPlan(declaredAmount);

    return MaterialApp(
      title: 'Свобода от сигарет',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1E1E2C),
        primaryColor: const Color(0xFF00BFA5),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00BFA5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: isActive ? DashboardScreen(plan: plan) : const StartScreen(),
    );
  }
}

// ---------------- СТАРТОВЫЙ ЭКРАН ----------------
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _errorMessage;

  void _calculatePlan() async {
    setState(() { _errorMessage = null; });
    final inputText = _controller.text.trim();
    if (inputText.isEmpty) {
      setState(() { _errorMessage = 'Пожалуйста, введи количество'; });
      return;
    }

    final int? declaredAmount = int.tryParse(inputText);
    if (declaredAmount == null || declaredAmount <= 0) {
      setState(() { _errorMessage = 'Введи корректное число'; });
      return;
    }

    final plan = generateQuitPlan(declaredAmount);
    final firstDay = plan.first;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_active', true);
    await prefs.setInt('declared_amount', declaredAmount);
    await prefs.setInt('current_day_index', 0);
    await prefs.setInt('cigarettes_left', firstDay.cigarettesAllowed);
    await prefs.remove('target_time'); 

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2D3E),
        title: const Text('План готов 🚀', style: TextStyle(color: Colors.white)),
        content: Text(
          'Ты указал $declaredAmount сигарет.\n\nЗавтра твой лимит составит: ${firstDay.cigarettesAllowed} сигарет.\n\nТвоя задача — просто курить по таймеру.',
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => DashboardScreen(plan: plan)),
              );
            },
            child: const Text('Понятно, я готов', style: TextStyle(color: Color(0xFF00BFA5))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.spa_rounded, size: 80, color: Color(0xFF00BFA5)),
              const SizedBox(height: 32),
              const Text('Давай будем честны.', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              const Text('Сколько сигарет в день ты выкуриваешь сейчас?', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 48),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: 'Например, 10',
                  filled: true,
                  fillColor: const Color(0xFF2A2D3E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(onPressed: _calculatePlan, child: const Text('Рассчитать мой план')),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- ГЛАВНЫЙ ЭКРАН ----------------
class DashboardScreen extends StatefulWidget {
  final List<DailyPlan> plan;
  const DashboardScreen({super.key, required this.plan});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _timer;
  DateTime? _targetTime;
  Duration _timeLeft = Duration.zero;
  
  int _currentDayIndex = 0;
  late int _cigarettesLeftToday;
  bool _isLoading = true;
  bool _isReadyAlertShown = false; 

  @override
  void initState() {
    super.initState();
    AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });

    _cigarettesLeftToday = widget.plan[0].cigarettesAllowed;
    _loadDataFromMemory();
  }

  Future<void> _loadDataFromMemory() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _currentDayIndex = prefs.getInt('current_day_index') ?? 0;
      _cigarettesLeftToday = prefs.getInt('cigarettes_left') ?? widget.plan[_currentDayIndex].cigarettesAllowed;
      
      final savedTime = prefs.getString('target_time');
      if (savedTime != null) {
        _targetTime = DateTime.parse(savedTime);
      } else {
        _setNewTargetTime(prefs);
      }
      _isLoading = false;
    });

    _startTimerTick();
  }

  void _setNewTargetTime(SharedPreferences prefs) {
    int cigarettesToday = widget.plan[_currentDayIndex].cigarettesAllowed;
    int intervalMinutes = cigarettesToday > 0 ? (900 ~/ cigarettesToday) : 0;
    
    // ИСПРАВЛЕНИЕ ЗДЕСЬ: Убрано слово const перед Duration
    _targetTime = DateTime.now().add(Duration(minutes: intervalMinutes)); 
    
    prefs.setString('target_time', _targetTime!.toIso8601String());

    AwesomeNotifications().cancelAll();
    
    if (cigarettesToday > 0) {
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 10,
          channelKey: 'timer_channel_2', 
          title: 'Время пришло! 🚬',
          body: 'Таймер завершен. Можешь сделать перекур.',
          wakeUpScreen: true,
          category: NotificationCategory.Alarm, 
        ),
        schedule: NotificationCalendar.fromDate(
          date: _targetTime!,
          allowWhileIdle: true, 
          preciseAlarm: true,   
        ),
      );
    }
  }

  void _showInAppAlert() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2D3E),
        title: const Text('Таймер вышел! 🚬', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        content: const Text('Можно сделать перекур.', style: TextStyle(color: Colors.white70, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно', style: TextStyle(color: Color(0xFF00BFA5), fontSize: 18)),
          ),
        ],
      ),
    );
  }

  void _startTimerTick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      if (_targetTime != null && _targetTime!.isAfter(now)) {
        setState(() {
          _timeLeft = _targetTime!.difference(now);
          _isReadyAlertShown = false; 
        });
      } else {
        setState(() {
          _timeLeft = Duration.zero;
        });
        
        if (!_isReadyAlertShown && _targetTime != null && _cigarettesLeftToday > 0) {
          _isReadyAlertShown = true;
          _showInAppAlert();
        }
      }
    });
  }

  void _onSmoked() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      if (_cigarettesLeftToday > 0) {
        _cigarettesLeftToday--;
      }
      
      if (_cigarettesLeftToday <= 0 && _currentDayIndex < widget.plan.length - 1) {
        _currentDayIndex++;
        _cigarettesLeftToday = widget.plan[_currentDayIndex].cigarettesAllowed;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('День завершен! Завтра новый этап.'), backgroundColor: Color(0xFF00BFA5)),
        );
      }
    });

    await prefs.setInt('current_day_index', _currentDayIndex);
    await prefs.setInt('cigarettes_left', _cigarettesLeftToday);
    
    _setNewTargetTime(prefs);
  }

  void _resetApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    AwesomeNotifications().cancelAll();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const StartScreen()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 ? "$hours:$minutes:$seconds" : "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final todayPlan = widget.plan[_currentDayIndex];
    final isFree = todayPlan.cigarettesAllowed == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Твой график'),
        backgroundColor: const Color(0xFF1E1E2C),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt, color: Colors.white54),
            onPressed: _resetApp,
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF2A2D3E),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
            ),
            child: Column(
              children: [
                Text(
                  isFree ? 'ТЫ СВОБОДЕН!' : 'СЛЕДУЮЩАЯ СИГАРЕТА ЧЕРЕЗ:',
                  style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  isFree ? '∞' : _formatDuration(_timeLeft),
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: _timeLeft.inSeconds == 0 ? Colors.redAccent : Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                if (!isFree)
                  ElevatedButton(
                    onPressed: _onSmoked,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16)),
                    child: Text('Я покурил (Осталось: $_cigarettesLeftToday)'),
                  ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.plan.length,
              itemBuilder: (context, index) {
                final day = widget.plan[index];
                final isToday = index == _currentDayIndex;
                final isPassed = index < _currentDayIndex;
                
                return Card(
                  color: isToday ? const Color(0xFF00BFA5).withOpacity(0.15) : const Color(0xFF2A2D3E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isToday ? const BorderSide(color: Color(0xFF00BFA5), width: 1.5) : BorderSide.none,
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    leading: CircleAvatar(
                      backgroundColor: isPassed ? Colors.green : (isToday ? const Color(0xFF00BFA5) : Colors.white12),
                      child: isPassed 
                        ? const Icon(Icons.check, color: Colors.white) 
                        : Text('${day.dayNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(
                      'День ${day.dayNumber}: ${day.cigarettesAllowed} сигарет',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isPassed ? Colors.white54 : Colors.white),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('${day.phase}\n${day.note}', style: TextStyle(height: 1.4, color: isPassed ? Colors.white38 : Colors.white70)),
                    ),
                    trailing: isToday && day.cigarettesAllowed > 0
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Осталось', style: TextStyle(fontSize: 10, color: Colors.white70)),
                            Text('$_cigarettesLeftToday', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
                          ],
                        )
                      : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- ЛОГИКА ----------------
class DailyPlan {
  final int dayNumber;
  final int cigarettesAllowed;
  final String phase;
  final String note;

  DailyPlan({required this.dayNumber, required this.cigarettesAllowed, required this.phase, this.note = ""});
}

List<DailyPlan> generateQuitPlan(int declaredAmount) {
  List<DailyPlan> plan = [];
  int currentDay = 1;
  int actualStart = declaredAmount + (declaredAmount ~/ 2);
  if (actualStart < 7) actualStart = 7;
  int currentAmount = actualStart;

  while (currentAmount > 2) {
    plan.add(DailyPlan(dayNumber: currentDay++, cigarettesAllowed: currentAmount, phase: "Адаптация", note: "Курим по таймеру."));
    plan.add(DailyPlan(dayNumber: currentDay++, cigarettesAllowed: currentAmount, phase: "Закрепление", note: "Держим ритм."));
    currentAmount--;
  }

  plan.add(DailyPlan(dayNumber: currentDay++, cigarettesAllowed: 2, phase: "Сдвиг", note: "Первая до 09:00, вторая вечером."));
  plan.add(DailyPlan(dayNumber: currentDay++, cigarettesAllowed: 2, phase: "Сдвиг", note: "Первая до 11:00, вторая вечером."));
  plan.add(DailyPlan(dayNumber: currentDay++, cigarettesAllowed: 2, phase: "Сдвиг", note: "Первая до 14:00, вторая вечером."));
  plan.add(DailyPlan(dayNumber: currentDay++, cigarettesAllowed: 2, phase: "Сдвиг", note: "Первая до 17:00, вторая вечером."));
  plan.add(DailyPlan(dayNumber: currentDay++, cigarettesAllowed: 1, phase: "Осознание", note: "Обрати внимание на тошноту."));
  plan.add(DailyPlan(dayNumber: currentDay++, cigarettesAllowed: 1, phase: "Осознание", note: "Почувствуй горечь дыма."));
  plan.add(DailyPlan(dayNumber: currentDay++, cigarettesAllowed: 1, phase: "Финал", note: "Ритуальная последняя сигарета."));
  plan.add(DailyPlan(dayNumber: currentDay++, cigarettesAllowed: 0, phase: "Свобода", note: "Ты свободен."));

  return plan;
}
