import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      setState(() {
        _errorMessage = 'Пожалуйста, введи количество';
      });
      return;
    }

    final int? declaredAmount = int.tryParse(inputText);
    if (declaredAmount == null || declaredAmount <= 0) {
      setState(() {
        _errorMessage = 'Введи корректное число больше нуля';
      });
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
          'Да, это больше. Расслабься, мы никуда не спешим. Твоя задача завтра — просто курить по таймеру.',
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
              const Icon(
                Icons.spa_rounded,
                size: 80,
                color: Color(0xFF00BFA5),
              ),
              const SizedBox(height: 32),
              const Text(
                'Давай будем честны.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Сколько сигарет в день ты выкуриваешь сейчас?\n\nНе приуменьшай. Нам нужна реальная цифра, чтобы составить комфортный график.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.5,
                ),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
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
    plan.add(DailyPlan(
      dayNumber: currentDay++,
      cigarettesAllowed: currentAmount,
      phase: "Адаптация",
      note: "Курим по таймеру.",
    ));
    plan.add(DailyPlan(
      dayNumber: currentDay++,
      cigarettesAllowed: currentAmount,
      phase: "Закрепление",
      note: "Держим ритм.",
    ));
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
