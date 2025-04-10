import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/timer_screen.dart';
import 'screens/circuit_screen.dart';
import 'services/settings_service.dart';
import 'dart:async';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize settings service
  await SettingsService().initialize();
  
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
  final FocusNode _10secToggleFocusNode = FocusNode();
  int _currentFocusIndex = 0; // 0 = timer, 1 = circuit, 2 = sound toggle
  
  // Settings service for global preferences
  final SettingsService _settingsService = SettingsService();
  
  // Add variable to track back button presses
  DateTime? _lastBackPressTime;

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
    _10secToggleFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Restore focus to last used icon when dependencies change
    _restoreLastFocus();
  }
  
  // Toggle 10-second warning sound
  void _toggleWarningSound() async {
    await _settingsService.toggle10SecWarning();
    print("10-second warning sound: ${_settingsService.is10SecWarningEnabled ? 'ON' : 'OFF'}");
    setState(() {
      _currentFocusIndex = 2; // Update focus index when clicked directly
    });
  }

  // Handle keyboard navigation
  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        // Move focus left
        setState(() {
          if (_currentFocusIndex > 0) {
            _currentFocusIndex--;
          } else {
            _currentFocusIndex = 2; // Wrap around to sound toggle
          }
          _updateFocusBasedOnIndex();
        });
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        // Move focus right
        setState(() {
          if (_currentFocusIndex < 2) {
            _currentFocusIndex++;
          } else {
            _currentFocusIndex = 0; // Wrap around to timer
          }
          _updateFocusBasedOnIndex();
        });
      } else if (event.logicalKey == LogicalKeyboardKey.enter || 
                 event.logicalKey == LogicalKeyboardKey.select) {
        // Activate the current focused item
        if (_currentFocusIndex == 0) {
          _navigateToTimer();
        } else if (_currentFocusIndex == 1) {
          _navigateToCircuit();
        } else if (_currentFocusIndex == 2) {
          _toggleWarningSound();
        }
      }
    }
  }
  
  // Update focus based on current index
  void _updateFocusBasedOnIndex() {
    if (_currentFocusIndex == 0) {
      _timerFocusNode.requestFocus();
    } else if (_currentFocusIndex == 1) {
      _circuitFocusNode.requestFocus();
    } else if (_currentFocusIndex == 2) {
      _10secToggleFocusNode.requestFocus();
    }
  }

  // Focus on icon when returning to this screen
  void _restoreLastFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          // Restore focus to the last clicked icon
          _updateFocusBasedOnIndex();
        });
      }
    });
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
    // Get current state of 10-second warning
    final bool is10secWarningSound = _settingsService.is10SecWarningEnabled;
    
    return WillPopScope(
      onWillPop: () async {
        // Handle double back press to exit
        if (_lastBackPressTime == null || 
            DateTime.now().difference(_lastBackPressTime!) > Duration(seconds: 2)) {
          // If first press or more than 2 seconds since last press
          _lastBackPressTime = DateTime.now();
                    
          return false; // Don't exit yet
        }
        
        return true; // Exit the app on second press within 2 seconds
      },
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
                          onFocusChange: (hasFocus) {
                            if (hasFocus) {
                              setState(() {
                                _currentFocusIndex = 0;
                              });
                            }
                          },
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
                          onFocusChange: (hasFocus) {
                            if (hasFocus) {
                              setState(() {
                                _currentFocusIndex = 1;
                              });
                            }
                          },
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
                      SizedBox(width: 20),
                      GestureDetector(
                        onTap: _toggleWarningSound,
                        child: Focus(
                          focusNode: _10secToggleFocusNode,
                          onFocusChange: (hasFocus) {
                            if (hasFocus) {
                              setState(() {
                                _currentFocusIndex = 2;
                              });
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.all(0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(0),
                            ),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.08,
                              child: Image.asset(
                                is10secWarningSound 
                                  ? 'assets/images/10sec-on.png'
                                  : 'assets/images/10sec-off.png',
                                color: _10secToggleFocusNode.hasFocus ? Colors.blue : Colors.grey[700],
                                colorBlendMode: BlendMode.srcIn,
                              ),
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
      ),
    );
  }
}
