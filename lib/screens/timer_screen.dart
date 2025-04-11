import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../services/settings_service.dart';

class TimerScreen extends StatefulWidget {
  TimerScreen({Key? key}) : super(key: key);

  @override
  TimerScreenState createState() => TimerScreenState();
}

class TimerScreenState extends State<TimerScreen> {
  final List<int> timerOptions = [
    15, 30, 45, 60, 90, 120, 150, 180,
    210, 240, 270, 300, 600, 1200, 1500, 1800
  ];

  Duration _selectedDuration = Duration.zero;
  Duration _remaining = Duration.zero;
  Stopwatch _stopwatch = Stopwatch();
  late final Ticker _ticker;
  bool _isRunning = false;
  bool _showInput = true;
  bool _isCountdown = false;
  bool _playedEndSound = false;
  bool _played10SecWarning = false;
  bool _isPaused = false;
  final AudioPlayer _player = AudioPlayer();
  final FocusNode _keyboardFocusNode = FocusNode();
  final FocusNode _pauseButtonFocusNode = FocusNode();
  final FocusNode _minutesFocusNode = FocusNode();
  final FocusNode _secondsFocusNode = FocusNode();
  final FocusNode _startButtonFocusNode = FocusNode();
  bool _isMinutesFocused = true;
  int _minutes = 0;
  int _seconds = 0;
  final Duration _countdownDuration = Duration(seconds: 3);
  
  // For the clock in the AppBar
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();
  
  // Settings service
  final SettingsService _settingsService = SettingsService();
  
  // For handling TV remote key presses
  String? _lastKeyPressed;
  DateTime _lastKeyPressTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick)..start();
    
    // Start clock timer
    _clockTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
    
    // Set initial focus to minutes section
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showInput) {
        _minutesFocusNode.requestFocus();
      }
    });
  }

  void _onTick(Duration elapsed) {
    if (_isRunning && !_isPaused) {
      final timeLeft = _isCountdown 
          ? _countdownDuration - _stopwatch.elapsed 
          : _selectedDuration - _stopwatch.elapsed;
      
      // Ensure we don't go below zero
      final sanitizedTimeLeft = timeLeft.isNegative ? Duration.zero : timeLeft;
          
      if (sanitizedTimeLeft == Duration.zero) {
        if (_isCountdown) {
          // Countdown is complete, start the actual timer
          _startActualTimer();
        } else if (_isRunning) { // Only handle completion once
          // Timer is complete - show 00:00
          setState(() {
            _remaining = Duration.zero;
            _isRunning = false; // Stop the timer
            _stopwatch.stop();
          });
          
          if (!_playedEndSound) {
            // Play the end sound and show input only after sound completes
            _playEndSound();
            _playedEndSound = true;
          }
        }
      } else {
        // Update the remaining time
        setState(() {
          _remaining = sanitizedTimeLeft;
        });
        
        // Check if we're at 10 seconds and should play warning sound
        if (!_isCountdown && !_played10SecWarning && 
            sanitizedTimeLeft.inSeconds <= 10 && sanitizedTimeLeft.inSeconds > 9 &&
            _settingsService.is10SecWarningEnabled) {
          _played10SecWarning = true;
          _playSound('10secLeft.mp3');
        }
        
        // If we're about to finish (last second), play the sound
        if (!_isCountdown && !_playedEndSound && sanitizedTimeLeft.inSeconds <= 1 && sanitizedTimeLeft.inMilliseconds <= 50) {
          _playEndSound();
          _playedEndSound = true;
        }
      }
    }
  }

  void _startCountdown() {
    _playSound('start.mp3');
    setState(() {
      _remaining = _countdownDuration;
      _isCountdown = true;
      _isRunning = true;
      _showInput = false;
      _playedEndSound = false;
      _played10SecWarning = false;
      _stopwatch..reset()..start();
    });
  }

  void _startActualTimer() {
    setState(() {
      _isCountdown = false;
      _isRunning = true;
      _remaining = _selectedDuration;
      _showInput = false;
      _playedEndSound = false;
      _played10SecWarning = false;
      _isPaused = false;
      _stopwatch..reset()..start();
    });
    
    // Focus the pause button when the timer starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_pauseButtonFocusNode.hasFocus) {
        _pauseButtonFocusNode.requestFocus();
      }
    });
  }

  Future<void> _playSound(String soundFile) async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/$soundFile'));
    } catch (e) {
    }
  }

  Future<void> _playEndSound() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/end.mp3'));
      
      // Show input UI after sound completes
      _player.onPlayerComplete.listen((event) {
        if (mounted && !_isCountdown && !_isRunning) {
          setState(() {
            _showInput = true;
            _minutes = 0;
            _seconds = 0;
          });
          
          // Request focus on minutes section
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _showInput) {
              _minutesFocusNode.requestFocus();
            }
          });
        }
      });
    } catch (e) {
      // If sound fails, still show input UI
      if (mounted && !_isCountdown && !_isRunning) {
        setState(() {
          _showInput = true;
          _minutes = 0;
          _seconds = 0;
        });
        
        // Request focus on minutes section
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _showInput) {
            _minutesFocusNode.requestFocus();
          }
        });
      }
    }
  }

  void _start() {
    if (_minutes == 0 && _seconds == 0) return;
    
    // Stop any existing timer first
    if (_isRunning) {
      _stop();
    }
    
    // Set the selected duration
    _selectedDuration = Duration(minutes: _minutes, seconds: _seconds);
    
    // Reset state completely before starting new countdown
    setState(() {
      _playedEndSound = false;
      _played10SecWarning = false;
      _showInput = false;
    });
    
    _startCountdown();
  }

  void _stop() {
    setState(() {
      _stopwatch.stop();
      _isRunning = false;
      _isCountdown = false;
      _isPaused = false;
    });
  }

  void _handleBackPress() {
    // Stop any playing sound
    _player.stop();
    
    if (_isRunning || _isCountdown) {
      // If timer is running or in countdown, stop it and show input
      setState(() {
        _stop();
        _showInput = true;
        _minutes = 0;
        _seconds = 0;
        _isMinutesFocused = true;
      });
      
      // Request focus on minutes section
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showInput) {
          _minutesFocusNode.requestFocus();
        }
      });
    } else {
      // If on input view, go back to home screen
      Navigator.of(context).pop();
    }
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        // Pause the stopwatch
        _stopwatch.stop();
      } else {
        // Resume the stopwatch
        _stopwatch.start();
      }
    });
    
    // Focus the pause button after toggling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_pauseButtonFocusNode.hasFocus) {
        _pauseButtonFocusNode.requestFocus();
      }
    });
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final minutes = two(d.inMinutes.remainder(60));
    final seconds = two(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _ticker.dispose();
    _stopwatch.stop();
    _player.dispose();
    _keyboardFocusNode.dispose();
    _pauseButtonFocusNode.dispose();
    _minutesFocusNode.dispose();
    _secondsFocusNode.dispose();
    _startButtonFocusNode.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  Widget _buildTimerInput() {
    final screenHeight = MediaQuery.of(context).size.height;
    final timerFontSize = screenHeight * 0.25;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Fixed height container for consistency with timer display
        Container(
          height: 50,
          alignment: Alignment.center,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Minutes section
            Focus(
              focusNode: _minutesFocusNode,
              onFocusChange: (hasFocus) {
                if (hasFocus) {
                  setState(() => _isMinutesFocused = true);
                }
              },
              onKey: (node, event) {
                if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
                
                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  setState(() {
                    _minutes = (_minutes + 1).clamp(0, 99);
                  });
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  setState(() {
                    _minutes = (_minutes - 1).clamp(0, 99);
                  });
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  _secondsFocusNode.requestFocus();
                  return KeyEventResult.handled;
                }
                
                return KeyEventResult.ignored;
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  _minutes.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: timerFontSize,
                    fontWeight: FontWeight.bold,
                    color: _minutesFocusNode.hasFocus ? Colors.blue : Colors.black,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            Text(
              ':',
              style: TextStyle(
                fontSize: timerFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                height: 1.0,
              ),
            ),
            // Seconds section
            Focus(
              focusNode: _secondsFocusNode,
              onFocusChange: (hasFocus) {
                if (hasFocus) {
                  setState(() => _isMinutesFocused = false);
                }
              },
              onKey: (node, event) {
                if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
                
                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  setState(() {
                    _seconds = (_seconds + 5).clamp(0, 55);
                  });
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  setState(() {
                    _seconds = (_seconds - 5).clamp(0, 55);
                  });
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  _minutesFocusNode.requestFocus();
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  _startButtonFocusNode.requestFocus();
                  return KeyEventResult.handled;
                }
                
                return KeyEventResult.ignored;
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  _seconds.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: timerFontSize,
                    fontWeight: FontWeight.bold,
                    color: _secondsFocusNode.hasFocus ? Colors.blue : Colors.black,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: screenHeight * 0.05),
        Container(
          height: 50,
          child: GestureDetector(
            onTap: _start,
            child: Focus(
              focusNode: _startButtonFocusNode,
              onKey: (node, event) {
                if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
                
                if (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.select) {
                  _start();
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  _secondsFocusNode.requestFocus();
                  return KeyEventResult.handled;
                }
                
                return KeyEventResult.ignored;
              },
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.play_arrow,
                  color: _startButtonFocusNode.hasFocus ? Colors.blue : Colors.black,
                  size: 40,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimerDisplay() {
    final screenHeight = MediaQuery.of(context).size.height;
    final timerFontSize = screenHeight * 0.25;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Fixed height container for "Starting Soon" text
        Container(
          height: 50,
          alignment: Alignment.center,
          child: _isCountdown
            ? Text(
                'Starting Soon',
                style: const TextStyle(
                  fontSize: 24,
                ),
                textAlign: TextAlign.center,
              )
            : Container(),
        ),
        const SizedBox(height: 20),
        Text(
          _format(_remaining),
          style: TextStyle(
            fontSize: timerFontSize,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: screenHeight * 0.05),
        Container(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isCountdown)
                GestureDetector(
                  onTap: _togglePause,
                  child: Focus(
                    focusNode: _pauseButtonFocusNode,
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _isPaused ? Icons.play_arrow : Icons.pause,
                        color: _pauseButtonFocusNode.hasFocus ? Colors.blue : Colors.black,
                        size: 40,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _keyboardFocusNode,
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          // Handle escape/back button
          if (event.logicalKey == LogicalKeyboardKey.escape || 
              event.logicalKey == LogicalKeyboardKey.goBack) {
            _handleBackPress();
            return;
          }
          
          // Handle space/pause when timer is running
          if ((event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.select) && _isRunning) {
            _togglePause();
            return;
          }
        }
      },
      autofocus: true,
      child: WillPopScope(
        onWillPop: () async {
          _handleBackPress();
          return false;
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(
              MediaQuery.of(context).size.height * 0.2,
            ),
            child: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              automaticallyImplyLeading: false,
              toolbarHeight: MediaQuery.of(context).size.height * 0.2,
              title: Container(
                height: MediaQuery.of(context).size.height * 0.2 * 0.8,
                child: Image.asset(
                  'assets/images/logo2.jpeg',
                  fit: BoxFit.contain,
                ),
              ),
              centerTitle: true,
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: _showInput 
                      ? _buildTimerInput()
                      : _buildTimerDisplay(),
                ),
                Container(
                  height: MediaQuery.of(context).size.height * 0.07,
                  width: double.infinity,
                  color: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '🥊 by Raounak Sharma',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.height * 0.02,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        '${_currentTime.hour > 12 ? _currentTime.hour - 12 : _currentTime.hour == 0 ? 12 : _currentTime.hour}:${_currentTime.minute.toString().padLeft(2, '0')} ${_currentTime.hour >= 12 ? 'PM' : 'AM'}',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.height * 0.05,
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
