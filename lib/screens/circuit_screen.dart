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

  // Focus nodes for option buttons
  late List<FocusNode> _intervalFocusNodes;
  late List<FocusNode> _breakFocusNodes;
  late List<FocusNode> _roundFocusNodes;
  late FocusNode _pauseButtonFocusNode;
  
  // Track which type of option is currently focused (0=interval, 1=break, 2=rounds)
  int _currentRowIndex = 0;
  // Track which option in the current row is focused
  int _currentColIndex = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick)..start();
    
    // Initialize focus nodes for all options
    _intervalFocusNodes = List.generate(
      intervalOptions.length,
      (index) => FocusNode(),
    );
    
    _breakFocusNodes = List.generate(
      breakOptions.length,
      (index) => FocusNode(),
    );
    
    _roundFocusNodes = List.generate(
      roundOptions.length,
      (index) => FocusNode(),
    );
    
    _pauseButtonFocusNode = FocusNode();
    
    // Set initial focus to the first interval option when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !isRunning) {
        _intervalFocusNodes[0].requestFocus();
      }
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

    // Determine if this button should be focused
    FocusNode? focusNode;
    bool isFocused = false;
    
    if (rowIndex == 0) {
      focusNode = _intervalFocusNodes[colIndex];
      isFocused = focusNode.hasFocus;
    } else if (rowIndex == 1) {
      focusNode = _breakFocusNodes[colIndex];
      isFocused = focusNode.hasFocus;
    } else if (rowIndex == 2) {
      focusNode = _roundFocusNodes[colIndex];
      isFocused = focusNode.hasFocus;
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
              width: isFocused ? 4 : 2,
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

  Widget _buildTimerUI() {
    final screenHeight = MediaQuery.of(context).size.height;
    final timerFontSize = screenHeight * 0.25; // 25% of height

    // Focus pause button when timer UI is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !isCountdown && _pauseButtonFocusNode != null) {
        _pauseButtonFocusNode.requestFocus();
      }
    });

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Fixed height container for the text to prevent layout shifts
          Container(
            height: 40, // Fixed height for title area
            alignment: Alignment.center,
            child: Text(
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
          SizedBox(height: screenHeight * 0.15),
          // Fixed height area for button to prevent layout shifts
          Container(
            height: 72, // Space for the button
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isCountdown)
                GestureDetector(
                  onTap: _togglePause,
                  child: Focus(
                    focusNode: _pauseButtonFocusNode,
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(
                          color: Colors.transparent,
                          width: 2,
                        ),
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
    _pauseButtonFocusNode.dispose();
    
    // Dispose all option focus nodes
    for (var node in _intervalFocusNodes) {
      node.dispose();
    }
    for (var node in _breakFocusNodes) {
      node.dispose();
    }
    for (var node in _roundFocusNodes) {
      node.dispose();
    }
    
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
          focusNode: _keyboardFocusNode,
          autofocus: true,
          onKey: (RawKeyEvent event) {
            if (event is RawKeyDownEvent) {
              // Handle ESC/Back button for all states
              if (event.logicalKey == LogicalKeyboardKey.escape || 
                  event.logicalKey == LogicalKeyboardKey.goBack) {
                _handleBackPress();
              }
              // For running circuit
              else if (isRunning) {
                if (event.logicalKey == LogicalKeyboardKey.space) {
                  _togglePause();
                } 
                // Handle Enter/Select/OK for pause button when focused
                else if ((event.logicalKey == LogicalKeyboardKey.enter || 
                         event.logicalKey == LogicalKeyboardKey.select) && 
                         !isCountdown && _pauseButtonFocusNode.hasFocus) {
                  _togglePause();
                }
              }
              // For config UI
              else if (!isRunning) {
                _handleConfigKeyNavigation(event);
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
  
  // Handle keyboard navigation in the configuration UI
  void _handleConfigKeyNavigation(RawKeyEvent event) {
    // Handle navigation keys
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _moveFocusRight();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _moveFocusLeft();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveFocusUp();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveFocusDown();
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
               event.logicalKey == LogicalKeyboardKey.select) {
      _activateFocusedOption();
    }
  }

  // Move focus right within the current row
  void _moveFocusRight() {
    int maxIndex = 0;
    if (_currentRowIndex == 0) {
      maxIndex = intervalOptions.length - 1;
    } else if (_currentRowIndex == 1) {
      maxIndex = breakOptions.length - 1;
    } else if (_currentRowIndex == 2) {
      maxIndex = roundOptions.length - 1;
    }
    
    if (_currentColIndex < maxIndex) {
      setState(() {
        _currentColIndex++;
        _requestFocusForCurrentOption();
      });
    }
  }
  
  // Move focus left within the current row
  void _moveFocusLeft() {
    if (_currentColIndex > 0) {
      setState(() {
        _currentColIndex--;
        _requestFocusForCurrentOption();
      });
    }
  }
  
  // Move focus up to the previous row if available
  void _moveFocusUp() {
    if (_currentRowIndex > 0) {
      setState(() {
        _currentRowIndex--;
        // Ensure column index is valid for the new row
        _currentColIndex = _currentColIndex.clamp(0, _getMaxColIndexForRow(_currentRowIndex));
        _requestFocusForCurrentOption();
      });
    }
  }
  
  // Move focus down to the next row if available
  void _moveFocusDown() {
    int lastAvailableRow = _getLastAvailableRowIndex();
    if (_currentRowIndex < lastAvailableRow) {
      setState(() {
        _currentRowIndex++;
        // Ensure column index is valid for the new row
        _currentColIndex = _currentColIndex.clamp(0, _getMaxColIndexForRow(_currentRowIndex));
        _requestFocusForCurrentOption();
      });
    }
  }
  
  // Helper to get the maximum column index for a given row
  int _getMaxColIndexForRow(int rowIndex) {
    if (rowIndex == 0) {
      return intervalOptions.length - 1;
    } else if (rowIndex == 1) {
      return breakOptions.length - 1;
    } else if (rowIndex == 2) {
      return roundOptions.length - 1;
    }
    return 0;
  }
  
  // Request focus for the current option based on row and column indices
  void _requestFocusForCurrentOption() {
    if (_currentRowIndex == 0 && _currentColIndex < intervalOptions.length) {
      _intervalFocusNodes[_currentColIndex].requestFocus();
    } else if (_currentRowIndex == 1 && _currentColIndex < breakOptions.length) {
      _breakFocusNodes[_currentColIndex].requestFocus();
    } else if (_currentRowIndex == 2 && _currentColIndex < roundOptions.length) {
      _roundFocusNodes[_currentColIndex].requestFocus();
    }
  }
  
  // Activate the currently focused option
  void _activateFocusedOption() {
    if (_currentRowIndex == 0) {
      // Set interval
      setState(() => interval = intervalOptions[_currentColIndex]);
    } else if (_currentRowIndex == 1) {
      // Set break duration
      setState(() => breakDuration = breakOptions[_currentColIndex]);
    } else if (_currentRowIndex == 2) {
      // Set rounds and start circuit
      setState(() {
        rounds = roundOptions[_currentColIndex];
        _startCircuit();
      });
    }
  }
}
