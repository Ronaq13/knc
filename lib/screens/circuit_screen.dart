import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class CircuitScreen extends StatefulWidget {
  const CircuitScreen({Key? key}) : super(key: key);

  @override
  State<CircuitScreen> createState() => _CircuitScreenState();
}

class _CircuitScreenState extends State<CircuitScreen> {
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
        isCountdown = false;
        _startInterval();
      } else if (isBreak) {
        _startInterval();
      } else {
        if (currentRound < (rounds ?? 0)) {
          if (currentRound == (rounds ?? 0)) {
            _completeWorkout();
          } else {
            _startBreak();
          }
        } else {
          _completeWorkout();
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
      currentRound += 1;
      _lastBeepSecond = null;
      stopwatch
        ..reset()
        ..start();
    });
  }

  void _startBreak() {
    _audioPlayer.stop();

    if (currentRound >= (rounds ?? 0)) {
      _completeWorkout();
      return;
    }
    if (currentRound == 0) {
      _startInterval();
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
  }

  void _startCircuit() {
    setState(() {
      isRunning = true;
      isCompleted = false;
      currentRound = 0;
      isPaused = false;
    });
    _startInterval();

    // Set focus to pause button when circuit starts
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pauseFocusNode.requestFocus();
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
    _audioPlayer.stop();
    setState(() {
      isRunning = false;
      isPaused = false;
      isCompleted = false;
      currentRound = 0;
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

          if (event.logicalKey == LogicalKeyboardKey.arrowRight)
            newCol++;
          else if (event.logicalKey == LogicalKeyboardKey.arrowLeft)
            newCol--;
          else if (event.logicalKey == LogicalKeyboardKey.arrowDown)
            newRow++;
          else if (event.logicalKey == LogicalKeyboardKey.arrowUp)
            newRow--;

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

  Widget buildTVButton({
    required String label,
    required VoidCallback onPressed,
    required FocusNode focusNode,
  }) {
    return Focus(
      focusNode: focusNode,
      onKey: (FocusNode node, RawKeyEvent event) {
        if (event is! RawKeyDownEvent) return KeyEventResult.ignored;

        // Handle left-right navigation
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          FocusScope.of(node.context!).nextFocus();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          FocusScope.of(node.context!).previousFocus();
          return KeyEventResult.handled;
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
          ),
          buildTVButton(
            label: 'Reset',
            onPressed: _resetState,
            focusNode: _resetFocusNode,
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
      title = "Round $currentRound completed";
    } else {
      title = "Round $currentRound / $rounds";
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final timerFontSize = screenHeight * 0.25; // 25% of height
    final titleFontSize = screenHeight * 0.05;

    return Column(
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
    );
  }

  Widget _buildConfigUI() {
    return Column(
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
        child: isRunning || isCompleted ? _buildTimerUI() : _buildConfigUI(),
      ),
    );
  }
}
