import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
    // Only play during intervals (not breaks)
    if (isBreak) return;

    int secondsLeft = timeLeft.inSeconds;
    if (secondsLeft == 4 && _lastBeepSecond != secondsLeft) {
      _lastBeepSecond = secondsLeft;
      _playSound('end.mp3');
    } else if (secondsLeft > 4 || secondsLeft <= 0) {
      _lastBeepSecond = null; // Reset when outside the 4-second window
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

  // Add this method to play sounds
  Future<void> _playSound(String soundFile) async {
    try {
      await _audioPlayer.stop(); // Stop any current playback
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
    // Stop any currently playing sounds
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
    });
    _startInterval();
  }

  void _completeWorkout() {
    _audioPlayer.stop(); // Stop any playing sounds

    setState(() {
      isCompleted = true;
      isRunning = false;
      isPaused = false;
      stopwatch.stop();
    });
  }

  void _resetState() {
    _audioPlayer.stop(); // Stop any playing sounds

    setState(() {
      isRunning = false;
      isPaused = false;
      isCompleted = false;
      currentRound = 0;
      isBreak = false;
      isCountdown = false;
      stopwatch.stop();
    });
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  Widget _buildOptionButton<T>(T value, T? selected, void Function(T) onTap) {
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: selected == value ? Colors.amber : Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          value is Duration ? _format(value) : value.toString(),
          style: const TextStyle(fontSize: 20, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSelection<T>(
    String label,
    List<T> options,
    T? selected,
    void Function(T) onTap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 24, color: Colors.white)),
        Wrap(
          children:
              options
                  .map((e) => _buildOptionButton<T>(e, selected, onTap))
                  .toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: () {
            setState(() => isPaused = !isPaused);
          },
          child: Text(isPaused ? 'Resume' : 'Pause'),
        ),
        const SizedBox(width: 20),
        ElevatedButton(onPressed: _resetState, child: const Text('Reset')),
      ],
    );
  }

  Widget _buildTimerUI() {
    String title;
    if (isCompleted) {
      title = "Workout complete!";
    } else if (isBreak) {
      title = "Round $currentRound completed";
    } else {
      title = "Round $currentRound of $rounds";
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontSize: 28, color: Colors.white)),
        const SizedBox(height: 16),
        Text(
          _format(remaining),
          style: const TextStyle(fontSize: 64, color: Colors.white),
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
        _buildSelection<Duration>(
          'Interval',
          intervalOptions,
          interval,
          (val) => setState(() => interval = val),
        ),
        if (interval != null)
          _buildSelection<Duration>(
            'Break',
            breakOptions,
            breakDuration,
            (val) => setState(() => breakDuration = val),
          ),
        if (interval != null && breakDuration != null)
          _buildSelection<int>(
            'Rounds',
            roundOptions,
            rounds,
            (val) => setState(() {
              rounds = val;
              _startCircuit();
            }),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    stopwatch.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: isRunning || isCompleted ? _buildTimerUI() : _buildConfigUI(),
      ),
    );
  }
}
