import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NetworkDebugScreen extends StatefulWidget {
  const NetworkDebugScreen({Key? key}) : super(key: key);

  @override
  State<NetworkDebugScreen> createState() => _NetworkDebugScreenState();
}

class _NetworkDebugScreenState extends State<NetworkDebugScreen> {
  String _result = 'Tap button to test connection';

  Future<void> _testConnection() async {
    setState(() {
      _result = 'Testing...';
    });

    final tests = <String, String>{};

    // Test 1: 10.0.2.2:8002
    try {
      final response = await http
          .get(Uri.parse('http://10.0.2.2:8002/health'))
          .timeout(const Duration(seconds: 5));
      tests['10.0.2.2:8002'] = 'SUCCESS: ${response.statusCode}';
    } catch (e) {
      tests['10.0.2.2:8002'] = 'FAILED: $e';
    }

    // Test 2: localhost:8002
    try {
      final response = await http
          .get(Uri.parse('http://localhost:8002/health'))
          .timeout(const Duration(seconds: 5));
      tests['localhost:8002'] = 'SUCCESS: ${response.statusCode}';
    } catch (e) {
      tests['localhost:8002'] = 'FAILED: $e';
    }

    // Test 3: 127.0.0.1:8002
    try {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:8002/health'))
          .timeout(const Duration(seconds: 5));
      tests['127.0.0.1:8002'] = 'SUCCESS: ${response.statusCode}';
    } catch (e) {
      tests['127.0.0.1:8002'] = 'FAILED: $e';
    }

    setState(() {
      _result = tests.entries.map((e) => '${e.key}: ${e.value}').join('\n\n');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Network Debug')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _testConnection,
              child: const Text('Test Connection'),
            ),
            const SizedBox(height: 20),
            Expanded(child: SingleChildScrollView(child: Text(_result))),
          ],
        ),
      ),
    );
  }
}
