import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/mobile/flutter_gemma_mobile.dart';

/// Example showing how to bundle and use a model with your app
/// 
/// Setup steps:
/// 1. Add model file to assets/ folder
///    For models > 2GB, split into parts: your-model.bin.part1, .part2, etc.
///    Use scripts/split_model.sh to split large files
/// 
/// 2. Declare in pubspec.yaml:
///    flutter:
///      assets:
///        - assets/models/your-model.bin        # Single file
///        # OR for large models:
///        - assets/models/your-model.bin.part1  # Multi-part
///        - assets/models/your-model.bin.part2
///        - assets/models/your-model.bin.part3
/// 
/// 3. Run this example
/// 
/// Note: Multi-part files are auto-detected and assembled automatically.
/// Just reference the base filename in modelUrl.
class BundledModelExample extends StatefulWidget {
  const BundledModelExample({super.key});

  @override
  State<BundledModelExample> createState() => _BundledModelExampleState();
}

class _BundledModelExampleState extends State<BundledModelExample> {
  String _status = 'Not initialized';
  bool _isInstalling = false;
  InferenceModel? _model;

  @override
  void initState() {
    super.initState();
    _initializeBundledModel();
  }

  Future<void> _initializeBundledModel() async {
    setState(() {
      _status = 'Checking bundled model...';
      _isInstalling = true;
    });

    try {
      // Define your bundled model
      // Replace with your actual model file name
      final modelSpec = InferenceModelSpec(
        name: 'gemma-2b-bundled',
        modelUrl: 'asset://assets/models/gemma-2b-it.bin',
      );

      // Check if already installed
      final isInstalled = await BundledModelInstaller.isInstalled(modelSpec);
      
      if (isInstalled) {
        setState(() {
          _status = 'Model already installed ✓';
        });
      } else {
        setState(() {
          _status = 'Installing model from app bundle...\n(This only happens once)';
        });

        // Install from bundled assets
        await BundledModelInstaller.installIfNeeded(modelSpec);

        setState(() {
          _status = 'Model installed successfully ✓';
        });
      }

      // Now create the model for inference
      setState(() {
        _status = 'Loading model into memory...';
      });

      _model = await FlutterGemmaPlugin.instance.createModel(
        modelType: ModelType.gemmaIt,
        preferredBackend: PreferredBackend.gpu,
        maxTokens: 512,
      );

      setState(() {
        _status = 'Model ready for inference! ✓';
        _isInstalling = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isInstalling = false;
      });
    }
  }

  Future<void> _testInference() async {
    if (_model == null) {
      setState(() {
        _status = 'Model not loaded';
      });
      return;
    }

    setState(() {
      _status = 'Generating response...';
    });

    try {
      final session = await _model!.createSession();
      await session.addQueryChunk(const Message(text: 'Hello! Tell me a short joke.', isUser: true));
      final response = await session.getResponse();

      setState(() {
        _status = 'Response:\n$response';
      });

      await session.close();
    } catch (e) {
      setState(() {
        _status = 'Error during inference: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bundled Model Example'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isInstalling)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    Text(
                      _status,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isInstalling || _model == null ? null : _testInference,
              icon: const Icon(Icons.smart_toy),
              label: const Text('Test Inference'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            const Expanded(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How it works:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '1. Model is bundled with your app\n\n'
                          '2. On first launch, it\'s copied to app documents directory\n\n'
                          '3. Model path is registered in SharedPreferences\n\n'
                          '4. On subsequent launches, copy step is skipped\n\n'
                          '5. Model is instantly available for inference',
                          style: TextStyle(fontSize: 14),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Benefits:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '✓ No network required\n'
                          '✓ Works offline immediately\n'
                          '✓ Guaranteed model availability\n'
                          '✓ One-time setup cost',
                          style: TextStyle(fontSize: 14, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _model?.close();
    super.dispose();
  }
}

// Usage in main.dart:
// 
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   
//   // Optional: Install model before app starts
//   // await BundledModelInstaller.installIfNeeded(
//   //   InferenceModelSpec(
//   //     name: 'gemma-2b-bundled',
//   //     modelUrl: 'asset://assets/models/gemma-2b-it.bin',
//   //   ),
//   // );
//   
//   runApp(MaterialApp(
//     home: BundledModelExample(),
//   ));
// }