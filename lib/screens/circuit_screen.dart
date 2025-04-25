import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import '../services/settings_service.dart';

class CircuitScreen extends StatefulWidget {
  const CircuitScreen({Key? key}) : super(key: key);

  @override
  State<CircuitScreen> createState() => CircuitScreenState();
}

class CircuitScreenState extends State<CircuitScreen> {
  Duration? interval;
  Duration? breakDuration;
  int? rounds;

  int currentRound = 0;
  bool isRunning = false;
  bool isPaused = false;
  bool isBreak = false;
  bool isCountdown = true;
  bool isCompleted = false;
  Duration remaining = Duration.zero;
  Duration totalPhaseDuration = Duration.zero;
  Stopwatch stopwatch = Stopwatch();
  late final Ticker _ticker;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Duration countdownTime = Duration(seconds: 3);
  final FocusNode _keyboardFocusNode = FocusNode();
  final SettingsService _settingsService = SettingsService();
  bool _played10SecWarning = false;
  
  // For clock in bottom nav
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  // Public getters for external access
  bool get isCircuitRunning => isRunning;
  bool get isCircuitCompleted => isCompleted;

  // Time when pause was pressed
  Duration? _pausedRemaining;

  // Define options as instance variables rather than getters
  final List<Duration> intervalOptions = [
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 45),
    Duration(minutes: 1),
    Duration(minutes: 1, seconds: 30),
    Duration(minutes: 2),
    Duration(minutes: 2, seconds: 30),
    Duration(minutes: 3),
    Duration(minutes: 3, seconds: 30),
    Duration(minutes: 4),
    Duration(minutes: 5),
    Duration(minutes: 8),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 20),
    Duration(minutes: 30),
  ];

  final List<Duration> breakOptions = [
    Duration(seconds: 0),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 45),
    Duration(minutes: 1),
    Duration(minutes: 2),
  ];

  final List<int> roundOptions = [3, 5, 8, 10, 12, 15, 18, 20];
  int? _lastBeepSecond;

  // Focus nodes for option buttons
  late List<FocusNode> _intervalFocusNodes;
  late List<FocusNode> _breakFocusNodes;
  late List<FocusNode> _roundFocusNodes;
  late FocusNode _pauseButtonFocusNode;
  
  // Track which type of option is currently focused (0=interval, 1=break, 2=rounds)
  int _currentRowIndex = 0;
  // Track which option in the current row is focused
  int _currentColIndex = 0;

  // For custom input
  bool _showInput = true;
  bool _playedEndSound = false;
  final FocusNode _intervalMinutesFocusNode = FocusNode();
  final FocusNode _intervalSecondsFocusNode = FocusNode();
  final FocusNode _breakMinutesFocusNode = FocusNode();
  final FocusNode _breakSecondsFocusNode = FocusNode();
  final FocusNode _roundsFocusNode = FocusNode();
  final FocusNode _startButtonFocusNode = FocusNode();
  
  int _intervalMinutes = 0;
  int _intervalSeconds = 0;
  int _breakMinutes = 0;
  int _breakSeconds = 0;
  int _roundsCount = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick)..start();
    
    // Initialize clock timer
    _clockTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
    
    // Initialize focus nodes for all options
    _intervalFocusNodes = List<FocusNode>.generate(
      intervalOptions.length,
      (index) => FocusNode(),
    );
    
    _breakFocusNodes = List<FocusNode>.generate(
      breakOptions.length,
      (index) => FocusNode(),
    );
    
    _roundFocusNodes = List<FocusNode>.generate(
      roundOptions.length,
      (index) => FocusNode(),
    );
    
    _pauseButtonFocusNode = FocusNode();
    
    // Set initial focus directly
    _intervalMinutesFocusNode.requestFocus();
  }

  void _onTick(Duration elapsed) {
    if (!isRunning || isPaused) return;

    final timeLeft = totalPhaseDuration - stopwatch.elapsed;
    if (timeLeft <= Duration.zero) {
      _audioPlayer.stop();
      stopwatch
        ..stop()
        ..reset();
      _lastBeepSecond = null;
      _played10SecWarning = false;
      if (isCountdown) {
        isCountdown = false;
        _startInterval();
      } else if (isBreak) {
        _startInterval();
      } else {
        if (currentRound >= (rounds ?? 0)) {
            _completeWorkout();
        } else {
          // Increment round after an interval completes but before starting break
          setState(() {
            currentRound++;
          });
          _startBreak();
        }
      }
    } else {
      _maybePlayBeep(timeLeft);
      setState(() {
        remaining = timeLeft;
      });
    }
  }

  void _maybePlayBeep(Duration timeLeft) {    
    // Don't play sounds during countdown
    if (isCountdown) return;

    // Check for 10-second warning during interval
    if (!isBreak && !_played10SecWarning && 
        timeLeft.inSeconds <= 10 && timeLeft.inSeconds > 9 &&
        _settingsService.is10SecWarningEnabled) {
      _played10SecWarning = true;
      _playSound('10secLeft.mp3');
    }

    // Only play end sound during interval (not during break)
    // Also ensure we're not in a break
    if (!isBreak) {
      int secondsLeft = timeLeft.inSeconds;
      if (secondsLeft == 1 && _lastBeepSecond != secondsLeft) {
        _lastBeepSecond = secondsLeft;
        _playSound('end.mp3');
      } else if (secondsLeft > 1 || secondsLeft <= 0) {
        _lastBeepSecond = null;
      }
    }
  }

  void _startCountdown() {
    setState(() {
      isBreak = false;
      isCountdown = true;
      totalPhaseDuration = countdownTime;
      remaining = countdownTime;
      _lastBeepSecond = null;
      stopwatch
        ..reset()
        ..start();
    });
  }

  Future<void> _playSound(String soundFile) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/$soundFile'));
    } catch (e) {
      debugPrint('Error playing sound $soundFile: $e');
    }
  }

  void _startInterval() {
    _playSound('start.mp3');

    setState(() {
      isBreak = false;
      isCountdown = false;
      totalPhaseDuration = interval!;
      remaining = interval!;
      _lastBeepSecond = null;
      _played10SecWarning = false;
      stopwatch
        ..reset()
        ..start();
    });
  }

  void _startBreak() {
    _audioPlayer.stop();

    // If break duration is 0, handle countdown or direct start
    if (breakDuration!.inSeconds == 0) {
      // For rounds after first, show countdown
      if (currentRound > 1) {
        setState(() {
          isBreak = false;
          isCountdown = true;
          totalPhaseDuration = countdownTime;
          remaining = countdownTime;
          _lastBeepSecond = null;
          stopwatch.reset();
          stopwatch.start();
        });
      } else {
        // For first round, start interval directly
        _startInterval();
      }
      return;
    }

    setState(() {
      isBreak = true;
      isCountdown = false;
      totalPhaseDuration = breakDuration!;
      remaining = breakDuration!;
      _lastBeepSecond = null;
      _played10SecWarning = false;
      stopwatch.reset();
      stopwatch.start();
    });
  }

  void _startCircuit() {
    // Validate inputs
    if (_intervalMinutes == 0 && _intervalSeconds == 0) return;
    if (_roundsCount == 0) return;

    // Stop any existing timers and audio
    _audioPlayer.stop();
    stopwatch.stop();

    setState(() {
      // Set new durations
      interval = Duration(minutes: _intervalMinutes, seconds: _intervalSeconds);
      breakDuration = Duration(minutes: _breakMinutes, seconds: _breakSeconds);
      rounds = _roundsCount;
      
      // Reset all state for new circuit
      _showInput = false;
      isRunning = true;
      isCountdown = true;
      isBreak = false;
      isPaused = false;
      currentRound = 1;
      
      // Reset timers and flags
      remaining = countdownTime;
      totalPhaseDuration = countdownTime;
      _pausedRemaining = null;
      _playedEndSound = false;
      _played10SecWarning = false;
      _lastBeepSecond = null;
      
      // Reset and start stopwatch
      stopwatch.reset();
      stopwatch.start();
    });
  }

  void _togglePause() {
    setState(() {
      isPaused = !isPaused;
      if (isPaused) {
        // Store the remaining time when paused
        _pausedRemaining = remaining;
        stopwatch.stop();
        // Pause audio playback
        _audioPlayer.pause();
      } else {
        // Adjust the total phase duration to account for pause time
        if (_pausedRemaining != null) {
          totalPhaseDuration = _pausedRemaining!;
          remaining = _pausedRemaining!;
          stopwatch.reset();
          stopwatch.start();
          _pausedRemaining = null;
          // Resume audio playback if it was paused
          _audioPlayer.resume();
        }
      }
    });
    
    // Focus the pause button after toggling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_pauseButtonFocusNode.hasFocus) {
        _pauseButtonFocusNode.requestFocus();
      }
    });
  }

  void _completeWorkout() {
    _audioPlayer.stop();
    setState(() {
      isCompleted = true;
      isRunning = false;
      isPaused = false;
      stopwatch.stop();
    });
    
    // Return to home screen after workout is complete
    Navigator.of(context).pop();
  }

  void _resetState() {
    _audioPlayer.stop();
    setState(() {
      isRunning = false;
      isPaused = false;
      isCompleted = false;
      currentRound = 1; // Reset to 1
      isBreak = false;
      isCountdown = false;
      stopwatch.stop();
      _pausedRemaining = null;
      _currentRowIndex = 0;
      _currentColIndex = 0;
    });
    
    // Ensure keyboard focus is maintained when resetting
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _intervalFocusNodes.isNotEmpty) {
        _intervalFocusNodes[0].requestFocus();
      }
    });
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final minutes = two(d.inMinutes.remainder(60));
    final seconds = two(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildOptionButton<T>(
    T value,
    T? selected,
    void Function(T) onTap,
    int rowIndex,
    int colIndex,
  ) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonHeight = screenHeight * 0.10;
    final buttonWidth = screenWidth * 0.10; // Adjust width as needed
    final fontSize = buttonHeight * 0.3; // 30% of height

    // Determine if this button should be focused
    FocusNode? focusNode;
    bool isFocused = false;
    
    // Handle different types of focus nodes based on row index
    if (rowIndex == 0 && colIndex < _intervalFocusNodes.length) {
      focusNode = _intervalFocusNodes[colIndex];
      isFocused = focusNode.hasFocus;
    } else if (rowIndex == 1 && colIndex < _breakFocusNodes.length) {
      focusNode = _breakFocusNodes[colIndex];
      isFocused = focusNode.hasFocus;
    } else if (rowIndex == 2 && colIndex < _roundFocusNodes.length) {
      focusNode = _roundFocusNodes[colIndex];
      isFocused = focusNode.hasFocus;
    }

    if (focusNode == null) {
      if (rowIndex == 0) {
        focusNode = FocusNode();
        if (_intervalFocusNodes.length <= colIndex) {
          _intervalFocusNodes.add(focusNode);
        } else {
          focusNode = _intervalFocusNodes[colIndex];
        }
      } else if (rowIndex == 1) {
        focusNode = FocusNode();
        if (_breakFocusNodes.length <= colIndex) {
          _breakFocusNodes.add(focusNode);
        } else {
          focusNode = _breakFocusNodes[colIndex];
        }
      } else if (rowIndex == 2) {
        focusNode = FocusNode();
        if (_roundFocusNodes.length <= colIndex) {
          _roundFocusNodes.add(focusNode);
        } else {
          focusNode = _roundFocusNodes[colIndex];
        }
      }
    }

    return GestureDetector(
      onTap: () => onTap(value),
      child: Focus(
        focusNode: focusNode,
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            setState(() {
              _currentRowIndex = rowIndex;
              _currentColIndex = colIndex;
            });
          }
        },
            child: Container(
              height: buttonHeight,
              width: buttonWidth,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
            color: isFocused 
                  ? Colors.blue 
                  : selected == value 
                        ? Colors.amber
                      : Colors.grey[800],
                borderRadius: BorderRadius.circular(52),
                border: Border.all(
                  color: isFocused ? Colors.white : Colors.transparent,
                ),
              ),
              child: Center(
                child: Text(
                  value is Duration ? _format(value) : value.toString(),
                  style: TextStyle(fontSize: fontSize, color: Colors.white),
                ),
              ),
            ),
      ),
    );
  }

  // Helper method to determine the last available row index based on selected values
  int _getLastAvailableRowIndex() {
    if (interval == null) {
      return 0; // Only Interval row is available
    } else if (breakDuration == null) {
      return 1; // Interval and Break rows are available
    } else {
      return 2; // All rows are available
    }
  }

  Widget buildTVButton({
    required String label,
    required VoidCallback onPressed,
  }) {
          final screenHeight = MediaQuery.of(context).size.height;
          final screenWidth = MediaQuery.of(context).size.width;
          final buttonHeight = screenHeight * 0.10;
    final minButtonWidth = screenWidth * 0.10; // Adjust width as needed
          final fontSize = buttonHeight * 0.3; // 30% of height

          return GestureDetector(
            onTap: onPressed,
            child: Container(
              height: buttonHeight,
        constraints: BoxConstraints(
          minWidth: minButtonWidth,
        ),
        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        margin: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
          color: Colors.grey[800],
                borderRadius: BorderRadius.circular(52),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(fontSize: fontSize, color: Colors.white),
                ),
              ),
      ),
    );
  }

  Widget _buildTimerDisplay() {
    final screenHeight = MediaQuery.of(context).size.height;
    final timerFontSize = screenHeight * 0.25;

    // Ensure pause button has focus when timer is running
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && isRunning && !isCountdown && !_pauseButtonFocusNode.hasFocus) {
        _pauseButtonFocusNode.requestFocus();
      }
    });

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
      children: [
          // Fixed height container for the text to prevent layout shifts
          Container(
            height: 50, // Fixed height for title area
            alignment: Alignment.center,
            child: Text(
              isCountdown 
                ? 'Starting Soon' 
                : isBreak 
                  ? 'Break' 
                  : 'Round $currentRound / ${rounds ?? 0}',
              style: const TextStyle(
                fontSize: 24,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _format(remaining),
            style: TextStyle(
              fontSize: timerFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
          // Constant spacing between timer and button area
          SizedBox(height: screenHeight * 0.05),
          // Fixed height area for button to prevent layout shifts
          Container(
            height: 72,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
                if (!isCountdown)
                GestureDetector(
                  onTap: _togglePause,
                  child: Focus(
                    focusNode: _pauseButtonFocusNode,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.enter ||
                            event.logicalKey == LogicalKeyboardKey.select ||
                            event.logicalKey == LogicalKeyboardKey.space) {
                          _togglePause();
                          return KeyEventResult.handled;
                        }
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
                        isPaused ? Icons.play_arrow : Icons.pause,
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
      ),
    );
  }

  Widget _buildCircuitInput() {
    final screenHeight = MediaQuery.of(context).size.height;
    final timerFontSize = screenHeight * 0.12;
    final labelFontSize = screenHeight * 0.02;
    final verticalSpacing = screenHeight * 0.02;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Interval Input
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Interval',
                style: TextStyle(
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: verticalSpacing * 0.3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Focus(
                    focusNode: _intervalMinutesFocusNode,
                    onFocusChange: (hasFocus) {
                      if (hasFocus) {
                        setState(() {
                          // This will trigger a rebuild only this UI when focus changes.
                          // This is required to ensure that the focus node is updated instantly.
                        });
                      }
                    },
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          setState(() {
                            _intervalMinutes = (_intervalMinutes - 1).clamp(0, 99);
                          });
                          return KeyEventResult.handled;
                        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          setState(() {
                            _intervalMinutes = (_intervalMinutes + 1).clamp(0, 99);
                          });
                          return KeyEventResult.handled;
                        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                          _intervalSecondsFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        _intervalMinutes.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: timerFontSize,
                          fontWeight: FontWeight.bold,
                          color: _intervalMinutesFocusNode.hasFocus ? Colors.blue : Colors.black,
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
                  Focus(
                    focusNode: _intervalSecondsFocusNode,
                    onFocusChange: (hasFocus) {
                      if (hasFocus) {
                        setState(() {
                          // This will trigger a rebuild only this UI when focus changes.
                          // This is required to ensure that the focus node is updated instantly.
                        });
                      }
                    },
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          setState(() {
                            _intervalSeconds = (_intervalSeconds - 5).clamp(0, 55);
                          });
                          return KeyEventResult.handled;
                        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          setState(() {
                            _intervalSeconds = (_intervalSeconds + 5).clamp(0, 55);
                          });
                          return KeyEventResult.handled;
                        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                          _intervalMinutesFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                          _breakMinutesFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        _intervalSeconds.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: timerFontSize,
                          fontWeight: FontWeight.bold,
                          color: _intervalSecondsFocusNode.hasFocus ? Colors.blue : Colors.black,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: verticalSpacing),

          // Break Input
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Break',
                style: TextStyle(
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: verticalSpacing * 0.3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Focus(
                    focusNode: _breakMinutesFocusNode,
                    onFocusChange: (hasFocus) {
                      if (hasFocus) {
                        setState(() {
                          // This will trigger a rebuild only this UI when focus changes.
                          // This is required to ensure that the focus node is updated instantly.
                        });
                      }
                    },
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          setState(() {
                            _breakMinutes = (_breakMinutes - 1).clamp(0, 99);
                          });
                          return KeyEventResult.handled;
                        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          setState(() {
                            _breakMinutes = (_breakMinutes + 1).clamp(0, 99);
                          });
                          return KeyEventResult.handled;
                        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                          _breakSecondsFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                          _intervalSecondsFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        _breakMinutes.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: timerFontSize,
                          fontWeight: FontWeight.bold,
                          color: _breakMinutesFocusNode.hasFocus ? Colors.blue : Colors.black,
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
                  Focus(
                    focusNode: _breakSecondsFocusNode,
                    onFocusChange: (hasFocus) {
                      if (hasFocus) {
                        setState(() {
                          // This will trigger a rebuild only this UI when focus changes.
                          // This is required to ensure that the focus node is updated instantly.
                        });
                      }
                    },
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          setState(() {
                            _breakSeconds = (_breakSeconds - 5).clamp(0, 55);
                          });
                          return KeyEventResult.handled;
                        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          setState(() {
                            _breakSeconds = (_breakSeconds + 5).clamp(0, 55);
                          });
                          return KeyEventResult.handled;
                        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                          _breakMinutesFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                          _roundsFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        _breakSeconds.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: timerFontSize,
                          fontWeight: FontWeight.bold,
                          color: _breakSecondsFocusNode.hasFocus ? Colors.blue : Colors.black,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: verticalSpacing),

          // Rounds Input
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rounds',
                style: TextStyle(
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: verticalSpacing * 0.3),
              Focus(
                focusNode: _roundsFocusNode,
                onFocusChange: (hasFocus) {
                  if (hasFocus) {
                    setState(() {
                      // This will trigger a rebuild only this UI when focus changes.
                      // This is required to ensure that the focus node is updated instantly.
                    });
                  }
                },
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      setState(() {
                        _roundsCount = (_roundsCount - 1).clamp(0, 99);
                      });
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      setState(() {
                        _roundsCount = (_roundsCount + 1).clamp(0, 99);
                      });
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      _breakSecondsFocusNode.requestFocus();
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                      _startButtonFocusNode.requestFocus();
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    _roundsCount.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: timerFontSize,
                      fontWeight: FontWeight.bold,
                      color: _roundsFocusNode.hasFocus ? Colors.blue : Colors.black,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: verticalSpacing * 1.5),

          // Start Button
          Container(
            height: screenHeight * 0.06,
            child: GestureDetector(
              onTap: _startCircuit,
              child: Focus(
                focusNode: _startButtonFocusNode,
                onFocusChange: (hasFocus) {
                  if (hasFocus) {
                    setState(() {
                      // This will trigger a rebuild only this UI when focus changes.
                      // This is required to ensure that the focus node is updated instantly.
                    });
                  }
                },
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.select) {
                      _startCircuit();
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      _roundsFocusNode.requestFocus();
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                      return KeyEventResult.handled;
                    }
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _keyboardFocusNode,
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          // Only handle escape/back button at root level
          if (event.logicalKey == LogicalKeyboardKey.escape || 
              event.logicalKey == LogicalKeyboardKey.goBack) {
            _handleBackPress();
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
                      ? _buildCircuitInput()
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
                      // Left side with QR code and text
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(
                                text: 'https://www.linkedin.com/in/raounak-sharma/'
                              ));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('LinkedIn URL copied to clipboard'),
                                  duration: Duration(seconds: 2),
                                )
                              );
                            },
                            child: Container(
                              height: MediaQuery.of(context).size.height * 0.05,
                              width: MediaQuery.of(context).size.height * 0.05,
                              margin: EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey[400]!,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: QrImageView(
                                data: 'https://www.linkedin.com/in/raounak-sharma/',
                                version: QrVersions.auto,
                                size: MediaQuery.of(context).size.height * 0.045,
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: EdgeInsets.zero,
                                gapless: true,
                              ),
                            ),
                          ),
                          Text(
                            '🛠️ by Raounak Sharma',
                            style: TextStyle(
                              fontSize: MediaQuery.of(context).size.height * 0.02,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      // Right side with clock
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

  @override
  void dispose() {
    _ticker.dispose();
    stopwatch.stop();
    _audioPlayer.dispose();
    _keyboardFocusNode.dispose();
    _pauseButtonFocusNode.dispose();
    _intervalMinutesFocusNode.dispose();
    _intervalSecondsFocusNode.dispose();
    _breakMinutesFocusNode.dispose();
    _breakSecondsFocusNode.dispose();
    _roundsFocusNode.dispose();
    _startButtonFocusNode.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  void _handleBackPress() {
    if (isRunning) {
      // If timer is running, stop it and reset everything
      setState(() {
        _audioPlayer.stop();
        isRunning = false;
        isPaused = false;
        isCountdown = false;
        isBreak = false;
        _showInput = true;
        stopwatch.stop();
        
        // Reset all input values
        _intervalMinutes = 0;
        _intervalSeconds = 0;
        _breakMinutes = 0;
        _breakSeconds = 0;
        _roundsCount = 0;
        
        // Reset stored durations
        interval = null;
        breakDuration = null;
        rounds = null;
        currentRound = 0;
        
        // Reset remaining time
        remaining = Duration.zero;
        totalPhaseDuration = Duration.zero;
        _pausedRemaining = null;
        
        // Reset flags
        _playedEndSound = false;
        _played10SecWarning = false;
        _lastBeepSecond = null;
      });
      
      // Set focus back to interval minutes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _intervalMinutesFocusNode.requestFocus();
        }
      });
    } else {
      // If not running, just pop back to previous screen
      Navigator.of(context).pop();
    }
  }
}