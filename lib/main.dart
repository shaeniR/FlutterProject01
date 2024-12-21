import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // For encoding and decoding JSON
import 'dart:math';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'joke_service.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Joke App',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.teal.shade50,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontFamily: 'Arial', color: Colors.black),
        ),
      ),
      home: const JokeListPage(),
    );
  }
}

class JokeListPage extends StatefulWidget {
  const JokeListPage({super.key});

  @override
  _JokeListPageState createState() => _JokeListPageState();
}

class _JokeListPageState extends State<JokeListPage> {
  final JokeService _jokeService = JokeService();
  List<Map<String, dynamic>> _jokesRaw = [];
  bool _isLoading = false;
  final List<Color> _cardColors = [
    Colors.pink.shade100,
    Colors.green.shade100,
    Colors.blue.shade100,
    Colors.orange.shade100,
    Colors.yellow.shade100,
    Colors.purple.shade100,
  ];

  Future<void> _fetchJokes() async {
    setState(() => _isLoading = true);

    final hasConnection = await InternetConnectionChecker().hasConnection;
    if (!hasConnection) {
      final cachedJokes = await _loadCachedJokes();
      if (cachedJokes.isNotEmpty) {
        setState(() {
          _jokesRaw = cachedJokes;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection and no cached jokes available.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    try {
      final jokes = await _jokeService.fetchJokesRaw();
      setState(() {
        _jokesRaw = jokes;
      });

      // Cache the jokes
      await _cacheJokes(jokes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching jokes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<List<Map<String, dynamic>>> _loadCachedJokes() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJokes = prefs.getString('cached_jokes');
    if (cachedJokes != null) {
      return List<Map<String, dynamic>>.from(json.decode(cachedJokes));
    }
    return [];
  }

  Future<void> _cacheJokes(List<Map<String, dynamic>> jokes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_jokes', json.encode(jokes));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Joke App',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Get ready to laugh out loud! 😂',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                  shadows: [Shadow(color: Colors.white, blurRadius: 2)],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Image.asset(
                'assets/images/joke_image.png',
                height: 150,
                width: 150,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _fetchJokes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isLoading ? 'Loading...' : 'Make Me Laugh! 😄',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.teal,
                      ),
                    )
                  : _buildJokeList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJokeList() {
    if (_jokesRaw.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 16.0),
          child: Text(
            'No jokes fetched yet 😔',
            style: TextStyle(fontSize: 20, color: Colors.teal),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _jokesRaw.length,
      itemBuilder: (context, index) {
        final jokeJson = _jokesRaw[index];
        final randomColor = _cardColors[Random().nextInt(_cardColors.length)];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: randomColor,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  jokeJson['type'] == 'twopart'
                      ? 'Q: ${jokeJson['setup']}'
                      : jokeJson['joke'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (jokeJson['type'] == 'twopart')
                  Text(
                    'A: ${jokeJson['delivery']}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
