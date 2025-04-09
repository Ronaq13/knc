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
  final AudioPlayer _player = AudioPlayer();
  final FocusNode _keyboardFocusNode = FocusNode();
  final Duration _countdownDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (_isRunning && _selectedDuration != null) {
      final timeLeft = _isCountdown 
          ? _countdownDuration - _stopwatch.elapsed 
          : _selectedDuration! - _stopwatch.elapsed;
          
      if (timeLeft <= Duration.zero) {
        if (_isCountdown) {
          // Countdown is complete, start the actual timer
          _startActualTimer();
        } else {
          // Timer is complete
          setState(() {
            _remaining = Duration.zero;
          });
          _stop();
          if (!_playedEndSound) {
            _playEndSound();
            _playedEndSound = true;
            // Only show grid when timer completes fully, not during countdown transition
            Future.delayed(Duration(milliseconds: 500), () {
              if (mounted) {
                setState(() {
                  _showGrid = true;
                });
              }
            });
          }
        }
      } else {
        if (!_isCountdown && !_playedEndSound && timeLeft.inSeconds <= 1) {
          _playEndSound();
          _playedEndSound = true;
          // Only show grid when timer completes fully
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {
                _showGrid = true;
              });
            }
          });
        }
        setState(() {
          _remaining = timeLeft;
        });
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
      _showGrid = false;
      _playedEndSound = false;
      _stopwatch..reset()..start();
    });
    
    // Debug log
    print('Starting actual timer: duration=${_selectedDuration!.inSeconds}s');
  }

  Future<void> _playSound(String soundFile) async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/$soundFile'));
    } catch (e) {
      print('Error playing sound: $e');
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
      }
    }
  }

  // Separate sound playing from showing grid
  Future<void> _playEndSound() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/end.mp3'));
    } catch (e) {
      print('Error playing end sound: $e');
    }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Added debug output to identify the state
    print('Build Timer Screen: showGrid=$_showGrid, isRunning=$_isRunning, isCountdown=$_isCountdown');
    
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
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            automaticallyImplyLeading: false, // Remove back button
            title: Text(
              'Timer',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w100,
                fontFamily: 'Roboto Condensed',
              ),
            ),
            centerTitle: true,
            toolbarHeight: 80,
          ),
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

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isCountdown)
            Text(
              'Starting Soon',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          SizedBox(height: _isCountdown ? 20 : 0),
          LayoutBuilder(
            builder: (context, constraints) {
              return Text(
                _format(_remaining),
                style: TextStyle(
                  fontSize: timerFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
        ],
      ),
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
}
