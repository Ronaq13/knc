import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/timer_screen.dart';
import 'screens/circuit_screen.dart';
import 'dart:async';

void main() {
  runApp(KncApp());
}

class KncApp extends StatelessWidget {
  const KncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness Timer: Boxing, BJJ, HIIT',
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

class _KncHomeState extends State<KncHome> with WidgetsBindingObserver {
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();
  final FocusNode _timerFocusNode = FocusNode();
  final FocusNode _circuitFocusNode = FocusNode();
  int _currentFocusIndex = 0; // 0 = timer, 1 = circuit

  @override
  void initState() {
    super.initState();
    
    _clockTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
    
    // Set initial focus on the timer icon
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timerFocusNode.requestFocus();
    });
    
    // Register for didChangeAppLifecycleState callback
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _timerFocusNode.dispose();
    _circuitFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Restore focus to last used icon when dependencies change
    _restoreLastFocus();
  }
  
  // Focus on timer icon when returning to this screen
  void _restoreLastFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          // Restore focus to the last clicked icon
          if (_currentFocusIndex == 0) {
            _timerFocusNode.requestFocus();
          } else {
            _circuitFocusNode.requestFocus();
          }
        });
      }
    });
  }

  // Handle keyboard navigation
  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        // Move focus to timer icon
        setState(() {
          _currentFocusIndex = 0;
          _timerFocusNode.requestFocus();
        });
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        // Move focus to circuit icon
        setState(() {
          _currentFocusIndex = 1;
          _circuitFocusNode.requestFocus();
        });
      } else if (event.logicalKey == LogicalKeyboardKey.enter || 
                 event.logicalKey == LogicalKeyboardKey.select) {
        // Activate the current focused item
        if (_currentFocusIndex == 0) {
          _navigateToTimer();
        } else {
          _navigateToCircuit();
        }
      }
    }
  }

  void _navigateToTimer() {
    // Set focus index before navigation
    _currentFocusIndex = 0;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => TimerScreen()),
    ).then((_) {
      // Restore focus to the last clicked icon when returning
      _restoreLastFocus();
    });
  }

  void _navigateToCircuit() {
    // Set focus index before navigation
    _currentFocusIndex = 1;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => CircuitScreen()),
    ).then((_) {
      // Restore focus to the last clicked icon when returning
      _restoreLastFocus();
    });
  }

  @override
  Widget build(BuildContext context) {  
    return Scaffold(
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
      body: RawKeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        autofocus: true,
        onKey: _handleKeyEvent,
        child: Container(
          child: Column(
            children: [
              Expanded(flex: 1, child: Container()),

              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    '${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}:${_currentTime.second.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.height * 0.25,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              Expanded(flex: 1, child: Container()),

              Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _navigateToTimer,
                      child: Focus(
                        focusNode: _timerFocusNode,
                        child: Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.timer,
                            size: MediaQuery.of(context).size.height * 0.05,
                            color: _timerFocusNode.hasFocus ? Colors.blue : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 20),
                    GestureDetector(
                      onTap: _navigateToCircuit,
                      child: Focus(
                        focusNode: _circuitFocusNode,
                        child: Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.loop,
                            size: MediaQuery.of(context).size.height * 0.05,
                            color: _circuitFocusNode.hasFocus ? Colors.blue : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
