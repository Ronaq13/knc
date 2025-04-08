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
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.white,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
          bodyLarge: TextStyle(color: Colors.black),
          labelLarge: TextStyle(color: Colors.black),
          titleMedium: TextStyle(color: Colors.black),
          titleLarge: TextStyle(color: Colors.black),
        ),
        colorScheme: ColorScheme.light(
          primary: Colors.blue,
          secondary: Colors.blueAccent,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
        ),
      ),
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
  // final _titles = ['Stopwatch', 'Timers', 'Circuit'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          MediaQuery.of(context).size.height * 0.2,
        ), // 20% of screen height
        child: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          toolbarHeight:
              MediaQuery.of(context).size.height * 0.2, // Match preferredSize
          title: Center(
            // Ensures perfect centering
            child: Container(
              height:
                  MediaQuery.of(context).size.height *
                  0.2 *
                  0.8, // 80% of AppBar height
              child: Image.asset(
                'assets/images/logo2.jpeg',
                fit: BoxFit.contain,
              ),
            ),
          ),
          centerTitle: true,
        ),
      ),

      body: _pages[_selectedIndex],

      bottomNavigationBar: SizedBox(
        height:
            MediaQuery.of(context).size.height * 0.1, // 10% of screen height
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey[600],
          currentIndex: _selectedIndex,
          onTap: (int idx) => setState(() => _selectedIndex = idx),
          type: BottomNavigationBarType.fixed,
          selectedFontSize:
              MediaQuery.of(context).size.height *
              0.04 *
              0.5, // 50% of item height
          unselectedFontSize: MediaQuery.of(context).size.height * 0.04 * 0.5,
          iconSize:
              MediaQuery.of(context).size.height *
              0.04, // 50% of item height (4% screen height)
          items: [
            BottomNavigationBarItem(
              icon: SizedBox(
                height:
                    MediaQuery.of(context).size.height *
                    0.04, // 4% screen (50% of 80% of 10%)
                child: Icon(Icons.timer),
              ),
              label: 'Stopwatch',
            ),
            BottomNavigationBarItem(
              icon: SizedBox(
                height: MediaQuery.of(context).size.height * 0.04,
                child: Icon(Icons.schedule),
              ),
              label: 'Timers',
            ),
            BottomNavigationBarItem(
              icon: SizedBox(
                height: MediaQuery.of(context).size.height * 0.04,
                child: Icon(Icons.fitness_center),
              ),
              label: 'Circuit',
            ),
          ],
        ),
      ),
    );
  }
}
