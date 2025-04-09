import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
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
  final FocusNode _keyboardFocusNode = FocusNode();

  // Public getters for external access
  bool get isCircuitRunning => isRunning;
  bool get isCircuitCompleted => isCompleted;

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

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick)..start();
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
    // Play start sound when 3 seconds left in break phase
    if (isBreak) {
      int secondsLeft = timeLeft.inSeconds;
      if (secondsLeft == 3 && _lastBeepSecond != secondsLeft) {
        _lastBeepSecond = secondsLeft;
        _playSound('start.mp3');
      }
      return;
    }
    
    // Don't play sounds during countdown
    if (isCountdown) return;

    // Only play end sound during interval (not during break)
    int secondsLeft = timeLeft.inSeconds;
    if (secondsLeft == 1 && _lastBeepSecond != secondsLeft) {
      _lastBeepSecond = secondsLeft;
      _playSound('end.mp3');
    } else if (secondsLeft > 1 || secondsLeft <= 0) {
      _lastBeepSecond = null;
    }
  }

  void _startCountdown() {
    _playSound('start.mp3');
    
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
    setState(() {
      isBreak = false;
      isCountdown = false;
      totalPhaseDuration = interval!;
      remaining = interval!;
      _lastBeepSecond = null;
      stopwatch
        ..reset()
        ..start();
    });
  }

  void _startBreak() {
    _audioPlayer.stop();

    // If break duration is 0, skip directly to next interval
    if (breakDuration!.inSeconds == 0) {
      // Play start sound immediately for 0-second breaks
      _playSound('start.mp3');
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
      currentRound = 1; // Start from round 1 instead of 0
      isPaused = false;
      isBreak = false;
      isCountdown = true; // Start with countdown
    });
    
    // Ensure keyboard focus for key events
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_keyboardFocusNode != null && !_keyboardFocusNode.hasFocus) {
        _keyboardFocusNode.requestFocus();
      }
    });
    
    // Start with countdown instead of interval
    _startCountdown();
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
      
      // Move back to configuration UI after completing the workout
      _resetState();
    });
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
    });
    
    // Ensure keyboard focus is maintained when resetting
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_keyboardFocusNode != null && !_keyboardFocusNode.hasFocus) {
        _keyboardFocusNode.requestFocus();
      }
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
    int rowIndex,
    int colIndex,
  ) {
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
          color: selected == value ? Colors.amber : Colors.grey[800],
          borderRadius: BorderRadius.circular(52),
        ),
        child: Center(
          child: Text(
            value is Duration ? _format(value) : value.toString(),
            style: TextStyle(fontSize: fontSize, color: Colors.white),
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

  Widget _buildTimerUI() {
    final screenHeight = MediaQuery.of(context).size.height;
    final timerFontSize = screenHeight * 0.25; // 25% of height

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isCountdown 
              ? 'Starting Soon' 
              : isBreak 
                ? 'Break' 
                : 'Round $currentRound / ${rounds ?? 0}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
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
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isCountdown)
              GestureDetector(
                onTap: _togglePause,
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isPaused ? Icons.play_arrow : Icons.pause,
                    color: Colors.black,
                    size: 40,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfigUI() {
    // Use SingleChildScrollView to ensure content fits on screen
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSelection<Duration>('Interval', intervalOptions, interval, (val) {
              setState(() => interval = val);
            }, 0),
            if (interval != null)
              _buildSelection<Duration>('Break', breakOptions, breakDuration, (val) {
                setState(() => breakDuration = val);
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
      ),
    );
  }

  Widget _buildSelection<T>(
    String title,
    List<T> options,
    T? selected,
    void Function(T) onSelect,
    int rowIndex,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Wrap the options in a Wrap widget to flow to next line if needed
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            children: options.map((option) {
              return _buildOptionButton(
                option,
                selected,
                onSelect,
                rowIndex,
                options.indexOf(option),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _handleBackPress() {
    _audioPlayer.stop();
    if (isRunning) {
      _resetState();
    } else if (!isRunning && !isCompleted) {
      // Only navigate back if we're already on the config screen
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    stopwatch.stop();
    _audioPlayer.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _handleBackPress();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: KeyboardListener(
          focusNode: _keyboardFocusNode,
          autofocus: true,
          onKeyEvent: (KeyEvent event) {
            print("Key event detected: ${event.logicalKey}"); // Debug print
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.escape || event.logicalKey == LogicalKeyboardKey.goBack) {
                print("ESC or Back button pressed"); // Debug print
                _handleBackPress();
              } else if (event.logicalKey == LogicalKeyboardKey.space && isRunning && !isCountdown) {
                // Add space key to toggle pause/resume
                _togglePause();
              }
            }
          },
          child: Center(
            child: isRunning || isCompleted 
                ? _buildTimerUI()
                : _buildConfigUI(),
          ),
        ),
      ),
    );
  }
}
