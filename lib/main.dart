import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async'; // Библиотека для работы с таймером

void main() {
  runApp(const QuitSmokingApp());
}

class QuitSmokingApp extends StatelessWidget {
  const QuitSmokingApp({super.key});

  @override
  Widget build(BuildContext context) {
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: const StartScreen(),
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

  void _calculatePlan() {
    setState(() {
      _errorMessage = null;
    });

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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2D3E),
        title: const Text('План готов 🚀', style: TextStyle(color: Colors.white)),
        content: Text(
          'Ты указал $declaredAmount сигарет.\n\n'
          'Чтобы снять начальный стресс, завтра твой лимит составит: ${firstDay.cigarettesAllowed} сигарет.\n\n'
          'Расслабься, мы никуда не спешим. Твоя задача — просто курить по таймеру.',
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Закрываем всплывающее окно
              // ПЕРЕХОДИМ НА ГЛАВНЫЙ ЭКРАН, передавая туда наш план
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => DashboardScreen(plan: plan),
                ),
              );
            },
            child: const Text('Понятно, я готов', style: TextStyle(color: Color(0xFF00BFA5))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
              const Text(
                'Давай будем честны.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'Сколько сигарет в день ты выкуриваешь сейчас?\n\nНам нужна реальная цифра, чтобы составить комфортный график.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: 'Например, 10',
                  hintStyle: const TextStyle(color: Colors.white24),
                  errorText: _errorMessage,
                  filled: true,
                  fillColor: const Color(0xFF2A2D3E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _calculatePlan,
                child: const Text('Рассчитать мой план'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- ГЛАВНЫЙ ЭКРАН (ТАЙМЕР И СПИСОК) ----------------

class DashboardScreen extends StatefulWidget {
  final List<DailyPlan> plan;

  const DashboardScreen({super.key, required this.plan});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _timer;
  Duration _timeLeft = const Duration(minutes: 60);
  int _currentDayIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    int cigarettesToday = widget.plan[_currentDayIndex].cigarettesAllowed;
    int intervalMinutes = cigarettesToday > 0 ? (900 ~/ cigarettesToday) : 0;
    
    setState(() {
      _timeLeft = Duration(minutes: intervalMinutes);
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft.inSeconds > 0) {
        setState(() {
          _timeLeft = _timeLeft - const Duration(seconds: 1);
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _onSmoked() {
    _startTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Отлично. Теперь ждем окончания следующего таймера.'),
        backgroundColor: Color(0xFF00BFA5),
      ),
    );
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
    final todayPlan = widget.plan[_currentDayIndex];
    final isFree = todayPlan.cigarettesAllowed == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Твой график'),
        backgroundColor: const Color(0xFF1E1E2C),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF2A2D3E),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
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
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    ),
                    child: const Text('Я покурил'),
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
                
                return Card(
                  color: isToday ? const Color(0xFF00BFA5).withOpacity(0.2) : const Color(0xFF2A2D3E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    leading: CircleAvatar(
                      backgroundColor: isToday ? const Color(0xFF00BFA5) : Colors.white12,
                      child: Text('${day.dayNumber}', style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(
                      '${day.cigarettesAllowed} сигарет(ы)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0), // <-- Исправлено здесь
                      child: Text('${day.phase}\n${day.note}', style: const TextStyle(height: 1.4)),
                    ),
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

// ---------------- ЛОГИКА (Генератор) ----------------

class DailyPlan {
  final int dayNumber;
  final int cigarettesAllowed;
  final String phase;
  final String note;

  DailyPlan({
    required this.dayNumber,
    required this.cigarettesAllowed,
    required this.phase,
    this.note = "",
  });
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
