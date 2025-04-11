import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/timer_screen.dart';
import 'screens/circuit_screen.dart';
import 'services/settings_service.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  final FocusNode _timerFocusNode = FocusNode(debugLabel: 'Timer');
  final FocusNode _circuitFocusNode = FocusNode(debugLabel: 'Circuit');
  final FocusNode _10secToggleFocusNode = FocusNode(debugLabel: '10secToggle');
  final SettingsService _settingsService = SettingsService();
  DateTime? _lastBackPressTime;
  DateTime _lastKeyTime = DateTime.now();

  int _currentFocusIndex = 0;
  List<FocusNode> get _focusNodes => [_timerFocusNode, _circuitFocusNode, _10secToggleFocusNode];

  void _logEvent(String message) {
    final now = DateTime.now();
    final timeString = "${now.hour}:${now.minute}:${now.second}.${now.millisecond}";
    print("[$timeString] $message");
  }

  void _handleLeftArrow() {
    _logEvent("Current focus is on: ${_focusNodes[_currentFocusIndex].debugLabel} (index: $_currentFocusIndex)");
    
    // Do nothing if we're already at the leftmost icon (timer)
    if (_currentFocusIndex == 0) {
      _logEvent("Already at leftmost icon (Timer), no focus change needed");
      return;
    }
    
    int newIndex = _currentFocusIndex - 1;
    _logEvent("Will change focus to: ${_focusNodes[newIndex].debugLabel} (index: $newIndex)");
    
    setState(() {
      _currentFocusIndex = newIndex;
      _focusNodes[_currentFocusIndex].requestFocus();
      _logEvent("Focus changed to: ${_focusNodes[_currentFocusIndex].debugLabel} (index: $_currentFocusIndex)");
    });
  }

  void _handleRightArrow() {
    _logEvent("Current focus is on: ${_focusNodes[_currentFocusIndex].debugLabel} (index: $_currentFocusIndex)");
    
    // Do nothing if we're already at the rightmost icon (10sec)
    if (_currentFocusIndex == _focusNodes.length - 1) {
      _logEvent("Already at rightmost icon (10sec), no focus change needed");
      return;
    }
    
    int newIndex = _currentFocusIndex + 1;
    _logEvent("Will change focus to: ${_focusNodes[newIndex].debugLabel} (index: $newIndex)");
    
    setState(() {
      _currentFocusIndex = newIndex;
      _focusNodes[_currentFocusIndex].requestFocus();
      _logEvent("Focus changed to: ${_focusNodes[_currentFocusIndex].debugLabel} (index: $_currentFocusIndex)");
    });
  }

  void _handleSelection() {
    _logEvent("Selection triggered - Current focus is on: ${_focusNodes[_currentFocusIndex].debugLabel} (index: $_currentFocusIndex)");
    
    // Use the current focus index directly to determine action
    switch (_currentFocusIndex) {
      case 0:
        _logEvent("Executing Timer action");
        _navigateToTimer();
        break;
      case 1:
        _logEvent("Executing Circuit action");
        _navigateToCircuit();
        break;
      case 2:
        _logEvent("Executing 10sec toggle action");
        _toggleWarningSound();
        break;
    }
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    final now = DateTime.now();
    if (now.difference(_lastKeyTime).inMilliseconds < 150) return;
    _lastKeyTime = now;

    _logEvent("Key pressed: ${event.logicalKey.keyLabel}");
    _logEvent("Current focus index: $_currentFocusIndex (${_focusNodes[_currentFocusIndex].debugLabel})");

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _handleLeftArrow();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _handleRightArrow();
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.space) {
      _handleSelection();
    }
  }

  void _navigateToTimer() {
    _logEvent("Navigating to Timer screen");
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) {
        _logEvent("Building Timer screen");
        return TimerScreen();
      }),
    ).then((_) {
      _logEvent("Returned from Timer screen");
      _timerFocusNode.requestFocus();
    });
  }

  void _navigateToCircuit() {
    _logEvent("Navigating to Circuit screen");
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) {
        _logEvent("Building Circuit screen");
        return CircuitScreen();
      }),
    ).then((_) {
      _logEvent("Returned from Circuit screen");
      _circuitFocusNode.requestFocus();
    });
  }

  void _toggleWarningSound() {
    _logEvent("Toggling 10-second warning sound");
    _logEvent("Current warning sound state: ${_settingsService.is10SecWarningEnabled}");
    
    setState(() {
      _settingsService.toggle10SecWarning();
    });
    
    _logEvent("New warning sound state: ${_settingsService.is10SecWarningEnabled}");
  }

  @override
  void initState() {
    super.initState();

    _clockTimer = Timer.periodic(Duration(seconds: 1), (_) {
      setState(() => _currentTime = DateTime.now());
    });

    // Set initial focus to Timer icon
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timerFocusNode.requestFocus();
      _logEvent("Initial focus set to Timer");
    });

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    for (var node in _focusNodes) {
      node.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool is10secWarningSound = _settingsService.is10SecWarningEnabled;
    _logEvent("Building UI with warning sound state: $is10secWarningSound");
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        
        if (_lastBackPressTime == null || 
            DateTime.now().difference(_lastBackPressTime!) > Duration(seconds: 2)) {
          _lastBackPressTime = DateTime.now();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(MediaQuery.of(context).size.height * 0.2),
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
          child: RawKeyboardListener(
            focusNode: FocusNode(skipTraversal: true, debugLabel: 'MainListener'),
            onKey: _handleKeyEvent,
            child: Column(
              children: [
                Expanded(flex: 1, child: Container()),

                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      '${_currentTime.hour > 12 ? _currentTime.hour - 12 : _currentTime.hour == 0 ? 12 : _currentTime.hour}:${_currentTime.minute.toString().padLeft(2, '0')} ${_currentTime.hour >= 12 ? 'PM' : 'AM'}',
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
                      // Timer icon
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
                              color: _currentFocusIndex == 0 ? Colors.blue : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 20),
                      
                      // Circuit icon
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
                              color: _currentFocusIndex == 1 ? Colors.blue : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 20),
                      
                      // 10-second warning toggle
                      GestureDetector(
                        onTap: () {
                          _logEvent("10sec toggle tapped via GestureDetector");
                          _toggleWarningSound();
                        },
                        child: Focus(
                          focusNode: _10secToggleFocusNode,
                          child: Container(
                            padding: EdgeInsets.all(0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.08,
                              child: Image.asset(
                                is10secWarningSound 
                                  ? 'assets/images/10sec-on.png'
                                  : 'assets/images/10sec-off.png',
                                color: _currentFocusIndex == 2 ? Colors.blue : Colors.grey[700],
                                colorBlendMode: BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Bottom bar with attribution
                Container(
                  height: MediaQuery.of(context).size.height * 0.07,
                  width: double.infinity,
                  color: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '🛠️ by Raounak Sharma 🥊',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.height * 0.02,
                          color: Colors.grey[800],
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