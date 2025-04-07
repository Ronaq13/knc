import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/scheduler.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({Key? key}) : super(key: key);

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  final AudioPlayer _player = AudioPlayer();
  final List<FocusNode> _timerFocusNodes = [];
  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _resetFocusNode = FocusNode();

  Duration? _selectedDuration;
  Duration _remaining = Duration.zero;
  late Ticker _ticker;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick);
    _initializeFocusNodes();
  }

  void _initializeFocusNodes() {
    _timerFocusNodes.clear();
    for (int i = 0; i < _durations.length; i++) {
      _timerFocusNodes.add(FocusNode());
    }
  }

  void _onTick(Duration elapsed) {
    if (!_isRunning || _selectedDuration == null) return;

    setState(() {
      _remaining = _selectedDuration! - elapsed;

      if (_remaining <= Duration.zero) {
        _stop();
        _playSound('assets/beep_end.mp3');
      } else if (_remaining.inSeconds == 10) {
        _playSound('assets/beep_warning.mp3');
      }
    });
  }

  void _start() {
    if (_selectedDuration == null) return;
    setState(() {
      _isRunning = true;
      _remaining = _selectedDuration!;
      _ticker.start();
    });
  }

  void _stop() {
    setState(() {
      _isRunning = false;
      _ticker.stop();
    });
  }

  void _reset() {
    setState(() {
      _isRunning = false;
      _ticker.stop();
      _remaining = _selectedDuration ?? Duration.zero;
    });
  }

  void _playSound(String path) async {
    await _player.play(AssetSource(path.replaceFirst('assets/', '')));
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes);
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  final List<Duration> _durations = List.generate(
    12,
    (i) => Duration(seconds: 30 * (i + 1)), // 30s to 6m
  );

  Widget _buildTimerButton(int index) {
    final duration = _durations[index];
    final isSelected = _selectedDuration == duration;

    return Focus(
      focusNode: _timerFocusNodes[index],
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final key = event.logicalKey;
        int newIndex = index;

        if (key == LogicalKeyboardKey.arrowRight) {
          newIndex = (index + 1) % _timerFocusNodes.length;
        } else if (key == LogicalKeyboardKey.arrowLeft) {
          newIndex =
              (index - 1 + _timerFocusNodes.length) % _timerFocusNodes.length;
        } else if (key == LogicalKeyboardKey.arrowDown) {
          newIndex = (index + 3) % _timerFocusNodes.length;
        } else if (key == LogicalKeyboardKey.arrowUp) {
          newIndex =
              (index - 3 + _timerFocusNodes.length) % _timerFocusNodes.length;
        } else if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select) {
          setState(() {
            _selectedDuration = duration;
            _remaining = duration;
          });
          return KeyEventResult.handled;
        }

        _timerFocusNodes[newIndex].requestFocus();
        return KeyEventResult.handled;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDuration = duration;
                _remaining = duration;
              });
            },
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFocused ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Text(
                _formatDuration(duration),
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlButton({
    required String label,
    required VoidCallback onPressed,
    required FocusNode focusNode,
  }) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final key = event.logicalKey;

        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select) {
          onPressed();
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.arrowLeft) {
          FocusScope.of(context).previousFocus();
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.arrowRight) {
          FocusScope.of(context).nextFocus();
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: onPressed,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: isFocused ? Colors.green : Colors.grey[700],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFocused ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _player.dispose();
    for (var node in _timerFocusNodes) {
      node.dispose();
    }
    _startFocusNode.dispose();
    _resetFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FocusTraversalGroup(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                Text(
                  _formatDuration(_remaining),
                  style: const TextStyle(fontSize: 64, color: Colors.white),
                ),
                const SizedBox(height: 40),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: List.generate(
                    _durations.length,
                    (index) => _buildTimerButton(index),
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildControlButton(
                      label: _isRunning ? 'Stop' : 'Start',
                      onPressed: _isRunning ? _stop : _start,
                      focusNode: _startFocusNode,
                    ),
                    _buildControlButton(
                      label: 'Reset',
                      onPressed: _reset,
                      focusNode: _resetFocusNode,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
