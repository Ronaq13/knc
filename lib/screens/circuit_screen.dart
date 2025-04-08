import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

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

  // Public getters for external access
  bool get isCircuitRunning => isRunning;
  bool get isCircuitCompleted => isCompleted;

  // Focus nodes for control buttons
  final FocusNode _pauseFocusNode = FocusNode();
  final FocusNode _resetFocusNode = FocusNode();

  // Time when pause was pressed
  Duration? _pausedRemaining;

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
  ];

  final List<Duration> breakOptions = [
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 45),
    Duration(minutes: 1),
    Duration(minutes: 2),
  ];

  final List<int> roundOptions = [3, 5, 8, 10, 12, 15, 18, 20, 25];
  int? _lastBeepSecond;

  late List<List<FocusNode>> _focusNodes;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick)..start();
    _focusNodes = [
      List.generate(intervalOptions.length, (_) => FocusNode()),
      List.generate(breakOptions.length, (_) => FocusNode()),
      List.generate(roundOptions.length, (_) => FocusNode()),
    ];
    
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0][0].requestFocus();
    });
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
      if (isCountdown) {
        // print("_onTick: Countdown finished, starting interval");
        isCountdown = false;
        _startInterval();
      } else if (isBreak) {
        // print("_onTick: Break finished, starting interval. Current round: $currentRound");
        _startInterval();
      } else {
        // Check if we've completed all rounds
        // print("_onTick: Interval finished, checking if all rounds completed. Current round: $currentRound, Total rounds: ${rounds ?? 0}");
        if (currentRound >= (rounds ?? 0)) {
          // print("_onTick: All rounds completed, completing workout");
          _completeWorkout();
        } else {
          // print("_onTick: Starting break for round $currentRound");
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
    if (isBreak) return;

    int secondsLeft = timeLeft.inSeconds;
    if (secondsLeft == 4 && _lastBeepSecond != secondsLeft) {
      _lastBeepSecond = secondsLeft;
      _playSound('end.mp3');
    } else if (secondsLeft > 4 || secondsLeft <= 0) {
      _lastBeepSecond = null;
    }
  }

  void _startCountdown() {
    // print("_startCountdown: Starting countdown, currentRound = $currentRound");
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
    // print("_startInterval: Before increment, currentRound = $currentRound");
    _playSound('start.mp3');
    setState(() {
      isBreak = false;
      isCountdown = false;
      totalPhaseDuration = interval!;
      remaining = interval!;
      
      // Only increment if we're not in the countdown phase
      // This ensures we don't increment twice when starting the circuit
      if (!isCountdown) {
        currentRound++;
        // print("_startInterval: After increment, currentRound = $currentRound");
      } else {
        // print("_startInterval: Skipping increment because isCountdown is true");
      }
      
      _lastBeepSecond = null;
      stopwatch
        ..reset()
        ..start();
    });
    
    // Ensure the pause button remains focused
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_pauseFocusNode.hasFocus) {
        _pauseFocusNode.requestFocus();
      }
    });
  }

  void _startBreak() {
    _audioPlayer.stop();

    // Check if we've completed all rounds
    if (currentRound >= (rounds ?? 0)) {
      _completeWorkout();
      return;
    }

    setState(() {
      isBreak = true;
      isCountdown = false;
      totalPhaseDuration = breakDuration!;
      remaining = breakDuration!;
      _lastBeepSecond = null;
      stopwatch
        ..reset()
        ..start();
    });
    
    // Ensure the pause button remains focused
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_pauseFocusNode.hasFocus) {
        _pauseFocusNode.requestFocus();
      }
    });
  }

  void _startCircuit() {
    // print("_startCircuit: Setting currentRound to 0");
    setState(() {
      isRunning = true;
      isCompleted = false;
      currentRound = 0; // Start from 0, will be incremented to 1 in _startInterval
      isPaused = false;
      isBreak = false;
      isCountdown = true; // Start with countdown
    });
    
    // Start with countdown instead of interval
    _startCountdown();
    
    // Set focus to pause button when circuit starts
    // Only if no button is currently focused and we're not transitioning from a button
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // Check if the focus is currently on the bottom navigation bar
      // If it is, don't request focus on the Pause button
      final currentFocus = FocusManager.instance.primaryFocus;
      final isBottomNavFocused = currentFocus != null && 
          (currentFocus != _pauseFocusNode && currentFocus != _resetFocusNode);
      
      if (!_pauseFocusNode.hasFocus && !_resetFocusNode.hasFocus && !isBottomNavFocused) {
        _pauseFocusNode.requestFocus();
      }
    });
  }

  void _togglePause() {
    setState(() {
      isPaused = !isPaused;
      if (isPaused) {
        // Store the remaining time when paused
        _pausedRemaining = remaining;
        stopwatch.stop();
      } else {
        // Adjust the total phase duration to account for pause time
        if (_pausedRemaining != null) {
          totalPhaseDuration = _pausedRemaining!;
          remaining = _pausedRemaining!;
          stopwatch.reset();
          stopwatch.start();
          _pausedRemaining = null;
        }
      }
    });
    
    // Ensure the pause/resume button remains focused
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_pauseFocusNode.hasFocus) {
        _pauseFocusNode.requestFocus();
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
  }

  void _resetState() {
    // print("_resetState: Resetting currentRound to 0");
    _audioPlayer.stop();
    setState(() {
      isRunning = false;
      isPaused = false;
      isCompleted = false;
      currentRound = 0; // Reset to 0
      isBreak = false;
      isCountdown = false;
      stopwatch.stop();
      _pausedRemaining = null;
    });
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  Widget _buildOptionButton<T>(
    T value,
    T? selected,
    void Function(T) onTap,
    FocusNode focusNode,
    int rowIndex,
    int colIndex,
  ) {
    return Focus(
      focusNode: focusNode,
      onKey: (FocusNode node, RawKeyEvent event) {
        if (event is! RawKeyDownEvent) return KeyEventResult.ignored;

        // Handle arrow key navigation
        if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
            event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.arrowDown ||
            event.logicalKey == LogicalKeyboardKey.arrowUp) {
          int newRow = rowIndex;
          int newCol = colIndex;

          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            // If we're on the rightmost button, prevent navigation
            if (colIndex >= _focusNodes[rowIndex].length - 1) {
              return KeyEventResult.handled;
            }
            newCol++;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            // If we're on the leftmost button, prevent navigation
            if (colIndex <= 0) {
              return KeyEventResult.handled;
            }
            newCol--;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            // If we're on the last available row, let the event propagate to the parent
            // to focus on the bottom navigation bar
            if (rowIndex >= _getLastAvailableRowIndex()) {
              return KeyEventResult.ignored;
            }
            newRow++;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            newRow--;
          }

          if (newRow >= 0 && newRow < _focusNodes.length) {
            if (newCol >= 0 && newCol < _focusNodes[newRow].length) {
              _focusNodes[newRow][newCol].requestFocus();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        }
        // Handle selection with Enter/OK key
        else if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter ||
            event.logicalKey == LogicalKeyboardKey.gameButtonSelect) {
          onTap(value);
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          final screenHeight = MediaQuery.of(context).size.height;
          final screenWidth = MediaQuery.of(context).size.width;
          final buttonHeight = screenHeight * 0.10;
          final buttonWidth = screenWidth * 0.10; // Adjust width as needed
          final fontSize = buttonHeight * 0.3; // 30% of height

          return GestureDetector(
            onTap: () => onTap(value),
            child: Container(
              height: buttonHeight,
              width: buttonWidth,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color:
                    selected == value
                        ? Colors.amber
                        : (isFocused ? Colors.blue : Colors.grey[800]),
                borderRadius: BorderRadius.circular(52),
                border: Border.all(
                  color: isFocused ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  value is Duration ? _format(value) : value.toString(),
                  style: TextStyle(fontSize: fontSize, color: Colors.white),
                ),
              ),
            ),
          );
        },
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
    required FocusNode focusNode,
    bool isLeftmost = false,
    bool isRightmost = false,
  }) {
    return Focus(
      focusNode: focusNode,
      onKey: (FocusNode node, RawKeyEvent event) {
        if (event is! RawKeyDownEvent) return KeyEventResult.ignored;

        // Handle left-right navigation
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          // If we're on the rightmost button, prevent navigation
          if (isRightmost) {
            return KeyEventResult.handled;
          }
          // Directly request focus on the next button
          if (label == 'Pause' || label == 'Resume') {
            _resetFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          // If we're on the leftmost button, prevent navigation
          if (isLeftmost) {
            return KeyEventResult.handled;
          }
          // Directly request focus on the previous button
          if (label == 'Reset') {
            _pauseFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        } 
        // Handle down arrow key to move focus to bottom navigation
        else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          // Let the event propagate to the parent to focus on the bottom navigation bar
          // This will prevent the focus from returning to the Pause button
          return KeyEventResult.ignored;
        }
        // Handle Enter/OK key press
        else if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter ||
            event.logicalKey == LogicalKeyboardKey.gameButtonSelect) {
          onPressed();
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          final screenHeight = MediaQuery.of(context).size.height;
          final screenWidth = MediaQuery.of(context).size.width;
          final buttonHeight = screenHeight * 0.10;
          final buttonWidth = screenWidth * 0.10; // Adjust width as needed
          final fontSize = buttonHeight * 0.3; // 30% of height

          return GestureDetector(
            onTap: onPressed,
            child: Container(
              height: buttonHeight,
              width: buttonWidth,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isFocused ? Colors.blue : Colors.grey[800],
                borderRadius: BorderRadius.circular(52),
                border: Border.all(
                  color: isFocused ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(fontSize: fontSize, color: Colors.white),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelection<T>(
    String label,
    List<T> options,
    T? selected,
    void Function(T) onTap,
    int rowIndex,
  ) {
    final screenHeight = MediaQuery.of(context).size.height;
    final labelHeight = screenHeight * 0.04;

    // Add debug print for rounds selection
    // if (label == 'Rounds') {
    //   print("_buildSelection: Building rounds selection, currentRound = $currentRound");
    // }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: labelHeight, color: Colors.black),
        ),
        Wrap(
          children: List.generate(
            options.length,
            (i) => _buildOptionButton<T>(
              options[i],
              selected,
              onTap,
              _focusNodes[rowIndex][i],
              rowIndex,
              i,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildControls() {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          buildTVButton(
            label: isPaused ? 'Resume' : 'Pause',
            onPressed: _togglePause,
            focusNode: _pauseFocusNode,
            isLeftmost: true,
          ),
          buildTVButton(
            label: 'Reset',
            onPressed: _resetState,
            focusNode: _resetFocusNode,
            isRightmost: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimerUI() {
    String title;
    if (isCompleted) {
      title = "Workout complete!";
    } else if (isBreak) {
      title = "Break time. Round $currentRound completed";
    } else {
      title = "Round $currentRound / $rounds";
    }
    
    // print("_buildTimerUI: Displaying title: $title, currentRound = $currentRound");

    final screenHeight = MediaQuery.of(context).size.height;
    final timerFontSize = screenHeight * 0.25; // 25% of height
    final titleFontSize = screenHeight * 0.05;

    // Only request focus if no button is currently focused and we're not transitioning from a button
    // This prevents the focus from returning to the Pause button when the down arrow key is pressed
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // Check if the focus is currently on the bottom navigation bar
      // If it is, don't request focus on the Pause button
      final currentFocus = FocusManager.instance.primaryFocus;
      final isBottomNavFocused = currentFocus != null && 
          (currentFocus != _pauseFocusNode && currentFocus != _resetFocusNode);
      
      if (!isCompleted && !_pauseFocusNode.hasFocus && !_resetFocusNode.hasFocus && !isBottomNavFocused) {
        _pauseFocusNode.requestFocus();
      }
    });

    return Container(
      // Ensure no focus border appears on this container
      decoration: BoxDecoration(
        border: null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: titleFontSize, color: Colors.black),
          ),
          const SizedBox(height: 16),
          Text(
            _format(remaining),
            style: TextStyle(fontSize: timerFontSize, color: Colors.black),
          ),
          const SizedBox(height: 32),
          if (!isCompleted) _buildControls(),
        ],
      ),
    );
  }

  Widget _buildConfigUI() {
    return Container(
      // Ensure no focus border appears on this container
      decoration: BoxDecoration(
        border: null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSelection<Duration>('Interval', intervalOptions, interval, (val) {
            setState(() => interval = val);

            if (breakDuration == null) {
              Future.delayed(const Duration(milliseconds: 100), () {
                _focusNodes[1][0].requestFocus(); // Focus Break row
              });
            }
          }, 0),
          if (interval != null)
            _buildSelection<Duration>('Break', breakOptions, breakDuration, (
              val,
            ) {
              setState(() => breakDuration = val);

              if (rounds == null) {
                Future.delayed(const Duration(milliseconds: 100), () {
                  _focusNodes[2][0].requestFocus(); // Focus Round row
                });
              }
            }, 1),
          if (interval != null && breakDuration != null)
            _buildSelection<int>('Rounds', roundOptions, rounds, (val) {
              setState(() {
                rounds = val;
                _startCircuit();
              });
            }, 2),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    stopwatch.stop();
    _audioPlayer.dispose();
    _pauseFocusNode.dispose();
    _resetFocusNode.dispose();
    for (var list in _focusNodes) {
      for (var node in list) {
        node.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: isRunning || isCompleted 
            ? Focus(
                // Use a non-traversable focus node to prevent body focus
                focusNode: FocusNode(skipTraversal: true, canRequestFocus: false),
                onKey: (FocusNode node, RawKeyEvent event) {
                  // Handle up arrow key to focus on the Pause button
                  if (event is RawKeyDownEvent && 
                      event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    // Only focus on the Pause button if the circuit is running
                    if (isRunning && !isCompleted) {
                      // Use a slight delay to ensure it works
                      Future.delayed(Duration(milliseconds: 10), () {
                        _pauseFocusNode.requestFocus();
                      });
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: Container(
                  // Ensure no focus border appears on this container
                  decoration: BoxDecoration(
                    border: null,
                  ),
                  child: _buildTimerUI(),
                ),
              )
            : _buildConfigUI(),
      ),
    );
  }

  // Method to directly focus the pause button
  void focusPauseButton() {
    if (!isRunning || isCompleted) return;
    
    // Request focus multiple times with increasing delays to ensure it gets applied
    _pauseFocusNode.requestFocus();
    
    // Try again with a slight delay
    Future.delayed(Duration(milliseconds: 10), () {
      if (!_pauseFocusNode.hasFocus) {
        _pauseFocusNode.requestFocus();
      }
    });
    
    // And once more with a longer delay
    Future.delayed(Duration(milliseconds: 50), () {
      if (!_pauseFocusNode.hasFocus) {
        _pauseFocusNode.requestFocus();
      }
    });
  }

  // Method to autofocus the first interval button or Pause button
  void autofocusFirstButton() {
    // If circuit is running, directly focus on the Pause button
    if (isRunning && !isCompleted) {
      // Use a slight delay to ensure UI is ready
      Future.delayed(Duration(milliseconds: 10), () {
        _pauseFocusNode.requestFocus();
      });
      return;
    }
    
    // Otherwise, if configuring, focus on appropriate config button
    if (!isRunning && !isCompleted && _focusNodes.isNotEmpty) {
      // Find the first available row
      int firstAvailableRow = 0;
      if (interval != null) {
        firstAvailableRow = 1;
        if (breakDuration != null) {
          firstAvailableRow = 2;
        }
      }
      
      // Focus on the first button in the first available row
      if (_focusNodes[firstAvailableRow].isNotEmpty) {
        _focusNodes[firstAvailableRow][0].requestFocus();
      }
    }
  }
}

// Extension to access the CircuitScreen state
extension CircuitScreenExtension on BuildContext {
  CircuitScreenState? get circuitScreenState => findAncestorStateOfType<CircuitScreenState>();
}
