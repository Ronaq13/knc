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

  // Create the pages with keys
  late final List<Widget> _pages;
  late final GlobalKey<StopwatchScreenState> _stopwatchKey;
  late final GlobalKey<TimerScreenState> _timerKey;
  late final GlobalKey<CircuitScreenState> _circuitKey;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize focus nodes with key event handling
    _focusNodes.clear(); // Clear the auto-generated list
    
    // Create custom focus nodes with key event handling
    for (int i = 0; i < 3; i++) {
      final int index = i; // Capture the index for the closure
      final focusNode = FocusNode();
      
      _focusNodes.add(focusNode);
    }
    
    // Initialize pages
    _stopwatchKey = GlobalKey<StopwatchScreenState>();
    _timerKey = GlobalKey<TimerScreenState>();
    _circuitKey = GlobalKey<CircuitScreenState>();
    final stopwatchScreen = StopwatchScreen(key: _stopwatchKey);
    final timerScreen = TimerScreen(key: _timerKey);
    final circuitScreen = CircuitScreen(key: _circuitKey);
    _pages = [
      stopwatchScreen,
      timerScreen,
      circuitScreen,
    ];
    
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
        // If we're on the stopwatch tab, trigger its autofocus
        if (_selectedIndex == 0) {
          final stopwatchState = _stopwatchKey.currentState;
          if (stopwatchState != null) {
            stopwatchState.autofocusStartButton();
          } else {
            // Fallback to body focus if we can't access the stopwatch state
            FocusScope.of(context).requestFocus(_bodyFocusNode);
          }
        } else if (_selectedIndex == 1) {
          // If we're on the timer tab, trigger its autofocus
          final timerState = _timerKey.currentState;
          if (timerState != null) {
            timerState.autofocusFirstButton();
          } else {
            // Fallback to body focus if we can't access the timer state
            FocusScope.of(context).requestFocus(_bodyFocusNode);
          }
        } else if (_selectedIndex == 2) {
          // If we're on the circuit tab, trigger its autofocus
          final circuitState = _circuitKey.currentState;
          if (circuitState != null) {
            // Use the more specific method if circuit is running
            if (circuitState.isCircuitRunning && !circuitState.isCircuitCompleted) {
              circuitState.focusPauseButton();
            } else {
              circuitState.autofocusFirstButton();
            }
          } else {
            // Fallback to body focus if we can't access the circuit state
            FocusScope.of(context).requestFocus(_bodyFocusNode);
          }
        } else {
          // For other screens, just focus the body
          FocusScope.of(context).requestFocus(_bodyFocusNode);
        }
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
              border: null,
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
                  onKey: (FocusNode node, RawKeyEvent event) {
                    if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      final stopwatchState = _stopwatchKey.currentState;
                      if (stopwatchState != null) {
                        stopwatchState.autofocusStartButton();
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Builder(
                    builder: (BuildContext context) {
                      final bool hasFocus = Focus.of(context).hasFocus;
                      return Container(
                        height: MediaQuery.of(context).size.height * 0.04,
                        decoration: BoxDecoration(
                          border: null,
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
                  onKey: (FocusNode node, RawKeyEvent event) {
                    if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      final timerState = _timerKey.currentState;
                      if (timerState != null) {
                        timerState.autofocusFirstButton();
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Builder(
                    builder: (BuildContext context) {
                      final bool hasFocus = Focus.of(context).hasFocus;
                      return Container(
                        height: MediaQuery.of(context).size.height * 0.04,
                        decoration: BoxDecoration(
                          border: null,
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
                  onKey: (FocusNode node, RawKeyEvent event) {
                    if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      final circuitState = _circuitKey.currentState;
                      if (circuitState != null) {
                        if (circuitState.isCircuitRunning && !circuitState.isCircuitCompleted) {
                          circuitState.focusPauseButton();
                        } else {
                          circuitState.autofocusFirstButton();
                        }
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Builder(
                    builder: (BuildContext context) {
                      final bool hasFocus = Focus.of(context).hasFocus;
                      return Container(
                        height: MediaQuery.of(context).size.height * 0.04,
                        decoration: BoxDecoration(
                          border: null,
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

