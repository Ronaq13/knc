import 'package:flutter/material.dart';
import 'screens/stopwatch_screen.dart';
import 'screens/timer_screen.dart';
import 'screens/circuit_screen.dart';

void main() {
  runApp(KncApp());
}

class KncApp extends StatelessWidget {
  const KncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Knc - Timer for TV',
      theme: ThemeData.dark(),
      home: KncHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class KncHome extends StatefulWidget {
  const KncHome({super.key});

  @override
  State<KncHome> createState() => _KncHomeState();
}

class _KncHomeState extends State<KncHome> {
  int _selectedIndex = 0;

  final _pages = [StopwatchScreen(), TimerScreen(), CircuitScreen()];
  final _titles = ['Stopwatch', 'Timers', 'Circuit'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selectedIndex]), centerTitle: true),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: (int idx) => setState(() => _selectedIndex = idx),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'Stopwatch'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Timers'),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Circuit',
          ),
        ],
      ),
    );
  }
}
