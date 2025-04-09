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
  final Duration _countdownDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick)..start();
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
    setState(() {
      _stopwatch.stop();
      _isRunning = false;
      _isCountdown = false;
    });
  }

  // Handle ESC key and back button press
  void _handleBackPress() {
    // Stop any playing sound
    _player.stop();
    
    if (_isRunning) {
      // If timer is running, stop it and show grid
      setState(() {
        _stop();
        _showGrid = true;
      });
    } else {
      // If on grid view, go back to home screen
      Navigator.of(context).pop();
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape || 
          event.logicalKey == LogicalKeyboardKey.goBack) {
        _handleBackPress();
      } else if (event.logicalKey == LogicalKeyboardKey.space && _isRunning && !_isCountdown) {
        _togglePause();
      }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleKeyEvent,
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
            (i) => _buildTimerButton(Duration(seconds: timerOptions[i])),
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

  Widget _buildTimerButton(Duration duration) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonHeight = screenHeight * 0.10;
    final buttonWidth = screenWidth * 0.10;
    final fontSize = buttonHeight * 0.3;

    return GestureDetector(
      onTap: () {
        _start(duration);
      },
      child: Container(
        height: buttonHeight,
        width: buttonWidth,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(52),
          border: Border.all(
            color: Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            _format(duration),
            style: TextStyle(fontSize: fontSize, color: Colors.white),
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
