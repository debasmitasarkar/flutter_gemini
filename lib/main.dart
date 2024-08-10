import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_gemini/utils.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Gemini Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Gemini Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _controller = TextEditingController();
  String output = '';

  final model =
      GenerativeModel(model: 'gemini-1.5-flash-latest', apiKey: geminiApiKey);
  File? _imageFile;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_imageFile != null)
              Stack(
                children: [
                  Image.file(
                    _imageFile!,
                    width: 200,
                    height: 200,
                  ),
                  Positioned(
                    top: -15,
                    right: -5,
                    child: IconButton(
                      onPressed: () => setState(() {
                        _imageFile = null;
                        _controller.clear();
                      }),
                      icon: const Icon(Icons.cancel),
                    ),
                  ),
                ],
              ),
            Row(
              children: [
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(50, 100, 50, 20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 80),
                      child: TextField(
                        maxLines: null,
                        controller: _controller,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    uploadTextToGemini(_controller.text);
                  },
                  child: const Text('Submit Text'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(Colors.deepPurple),
                    textStyle: WidgetStateProperty.all(
                      const TextStyle(color: Colors.white),
                    ),
                  ),
                  onPressed: () {
                    uploadTextAndImageToGemini(_controller.text);
                  },
                  child: const Text('Submit Text and Image',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            if (_isLoading == false)
              Flexible(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(20),
                  child: Markdown(
                    shrinkWrap: true,
                    data: output,
                    selectable: true,
                    physics: const NeverScrollableScrollPhysics(),
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(fontSize: 18, color: Colors.black),
                      h1: const TextStyle(fontSize: 24, color: Colors.black),
                      h2: const TextStyle(fontSize: 22, color: Colors.black),
                      h3: const TextStyle(fontSize: 20, color: Colors.black),
                      h4: const TextStyle(fontSize: 18, color: Colors.black),
                      h5: const TextStyle(fontSize: 16, color: Colors.black),
                      h6: const TextStyle(fontSize: 14, color: Colors.black),
                    ),
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: AILoadingAnimation(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> uploadTextToGemini(String text) async {
    // write code to upload text in gemini
    setState(() {
      output = '';
      _isLoading = true;
    });
    final content = [Content.text(text)];
    final response = await model.generateContent(content,
        generationConfig: GenerationConfig(
          temperature: 0.9,
        ),
        safetySettings: [
          SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.high),
        ]);
    setState(() {
      _isLoading = false;
      output = response.text ?? '';
    });
  }

  Future<void> uploadTextAndImageToGemini(String text) async {
    if (_imageFile == null) {
      final ImagePicker picker = ImagePicker();

      // Pick an image.
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      setState(() {
        _imageFile = File(image.path);
      });
    } else {
      setState(() {
        output = '';
        _isLoading = true;
      });
      final firstImage = await _imageFile!.readAsBytes();

      // Take Prompt from Text input
      final prompt = TextPart(_controller.text);
      final imageParts = [
        DataPart('image/jpeg', firstImage),
      ];

      // Send prompt with image to Gemini
      final response = await model.generateContent([
        Content.multi([prompt, ...imageParts])
      ]);

      setState(() {
        output = response.text ?? '';
        _isLoading = false;
      });
    }
  }
}

class AILoadingAnimation extends StatefulWidget {
  const AILoadingAnimation({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AILoadingAnimationState createState() => _AILoadingAnimationState();
}

class _AILoadingAnimationState extends State<AILoadingAnimation>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    Future.delayed(const Duration(seconds: 5), () {
      setState(() {
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedOpacity(
          opacity: _loading ? 1.0 : 0.0,
          duration: const Duration(seconds: 1),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _controller.value * 6.3,
                    child: const Icon(
                      Icons.memory,
                      color: Colors.blueAccent,
                      size: 100.0,
                    ),
                  );
                },
              ),
              const SizedBox(height: 20.0),
              const Text(
                "AI Loading Flutter...",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        AnimatedOpacity(
          opacity: !_loading ? 1.0 : 0.0,
          duration: const Duration(seconds: 1),
          child: const Icon(
            Icons.flutter_dash,
            color: Colors.blue,
            size: 150.0,
          ),
        ),
      ],
    );
  }
}
