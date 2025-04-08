import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _focusNodes = List.generate(3, (_) => FocusNode());
  final _bodyFocusNode = FocusNode();

  final _pages = [StopwatchScreen(), TimerScreen(), CircuitScreen()];

  @override
  void initState() {
    super.initState();
    // Set initial focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNodes[_selectedIndex]);
    });
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    _bodyFocusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % 3;
          FocusScope.of(context).requestFocus(_focusNodes[_selectedIndex]);
        });
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        setState(() {
          _selectedIndex = (_selectedIndex - 1 + 3) % 3;
          FocusScope.of(context).requestFocus(_focusNodes[_selectedIndex]);
        });
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        FocusScope.of(context).requestFocus(_bodyFocusNode);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        FocusScope.of(context).requestFocus(_focusNodes[_selectedIndex]);
      } else if (event.logicalKey == LogicalKeyboardKey.select || 
                 event.logicalKey == LogicalKeyboardKey.enter) {
        // The selection already happened via focus, but you can add additional
        // actions here if needed when the user presses enter/select
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(
            MediaQuery.of(context).size.height * 0.2,
          ),
          child: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            toolbarHeight: MediaQuery.of(context).size.height * 0.2,
            title: Center(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.2 * 0.8,
                child: Image.asset(
                  'assets/images/logo2.jpeg',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            centerTitle: true,
          ),
        ),
        body: Focus(
          focusNode: _bodyFocusNode,
          child: Container(
            decoration: BoxDecoration(
              border: _bodyFocusNode.hasFocus
                  ? Border.all(color: Colors.blue, width: 2)
                  : null,
            ),
            child: _pages[_selectedIndex],
          ),
        ),
        bottomNavigationBar: SizedBox(
          height: MediaQuery.of(context).size.height * 0.1,
          child: BottomNavigationBar(
            backgroundColor: Colors.white,
            selectedItemColor: Colors.blue,
            unselectedItemColor: Colors.grey[600],
            currentIndex: _selectedIndex,
            onTap: (int idx) {
              setState(() => _selectedIndex = idx);
              FocusScope.of(context).requestFocus(_focusNodes[idx]);
            },
            type: BottomNavigationBarType.fixed,
            selectedFontSize: MediaQuery.of(context).size.height * 0.04 * 0.5,
            unselectedFontSize: MediaQuery.of(context).size.height * 0.04 * 0.5,
            iconSize: MediaQuery.of(context).size.height * 0.04,
            items: [
              BottomNavigationBarItem(
                icon: Focus(
                  focusNode: _focusNodes[0],
                  child: Builder(
                    builder: (BuildContext context) {
                      final bool hasFocus = Focus.of(context).hasFocus;
                      return Container(
                        height: MediaQuery.of(context).size.height * 0.04,
                        decoration: BoxDecoration(
                          border: hasFocus ? Border.all(color: Colors.blue, width: 2) : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.all(hasFocus ? 4 : 0),
                        child: Icon(
                          Icons.timer,
                          color: hasFocus ? Colors.blue : (_selectedIndex == 0 ? Colors.blue : Colors.grey[600]),
                        ),
                      );
                    },
                  ),
                ),
                label: 'Stopwatch',
              ),
              BottomNavigationBarItem(
                icon: Focus(
                  focusNode: _focusNodes[1],
                  child: Builder(
                    builder: (BuildContext context) {
                      final bool hasFocus = Focus.of(context).hasFocus;
                      return Container(
                        height: MediaQuery.of(context).size.height * 0.04,
                        decoration: BoxDecoration(
                          border: hasFocus ? Border.all(color: Colors.blue, width: 2) : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.all(hasFocus ? 4 : 0),
                        child: Icon(
                          Icons.schedule,
                          color: hasFocus ? Colors.blue : (_selectedIndex == 1 ? Colors.blue : Colors.grey[600]),
                        ),
                      );
                    },
                  ),
                ),
                label: 'Timers',
              ),
              BottomNavigationBarItem(
                icon: Focus(
                  focusNode: _focusNodes[2],
                  child: Builder(
                    builder: (BuildContext context) {
                      final bool hasFocus = Focus.of(context).hasFocus;
                      return Container(
                        height: MediaQuery.of(context).size.height * 0.04,
                        decoration: BoxDecoration(
                          border: hasFocus ? Border.all(color: Colors.blue, width: 2) : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.all(hasFocus ? 4 : 0),
                        child: Icon(
                          Icons.fitness_center,
                          color: hasFocus ? Colors.blue : (_selectedIndex == 2 ? Colors.blue : Colors.grey[600]),
                        ),
                      );
                    },
                  ),
                ),
                label: 'Circuit',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

