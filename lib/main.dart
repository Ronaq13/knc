import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/timer_screen.dart';
import 'screens/circuit_screen.dart';
import 'dart:async';

void main() {
  runApp(KncApp());
}

class KncApp extends StatelessWidget {
  const KncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness Timer: Boxing, BJJ, HIIT',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.white,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
          bodyLarge: TextStyle(color: Colors.black),
          labelLarge: TextStyle(color: Colors.black),
          titleMedium: TextStyle(color: Colors.black),
          titleLarge: TextStyle(color: Colors.black),
        ),
        colorScheme: ColorScheme.light(
          primary: Colors.blue,
          secondary: Colors.blueAccent,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
        ),
      ),
      home: KncHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class KncHome extends StatefulWidget {
  const KncHome({super.key});

  @override
  State<KncHome> createState() => _KncHomeState();
}

class _KncHomeState extends State<KncHome> {
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    
    _clockTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _navigateToTimer() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => TimerScreen()),
    );
  }

  void _navigateToCircuit() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => CircuitScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {  
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          MediaQuery.of(context).size.height * 0.2,
        ),
        child: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
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
      body: Container(
        child: Column(
          children: [
            Expanded(flex: 1, child: Container()),

            Expanded(
              flex: 2,
              child: Center(
                child: Text(
                  '${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}:${_currentTime.second.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.height * 0.25,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            Expanded(flex: 1, child: Container()),

            Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _navigateToTimer,
                    child: Icon(
                      Icons.timer,
                      size: MediaQuery.of(context).size.height * 0.05,
                    ),
                  ),
                  SizedBox(width: 20),
                  GestureDetector(
                    onTap: _navigateToCircuit,
                    child: Icon(
                      Icons.loop,
                      size: MediaQuery.of(context).size.height * 0.05,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
