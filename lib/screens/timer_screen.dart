import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:audioplayers/audioplayers.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({Key? key}) : super(key: key);

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  // Generate durations from 30 seconds to 5 minutes (10 options, 30s intervals)
  final List<Duration> durations = List.generate(
    10,
    (i) => Duration(seconds: 30 * (i + 1)),
  );

  Duration? _selectedDuration;
  Duration _remaining = Duration.zero;
  Stopwatch _stopwatch = Stopwatch();
  late final Ticker _ticker;
  bool _isRunning = false;
  bool _showGrid = true;

  // Flag to ensure the end sound is played only once
  bool _playedEndSound = false;

  // Audio player instance
  final AudioPlayer _player = AudioPlayer();

  // We store one FocusNode per timer button.
  late List<FocusNode> _focusNodes;

  // Grid dimensions: we show 3 columns.
  final int _columns = 3;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick)..start();
    _focusNodes = List.generate(durations.length, (_) => FocusNode());

    // Autofocus the first timer button when grid is shown.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_showGrid && _focusNodes.isNotEmpty) {
        _focusNodes.first.requestFocus();
      }
    });
  }

  void _onTick(Duration elapsed) {
    if (_isRunning && _selectedDuration != null) {
      final timeLeft = _selectedDuration! - _stopwatch.elapsed;
      if (timeLeft <= Duration.zero) {
        // Timer has ended.
        setState(() {
          _remaining = Duration.zero;
        });
        _stop();
        // In case the end sound wasn’t started already.
        if (!_playedEndSound) {
          _playEndSoundAndShowGrid();
          _playedEndSound = true;
        }
      } else {
        // When timeLeft goes to 3 seconds (and if we haven’t played end sound yet)
        if (!_playedEndSound && timeLeft.inSeconds <= 3) {
          _playEndSoundAndShowGrid();
          _playedEndSound = true;
        }
        setState(() {
          _remaining = timeLeft;
        });
      }
    }
  }

  void _start(Duration duration) {
    setState(() {
      _selectedDuration = duration;
      _remaining = duration;
      _stopwatch
        ..reset()
        ..start();
      _isRunning = true;
      _showGrid = false;
      _playedEndSound = false; // reset flag when starting a new timer
    });
  }

  void _stop() {
    setState(() {
      _stopwatch.stop();
      _isRunning = false;
    });
  }

  // Plays the end sound (4 sec long) and then, when complete, shows the grid.
  Future<void> _playEndSoundAndShowGrid() async {
    try {
      await _player.play(AssetSource('sounds/end.mp3'));
      _player.onPlayerComplete.listen((event) {
        setState(() {
          _showGrid = true;
        });
      });
    } catch (e) {
      print('Error playing end sound: $e');
      setState(() {
        _showGrid = true;
      });
    }
  }

  // (If you want a short beep at 3 seconds instead of the end sound, you could use this.)
  Future<void> _playBeep() async {
    try {
      await _player.play(AssetSource('sounds/beep.mp3'));
    } catch (e) {
      print('Error playing beep: $e');
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
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      // Using ReadingOrderTraversalPolicy so that the children are traversed in creation order.
      policy: ReadingOrderTraversalPolicy(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child:
              _showGrid
                  ? _buildTimerGrid()
                  : _isRunning
                  ? _buildTimerDisplay()
                  : const SizedBox.shrink(),
        ),
      ),
    );
  }

  // Builds the grid of timer buttons.
  Widget _buildTimerGrid() {
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(), // Enables arrow key navigation
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 16,
        children: List.generate(
          durations.length,
          (i) => _buildTimerButton(durations[i], i, _focusNodes[i]),
        ),
      ),
    );
  }

  // Displays the countdown timer in the center.
  Widget _buildTimerDisplay() {
    return Text(
      _format(_remaining),
      style: const TextStyle(fontSize: 72, color: Colors.white),
    );
  }

  // Builds an individual timer button.
  // We pass in the duration, its index, and its associated FocusNode.
  Widget _buildTimerButton(Duration duration, int index, FocusNode focusNode) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        int? newIndex;
        // Calculate new index based on arrow key press.
        if (key == LogicalKeyboardKey.arrowRight) {
          // If not on the right edge
          if ((index + 1) % _columns != 0 && index + 1 < durations.length) {
            newIndex = index + 1;
          }
        } else if (key == LogicalKeyboardKey.arrowLeft) {
          if (index % _columns != 0) {
            newIndex = index - 1;
          }
        } else if (key == LogicalKeyboardKey.arrowDown) {
          if (index + _columns < durations.length) {
            newIndex = index + _columns;
          }
        } else if (key == LogicalKeyboardKey.arrowUp) {
          if (index - _columns >= 0) {
            newIndex = index - _columns;
          }
        } else if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select) {
          _start(duration);
          return KeyEventResult.handled;
        }

        if (newIndex != null) {
          _focusNodes[newIndex].requestFocus();
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: () => _start(duration),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isFocused ? Colors.blue : Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFocused ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Text(
                _format(duration),
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }
}
