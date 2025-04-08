import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

class StopwatchScreen extends StatefulWidget {
  final GlobalKey<StopwatchScreenState> stopwatchKey;

  StopwatchScreen({GlobalKey<StopwatchScreenState>? key}) 
      : stopwatchKey = key ?? GlobalKey<StopwatchScreenState>(),
        super(key: key ?? GlobalKey<StopwatchScreenState>());

  @override
  StopwatchScreenState createState() => StopwatchScreenState();
}

class StopwatchScreenState extends State<StopwatchScreen> {
  Stopwatch _stopwatch = Stopwatch();
  late final Ticker _ticker;
  late Duration _elapsed;
  bool _isRunning = false;

  final _startPauseFocusNode = FocusNode();
  final _resetFocusNode = FocusNode();

  void autofocusStartButton() {
    _startPauseFocusNode.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    _elapsed = Duration.zero;
    _ticker = Ticker(_onTick)..start();
    // Set initial focus to the start button
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _startPauseFocusNode.requestFocus();
    });
  }

  void _onTick(Duration elapsed) {
    if (_stopwatch.isRunning) {
      setState(() {
        _elapsed = _stopwatch.elapsed;
      });
    }
  }

  void _start() {
    setState(() {
      _stopwatch.start();
      _isRunning = true;
    });
  }

  void _pause() {
    setState(() {
      _stopwatch.stop();
      _isRunning = false;
    });
  }

  void _reset() {
    setState(() {
      _stopwatch.reset();
      _elapsed = Duration.zero;
      _isRunning = false;
    });
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final minutes = two(d.inMinutes.remainder(60));
    final seconds = two(d.inSeconds.remainder(60));
    final millis = (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(
      2,
      '0',
    );
    return '$minutes:$seconds.$millis';
  }

  @override
  void dispose() {
    _ticker.dispose();
    _startPauseFocusNode.dispose();
    _resetFocusNode.dispose();
    super.dispose();
  }

  Widget buildTVButton({
    required String label,
    required VoidCallback onPressed,
    required FocusNode focusNode,
  }) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;

        if (key == LogicalKeyboardKey.arrowRight) {
          if (focusNode == _resetFocusNode) {
            return KeyEventResult.handled;
          }
          FocusScope.of(node.context!).nextFocus();
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.arrowLeft) {
          if (focusNode == _startPauseFocusNode) {
            return KeyEventResult.handled;
          }
          FocusScope.of(node.context!).previousFocus();
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select) {
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
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              margin: EdgeInsets.symmetric(horizontal: 12),
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final timerFontSize = screenHeight * 0.25; // 25% of height

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _format(_elapsed),
            style: TextStyle(
              fontSize: timerFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              buildTVButton(
                label: _isRunning ? 'Pause' : 'Start',
                onPressed: _isRunning ? _pause : _start,
                focusNode: _startPauseFocusNode,
              ),
              buildTVButton(
                label: 'Reset',
                onPressed: _reset,
                focusNode: _resetFocusNode,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
