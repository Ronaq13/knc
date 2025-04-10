import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

class CircuitScreen extends StatefulWidget {
  const CircuitScreen({Key? key}) : super(key: key);

  @override
  State<CircuitScreen> createState() => CircuitScreenState();
}

class CircuitScreenState extends State<CircuitScreen> {
  // Timer state
  Stopwatch _stopwatch = Stopwatch();
  late final Ticker _ticker;
  Duration? _currentInterval;
  int currentRound = 1;
  int completedIntervals = 0;
  bool isCountdown = false;
  bool isRunning = false;
  bool isCompleted = false;
  bool isPaused = false;
  
  // For sound effects
  final AudioPlayer _player = AudioPlayer();
  bool _playedEndSound = false;
  bool _played10secWarning = false;
  
  // Configuration options
  List<int> intervalOptions = [20, 30, 45, 60, 120, 180];
  List<int> breakOptions = [10, 15, 20, 30, 45, 60];
  List<int> roundOptions = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  
  // Selected values
  int interval = 60;   // Default 60 seconds
  int breakDuration = 15;  // Default 15 seconds
  int rounds = 3;      // Default 3 rounds
  
  // Focus handling
  final FocusNode _keyboardFocusNode = FocusNode();
  final FocusNode _pauseButtonFocusNode = FocusNode();
  late List<FocusNode> _intervalFocusNodes;
  late List<FocusNode> _breakFocusNodes;
  late List<FocusNode> _roundFocusNodes;
  int _currentRowIndex = 0; // 0 = interval, 1 = break, 2 = rounds
  int _currentColIndex = 0;
  
  // For handling TV remote key presses
  String? _lastKeyPressed;
  DateTime _lastKeyPressTime = DateTime.now();
  
  // For the clock in the AppBar
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick);
    
    // Create focus nodes
    _intervalFocusNodes = List.generate(
      intervalOptions.length, 
      (_) => FocusNode()
    );
    
    _breakFocusNodes = List.generate(
      breakOptions.length, 
      (_) => FocusNode()
    );
    
    _roundFocusNodes = List.generate(
      roundOptions.length, 
      (_) => FocusNode()
    );
    
    // Set initial focus to first interval option
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _intervalFocusNodes[0].requestFocus();
    });
    
    // Initialize the clock timer
    _clockTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  void _onTick(Duration elapsed) {
    if (!isRunning || isPaused) return;

    final timeLeft = _currentInterval! - _stopwatch.elapsed;
    if (timeLeft <= Duration.zero) {
      _player.stop();
      _stopwatch
        ..stop()
        ..reset();
      if (isCountdown) {
        isCountdown = false;
        _startInterval();
      } else if (isPaused) {
        _startInterval();
      } else {
        if (currentRound >= rounds) {
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
        _currentInterval = timeLeft;
      });
    }
  }

  void _maybePlayBeep(Duration timeLeft) {
    // Play start sound when 3 seconds left in break phase
    if (isPaused) {
      int secondsLeft = timeLeft.inSeconds;
      if (secondsLeft == 3 && !_played10secWarning) {
        _played10secWarning = true;
        _playSound('start.mp3');
      }
      return;
    }
    
    // Don't play sounds during countdown
    if (isCountdown) return;

    // Only play end sound during interval (not during break)
    int secondsLeft = timeLeft.inSeconds;
    if (secondsLeft == 1 && !_playedEndSound) {
      _playedEndSound = true;
      _playSound('end.mp3');
    } else if (secondsLeft > 1 || secondsLeft <= 0) {
      _playedEndSound = false;
    }
  }

  void _startCountdown() {
    _playSound('start.mp3');
    
    setState(() {
      isPaused = false;
      isCountdown = true;
      _currentInterval = Duration(seconds: interval);
      _stopwatch
        ..reset()
        ..start();
    });
  }

  Future<void> _playSound(String soundFile) async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/$soundFile'));
    } catch (e) {
      debugPrint('Error playing sound $soundFile: $e');
    }
  }

  void _startInterval() {    
    setState(() {
      isPaused = false;
      isCountdown = false;
      _currentInterval = Duration(seconds: interval);
      _stopwatch
        ..reset()
        ..start();
    });
  }

  void _startBreak() {
    _player.stop();

    // If break duration is 0, skip directly to next interval
    if (breakDuration == 0) {
      // Play start sound immediately for 0-second breaks
      _playSound('start.mp3');
      _startInterval();
      return;
    }

    setState(() {
      isPaused = true;
      isCountdown = false;
      _currentInterval = Duration(seconds: breakDuration);
      _stopwatch
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
        _stopwatch.stop();
        // Pause audio playback
        _player.pause();
      } else {
        // Resume audio playback if it was paused
        _player.resume();
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
    _player.stop();
    setState(() {
      isCompleted = true;
      isRunning = false;
      isPaused = false;
      _stopwatch.stop();
    });
    
    // Return to home screen after workout is complete
    Navigator.of(context).pop();
  }

  void _resetState() {
    _player.stop();
    setState(() {
      isRunning = false;
      isPaused = false;
      isCompleted = false;
      currentRound = 1; // Reset to 1
      isCountdown = false;
      _stopwatch.stop();
      _currentInterval = null;
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
    if (_currentInterval == null) {
      return 0; // Only Interval row is available
    } else if (breakDuration == 0) {
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
                : isPaused 
                  ? 'Break' 
                  : 'Round $currentRound / $rounds',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _format(_currentInterval!),
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
            _buildSelection<int>('Interval', intervalOptions, interval, (val) {
              setState(() => interval = val);
            }, 0),
            if (interval != 0)
              _buildSelection<int>('Break', breakOptions, breakDuration, (val) {
                setState(() => breakDuration = val);
              }, 1),
            if (interval != 0 && breakDuration != 0)
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
    _player.stop();
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
    _stopwatch.stop();
    _player.dispose();
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
    
    // Dispose the clock timer
    _clockTimer?.cancel();
    
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
            // Only process key down events to avoid duplicates
            if (event is RawKeyDownEvent) {
              // Debug print to see what keys are being detected
              print("Raw key event: ${event.logicalKey} - ${event.physicalKey}");
              
              // Get the current key being pressed
              String currentKey = event.logicalKey.keyLabel;
              final now = DateTime.now();
              
              // Check if this is the same key being pressed rapidly (less than 150ms apart)
              if (_lastKeyPressed == currentKey && 
                  now.difference(_lastKeyPressTime).inMilliseconds < 150) {
                print("Skipping rapid repeat of key: $currentKey");
                return;
              }
              
              // Update tracking variables
              _lastKeyPressed = currentKey;
              _lastKeyPressTime = now;
              
              // Handle ESC/Back button for all states
              if (event.logicalKey == LogicalKeyboardKey.escape || 
                  event.logicalKey == LogicalKeyboardKey.goBack ||
                  event.physicalKey == PhysicalKeyboardKey.escape) {
                _handleBackPress();
                return;
              }
              
              // For running circuit
              if (isRunning) {
                // Handle space/pause 
                if (event.logicalKey == LogicalKeyboardKey.space ||
                    event.physicalKey == PhysicalKeyboardKey.space) {
                  _togglePause();
                  return;
                }
                
                // Handle Enter/Select/OK for pause button when focused
                if ((event.logicalKey == LogicalKeyboardKey.enter || 
                     event.logicalKey == LogicalKeyboardKey.select ||
                     event.physicalKey == PhysicalKeyboardKey.enter ||
                     event.physicalKey == PhysicalKeyboardKey.select) && 
                    !isCountdown && _pauseButtonFocusNode.hasFocus) {
                  _togglePause();
                  return;
                }
              }
              // For config UI
              else if (!isRunning) {
                // Handle right arrow
                if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                    event.physicalKey == PhysicalKeyboardKey.arrowRight) {
                  _handleMoveFocusRight();
                  return;
                }
                
                // Handle left arrow
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                    event.physicalKey == PhysicalKeyboardKey.arrowLeft) {
                  _handleMoveFocusLeft();
                  return;
                }
                
                // Handle up arrow
                if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                    event.physicalKey == PhysicalKeyboardKey.arrowUp) {
                  _handleMoveFocusUp();
                  return;
                }
                
                // Handle down arrow
                if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                    event.physicalKey == PhysicalKeyboardKey.arrowDown) {
                  _handleMoveFocusDown();
                  return;
                }
                
                // Handle enter/select
                if (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.select ||
                    event.physicalKey == PhysicalKeyboardKey.enter ||
                    event.physicalKey == PhysicalKeyboardKey.select) {
                  _handleActivateFocusedOption();
                  return;
                }
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
  
  // Handler methods for focus navigation with better control for TV remotes
  void _handleMoveFocusRight() {
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
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _requestFocusForCurrentOption();
          print("Moved focus RIGHT to column $_currentColIndex in row $_currentRowIndex");
        }
      });
    }
  }
  
  void _handleMoveFocusLeft() {
    if (_currentColIndex > 0) {
      setState(() {
        _currentColIndex--;
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _requestFocusForCurrentOption();
          print("Moved focus LEFT to column $_currentColIndex in row $_currentRowIndex");
        }
      });
    }
  }
  
  void _handleMoveFocusUp() {
    if (_currentRowIndex > 0) {
      setState(() {
        _currentRowIndex--;
        // Ensure column index is valid for the new row
        _currentColIndex = _currentColIndex.clamp(0, _getMaxColIndexForRow(_currentRowIndex));
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _requestFocusForCurrentOption();
          print("Moved focus UP to row $_currentRowIndex, column $_currentColIndex");
        }
      });
    }
  }
  
  void _handleMoveFocusDown() {
    int lastAvailableRow = _getLastAvailableRowIndex();
    if (_currentRowIndex < lastAvailableRow) {
      setState(() {
        _currentRowIndex++;
        // Ensure column index is valid for the new row
        _currentColIndex = _currentColIndex.clamp(0, _getMaxColIndexForRow(_currentRowIndex));
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _requestFocusForCurrentOption();
          print("Moved focus DOWN to row $_currentRowIndex, column $_currentColIndex");
        }
      });
    }
  }
  
  void _handleActivateFocusedOption() {
    if (_currentRowIndex == 0) {
      // Set interval
      setState(() => interval = intervalOptions[_currentColIndex]);
      
      // After selecting interval, focus on first break option
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _breakFocusNodes.isNotEmpty) {
          _currentRowIndex = 1;
          _currentColIndex = 0;
          _breakFocusNodes[0].requestFocus();
          print("Activated interval option, moved to break options");
        }
      });
    } else if (_currentRowIndex == 1) {
      // Set break duration
      setState(() => breakDuration = breakOptions[_currentColIndex]);
      
      // After selecting break, focus on first round option
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _roundFocusNodes.isNotEmpty) {
          _currentRowIndex = 2;
          _currentColIndex = 0;
          _roundFocusNodes[0].requestFocus();
          print("Activated break option, moved to round options");
        }
      });
    } else if (_currentRowIndex == 2) {
      // Set rounds and start circuit
      setState(() {
        rounds = roundOptions[_currentColIndex];
        _startCircuit();
      });
      print("Activated round option, starting circuit");
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
}
