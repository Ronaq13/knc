import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:audioplayers/audioplayers.dart';

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

  Duration? _selectedDuration;
  Duration _remaining = Duration.zero;
  Stopwatch _stopwatch = Stopwatch();
  late final Ticker _ticker;
  bool _isRunning = false;
  bool _showGrid = true;
  bool _isCountdown = false;
  bool _playedEndSound = false;
  bool _isPaused = false;
  final AudioPlayer _player = AudioPlayer();
  final FocusNode _keyboardFocusNode = FocusNode();
  final FocusNode _pauseButtonFocusNode = FocusNode();
  late List<FocusNode> _timerButtonFocusNodes;
  int _currentFocusIndex = 0;
  final Duration _countdownDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick)..start();
    
    _timerButtonFocusNodes = List.generate(
      timerOptions.length,
      (index) => FocusNode(),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showGrid) {
        _timerButtonFocusNodes[0].requestFocus();
      }
    });
  }

  void _onTick(Duration elapsed) {
    if (_isRunning && _selectedDuration != null && !_isPaused) {
      final timeLeft = _isCountdown 
          ? _countdownDuration - _stopwatch.elapsed 
          : _selectedDuration! - _stopwatch.elapsed;
      
      // Ensure we don't go below zero
      final sanitizedTimeLeft = timeLeft.isNegative ? Duration.zero : timeLeft;
          
      if (sanitizedTimeLeft == Duration.zero) {
        if (_isCountdown) {
          // Countdown is complete, start the actual timer
          _startActualTimer();
          
          // Safety check to ensure grid is not shown after countdown
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _showGrid && _isRunning && !_isCountdown) {
              setState(() {
                _showGrid = false;
              });
            }
          });
        } else if (_isRunning) { // Only handle completion once
          // Timer is complete - show 00:00
          setState(() {
            _remaining = Duration.zero;
            _isRunning = false; // Stop the timer
            _stopwatch.stop();
          });
          
          if (!_playedEndSound) {
            // Play the end sound and show grid only after sound completes
            _playEndSound();
            _playedEndSound = true;
          }
        }
      } else {
        // Update the remaining time
        setState(() {
          _remaining = sanitizedTimeLeft;
        });
        
        // If we're about to finish (last second), play the sound
        if (!_isCountdown && !_playedEndSound && sanitizedTimeLeft.inSeconds <= 1 && sanitizedTimeLeft.inMilliseconds <= 50) {
          _playEndSound();
          _playedEndSound = true;
        }
      }
    }
  }

  void _startCountdown(Duration timerDuration) {
    _playSound('start.mp3');
    setState(() {
      _selectedDuration = timerDuration;
      _remaining = _countdownDuration;
      _isCountdown = true;
      _isRunning = true;
      _showGrid = false;
      _playedEndSound = false;
      _stopwatch..reset()..start();
    });
  }

  void _startActualTimer() {
    setState(() {
      _isCountdown = false;
      _isRunning = true;
      _remaining = _selectedDuration!;
      _showGrid = false; // Explicitly ensure grid remains hidden
      _playedEndSound = false;
      _isPaused = false;
      _stopwatch..reset()..start();
    });
    
    // Focus the pause button when the timer starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_pauseButtonFocusNode.hasFocus) {
        _pauseButtonFocusNode.requestFocus();
      }
    });
    
    // Double check that grid is hidden after the state update
    // This is a safety measure in case another part of the code is setting _showGrid = true
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showGrid && _isRunning) {
        setState(() {
          _showGrid = false;
        });
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

  void _start(Duration duration) {
    // Stop any existing timer first
    if (_isRunning) {
      _stop();
    }
    
    // Reset state completely before starting new countdown
    setState(() {
      _playedEndSound = false;
      _showGrid = false;
    });
    
    _startCountdown(duration);
  }

  void _stop() {
    print("_stop called");
    setState(() {
      _stopwatch.stop();
      _isRunning = false;
      _isCountdown = false;
      _isPaused = false;
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    // Debug print to see what keys are being detected
    print("Key event: ${event.logicalKey} - isCountdown: $_isCountdown, isRunning: $_isRunning");
    
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape || 
          event.logicalKey == LogicalKeyboardKey.goBack) {
        print("ESC detected - handling back press");
        _handleBackPress();
      } else if (event.logicalKey == LogicalKeyboardKey.space && _isRunning) {
        // Allow pause even during countdown
        _togglePause();
      } else if (_showGrid) {
        _handleGridKeyNavigation(event);
      }
    }
  }

  // Handle ESC key and back button press
  void _handleBackPress() {
    // Stop any playing sound
    _player.stop();
    
    // Debug print to trace function execution
    print("_handleBackPress called, isCountdown: $_isCountdown, isRunning: $_isRunning");
    
    if (_isRunning || _isCountdown) { // Handle both running and countdown states
      print("Stopping timer and showing grid");
      // If timer is running or in countdown, stop it and show grid
      setState(() {
        _stop();
        _showGrid = true;
        _currentFocusIndex = 0; // Reset focus index to first button
      });
      
      // Request focus on the first button after the UI updates
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showGrid && _timerButtonFocusNodes.isNotEmpty) {
          _timerButtonFocusNodes[0].requestFocus();
        }
      });
    } else {
      // If on grid view, go back to home screen
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
    for (var node in _timerButtonFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _handleGridKeyNavigation(KeyEvent event) {
    final int columns = 4; // Estimated number of columns in the grid
    final int currentRow = _currentFocusIndex ~/ columns;
    final int currentCol = _currentFocusIndex % columns;
    
    int newIndex = _currentFocusIndex;
    
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      newIndex = _currentFocusIndex + 1;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      newIndex = _currentFocusIndex - 1;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      newIndex = _currentFocusIndex - columns;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      newIndex = _currentFocusIndex + columns;
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
               event.logicalKey == LogicalKeyboardKey.select) {
      // Start the timer with the currently focused option
      _start(Duration(seconds: timerOptions[_currentFocusIndex]));
      return;
    } else {
      return; // Not an arrow key or enter/select
    }
    
    // Ensure the new index is within bounds
    if (newIndex >= 0 && newIndex < timerOptions.length) {
      setState(() {
        _currentFocusIndex = newIndex;
        _timerButtonFocusNodes[newIndex].requestFocus();
      });
    }
  }

  // Separate sound playing from showing grid
  Future<void> _playEndSound() async {
    try {
      await _player.stop();
      
      // Remove any existing listeners to prevent duplicates
      _player.onPlayerComplete.drain();
      
      // Only set up the listener for grid display for end sound, not start sound
      _player.onPlayerComplete.listen((event) {
        if (mounted) {
          // Only show grid on timer completion, not during transitions
          if (!_isCountdown && !_isRunning) {
            setState(() {
              _showGrid = true; // Show grid after sound completes
            });
          }
        }
      });
      
      await _player.play(AssetSource('sounds/end.mp3'));
    } catch (e) {
      // If sound fails, still show the grid but only if timer is complete
      if (mounted && !_isCountdown && !_isRunning) {
        setState(() {
          _showGrid = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _keyboardFocusNode,
      onKey: (RawKeyEvent event) {
        // Debug print to see what keys are being detected
        print("Raw key event: ${event.logicalKey}");
        
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape || 
              event.logicalKey == LogicalKeyboardKey.goBack) {
            print("ESC detected - handling back press");
            _handleBackPress();
          } else if (event.logicalKey == LogicalKeyboardKey.space && _isRunning) {
            _togglePause();
          } else if (_showGrid) {
            // Handle grid navigation with arrow keys
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              int newIndex = _currentFocusIndex + 1;
              if (newIndex < timerOptions.length) {
                setState(() {
                  _currentFocusIndex = newIndex;
                  _timerButtonFocusNodes[newIndex].requestFocus();
                });
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              int newIndex = _currentFocusIndex - 1;
              if (newIndex >= 0) {
                setState(() {
                  _currentFocusIndex = newIndex;
                  _timerButtonFocusNodes[newIndex].requestFocus();
                });
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              int newIndex = _currentFocusIndex - 4;
              if (newIndex >= 0) {
                setState(() {
                  _currentFocusIndex = newIndex;
                  _timerButtonFocusNodes[newIndex].requestFocus();
                });
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              int newIndex = _currentFocusIndex + 4;
              if (newIndex < timerOptions.length) {
                setState(() {
                  _currentFocusIndex = newIndex;
                  _timerButtonFocusNodes[newIndex].requestFocus();
                });
              }
            } else if (event.logicalKey == LogicalKeyboardKey.enter ||
                       event.logicalKey == LogicalKeyboardKey.select) {
              _start(Duration(seconds: timerOptions[_currentFocusIndex]));
            }
          }
        }
      },
      autofocus: true,
      child: WillPopScope(
        onWillPop: () async {
          _handleBackPress();
          return false; // Always handle back press manually
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: _showGrid 
                ? _buildTimerGrid() 
                : _buildTimerDisplay(),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerGrid() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: List.generate(
            timerOptions.length,
            (i) => _buildTimerButton(Duration(seconds: timerOptions[i]), i),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerDisplay() {
    final screenHeight = MediaQuery.of(context).size.height;
    final timerFontSize = screenHeight * 0.25;

    return Stack(
      children: [
        // Timer display always centered
        Center(
          child: Text(
            _format(_remaining),
            style: TextStyle(
              fontSize: timerFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        // Starting Soon text positioned above but not affecting center alignment of timer
        if (_isCountdown)
          Positioned(
            top: screenHeight * 0.25,
            left: 0,
            right: 0,
            child: Text(
              'Starting Soon',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
        // Pause/Resume button at the bottom
        if (!_isCountdown) // Don't show during countdown
          Positioned(
            bottom: screenHeight * 0.15,
            left: 0,
            right: 0,
            child: Center(
              child: _buildPauseResumeButton(),
            ),
          ),
      ],
    );
  }

  Widget _buildTimerButton(Duration duration, int index) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonHeight = screenHeight * 0.10;
    final buttonWidth = screenWidth * 0.10;
    final fontSize = buttonHeight * 0.3;

    final isFocused = _timerButtonFocusNodes[index].hasFocus;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentFocusIndex = index;
        });
        _start(duration);
      },
      child: Focus(
        focusNode: _timerButtonFocusNodes[index],
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            setState(() {
              _currentFocusIndex = index;
            });
          }
        },
        child: Container(
          height: buttonHeight,
          width: buttonWidth,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: isFocused ? Colors.blue : Colors.grey[800],
            borderRadius: BorderRadius.circular(52),
            border: Border.all(
              color: isFocused ? Colors.white : Colors.transparent,
              width: isFocused ? 4 : 2,
            ),
          ),
          child: Center(
            child: Text(
              _format(duration),
              style: TextStyle(fontSize: fontSize, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPauseResumeButton() {
    return GestureDetector(
      onTap: _togglePause,
      child: Focus(
        focusNode: _pauseButtonFocusNode,
        child: Container(
          padding: EdgeInsets.all(16),
          child: Icon(
            _isPaused ? Icons.play_arrow : Icons.pause,
            color: Colors.black,
            size: MediaQuery.of(context).size.height * 0.05,
          ),
        ),
      ),
    );
  }
}
