import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io'; // For File
import 'dart:convert'; // For jsonDecode

// Import other created files
import 'models/story.dart';
import 'services/gemini_api.dart';
import 'services/openai_api.dart';
import 'ui/widgets/story_display.dart';
import 'ui/widgets/text_input.dart';
import 'ui/widgets/image_display.dart';

String? geminiApiKey;
String? openaiApiKey;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Beloved Dead',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  List<StoryElement> storyLog = [];
  String? currentImageData;
  final TextEditingController _inputController = TextEditingController();
  List<String> appLog = [];
  SharedPreferences? _prefsInstance;

  late GeminiService _geminiService;
  late OpenAIService _openAIService;

  bool _isLoadingState = true;
  bool _gameStarted = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    _prefsInstance = await SharedPreferences.getInstance();
    await _ensureApiKeys();
    if (geminiApiKey != null && openaiApiKey != null) {
      _geminiService = GeminiService(apiKey: geminiApiKey!);
      _openAIService = OpenAIService(apiKey: openaiApiKey!);
      // Load the built-in game data
      await _loadBuiltInGameData();
    } else {
       _addAppLog('One or more API keys are missing. Cannot start game initialization fully.');
    }
    if (mounted) {
      setState(() {
        _isLoadingState = false;
      });
    }
  }

  Future<void> _loadBuiltInGameData() async {
    _addAppLog('Loading built-in game data.');
    try {
      // Load the Markdown file instead of JSON
      final String mdContent = await DefaultAssetBundle.of(context)
          .loadString('assets/books/The Beloved Dead Chapter 0.tada.md');
      _initializeGameFromTada(mdContent);
      if (mounted) {
        setState(() {
          _gameStarted = true;
        });
      }
    } catch (e) {
      _addAppLog('Error loading built-in game data: $e');
      if (mounted) {
        setState(() {
          storyLog.add(TextElement('Error loading game data: $e'));
        });
      }
    }
  }

  Future<String?> _promptForKey(BuildContext dialogContext, String serviceName, String keyName) async {
    String? keyValue;
    TextEditingController keyController = TextEditingController();
    await showDialog(
      context: dialogContext, // Use passed context
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter API Key for $serviceName'),
          content: TextField(
            controller: keyController,
            decoration: InputDecoration(hintText: '$serviceName API Key'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (keyController.text.isNotEmpty) {
                    keyValue = keyController.text;
                }
                Navigator.of(context).pop();
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
    if (keyValue?.isNotEmpty == true) {
      await _prefsInstance!.setString(keyName, keyValue!);
      _addAppLog('API Key for $serviceName stored.');
    } else {
       _addAppLog('API Key for $serviceName not provided or submitted empty.');
    }
    return keyValue;
  }

  Future<void> _ensureApiKeys() async {
    geminiApiKey = _prefsInstance!.getString('gemini_api_key');
    openaiApiKey = _prefsInstance!.getString('openai_api_key');
    if (geminiApiKey == null || geminiApiKey!.isEmpty) {
      _addAppLog('Gemini API Key not found. Prompting user.');
      if (mounted) {
        geminiApiKey = await _promptForKey(context, 'Gemini', 'gemini_api_key');
      }
    }

    if (openaiApiKey == null || openaiApiKey!.isEmpty) {
      _addAppLog('OpenAI API Key not found. Prompting user.');
      if (mounted) {
        openaiApiKey = await _promptForKey(context, "OpenAI", "openai_api_key");
      }
    }

    if (geminiApiKey == null || openaiApiKey == null) {
        _addAppLog('Essential API keys are missing. Application might not function correctly.');
    }
  }

  Future<void> _promptForTadaJson() async {
    _addAppLog('Prompting user to select a .tada.json file.');
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;
      if (!filePath.toLowerCase().endsWith('.tada.json')) {
          _addAppLog('Selected file is not a .tada.json file: $filePath');
          if(mounted) {
            setState(() {
            storyLog.add(TextElement('Error: Please select a .tada.json file.'));
          });
          }
          return;
      }
      
      File file = File(filePath);
      try {
        String fileContent = await file.readAsString();
        _addAppLog('.tada.json file loaded: ${file.path}');
        _initializeGameFromTada(fileContent);
        if(mounted) {
          setState(() {
          _gameStarted = true;
        });
        }
      } catch (e) {
        _addAppLog('Error reading or parsing .tada.json file: $e');
        if(mounted) {
          setState(() {
          storyLog.add(TextElement('Error loading game file: $e'));
        });
        }
      }
    } else {
      _addAppLog('No .tada.json file selected.');
      if(mounted) {
        setState(() {
        storyLog.add(TextElement('No game file selected. Please select a .tada.json file to start.'));
      });
      }
    }
  }

  void _initializeGameFromTada(String tadaMarkdownContent) {
    _addAppLog('Initializing game from .tada.md content.');
    try {
      // Create the initial prompt for the LLM
      const String initialPrompt = "The following is the script for an interactive fiction game. "
          "Prompt the player to describe themselves and their literary preferences and customize responses based on it. "
          "E.g. if they mention a fondness for Terry Pratchett, add wordplay; if they enjoy Steinbeck, keep the prose terse and somber.";
    
      // Combine the instruction with the Markdown content
      final String combinedPrompt = "$initialPrompt\n\n$tadaMarkdownContent";
    
      // Store this as the first context for the Gemini service
      _geminiService.setInitialContext(combinedPrompt);
    
      // Add initial greeting to the story log
      if(mounted) {
        setState(() {
          storyLog.clear(); // Clear previous logs if any
          storyLog.add(TextElement("Welcome to The Beloved Dead. Please introduce yourself and mention any literary preferences you might have to customize your experience."));
        });
      }
    } catch (e) {
      _addAppLog('Error initializing game from .tada.md: $e');
      if(mounted) {
        setState(() {
          storyLog.add(TextElement('Error processing game file: $e'));
        });
      }
    }
  }

  Future<void> _handleUserInput(String input) async {
    if (input.trim().isEmpty || !_gameStarted) return;
    _addAppLog('User input: $input');
    final userInputElement = UserInputElement(input);
    if(mounted) {
      setState(() {
      storyLog.add(userInputElement);
    });
    }
    _inputController.clear();

    try {
      _addAppLog('Sending to Gemini: $input');
      String storyResponse = await _geminiService.getResponse(input, storyLogToString());
      _addAppLog('Received from Gemini: $storyResponse');
      if(mounted) {
        setState(() {
        storyLog.add(TextElement(storyResponse));
      });
      }

      if (storyResponse.toLowerCase().contains("generate image:") || storyResponse.toLowerCase().contains("new scene image:")) { 
        String imagePrompt = storyResponse.substring(storyResponse.toLowerCase().indexOf("image:") + 6).trim();
        if (imagePrompt.isEmpty) imagePrompt = "Sci-fi scene: ${storyLog.lastWhere((e) => e is TextElement, orElse: () => TextElement('')).text}";
        
         _addAppLog('Requesting image from OpenAI for prompt: $imagePrompt');
          String? imageData = await _openAIService.generateImage(imagePrompt);
          _addAppLog('Received base64 image data from OpenAI');
          if (imageData != null && mounted) {
            setState(() {
              currentImageData = imageData; // Now storing base64 data
              storyLog.add(ImageElement(imageData));
            });
          }
        else {
          _addAppLog('Failed to generate image or component not mounted.');
        }
      }
    } on ApiException catch (e) {
        _addAppLog('API Error: ${e.message}');
        if(mounted) {
          setState(() {
          storyLog.add(TextElement('API Error: ${e.message}'));
        });
        }
        if (e.isAuthError || e.isLimitError) {
            _addAppLog('Attempting to re-authenticate for ${e.serviceName}');
            if (e.serviceName.toLowerCase().contains('gemini')) {
                await _prefsInstance!.remove('gemini_api_key');
                geminiApiKey = null;
            } else if (e.serviceName.toLowerCase().contains('openai')) {
                await _prefsInstance!.remove('openai_api_key');
                openaiApiKey = null;
            }
            await _ensureApiKeys(); 
            if ((e.serviceName.toLowerCase().contains('gemini') && geminiApiKey != null && _prefsInstance!.getString('gemini_api_key') != null) ||
                (e.serviceName.toLowerCase().contains('openai') && openaiApiKey != null && _prefsInstance!.getString('openai_api_key') != null) ) {
                 _addAppLog('New API key provided for ${e.serviceName}. Please try your command again.');
                 if(mounted) {
                   setState(() {
                     storyLog.add(TextElement('New API key provided for ${e.serviceName}. Please try your command again.'));
                 });
                 }
            } else {
                 _addAppLog('Failed to get new API key for ${e.serviceName}.');
                 if(mounted) {
                   setState(() {
                     storyLog.add(TextElement('Failed to get new API key for ${e.serviceName}.'));
                 });
                 }
            }
        }
    } catch (e) {
      _addAppLog('Error processing input: $e');
      if(mounted) {
        setState(() {
        storyLog.add(TextElement('Error: Could not process your request. $e'));
      });
      }
    }
  }

  String storyLogToString() {
    // Provide limited history to avoid large payloads / context window issues
    return storyLog.reversed.whereType<TextElement>().take(5).map((e) => e.text).toList().reversed.join('\n');
  }
  
  void _addAppLog(String message) {
    final timestamp = DateTime.now().toIso8601String();
    if(mounted) {
      setState(() {
      appLog.insert(0, '$timestamp: $message');
    });
    }
    // Log to console for easier debugging during development
    // print('$timestamp: $message'); 
  }

  void _showAppLog() {
    _addAppLog('Application log viewed.');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Application Log'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: appLog.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text(appLog[index], style: const TextStyle(fontSize: 12)),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingState) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (geminiApiKey == null || openaiApiKey == null) {
         return Scaffold(
            appBar: AppBar(title: const Text('The Beloved Dead - API Key Error')),
            body: Center(
                child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'One or more API keys are missing. Please provide them when prompted or ensure they are stored.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isLoadingState = true;
                            });
                            _initializeApp(); // Retry initialization
                          },
                          child: const Text('Retry API Key Setup'),
                        )
                      ],
                    )
                ),
            ),
        );
    }
    if (!_gameStarted) {
        return Scaffold(
            appBar: AppBar(title: const Text('The Beloved Dead - Load Game')),
            body: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        if (storyLog.isNotEmpty && storyLog.last is TextElement)
                            Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text((storyLog.last as TextElement).text, style: TextStyle(color: storyLog.last.text.toLowerCase().contains('error') ? Colors.red : Theme.of(context).textTheme.bodyLarge?.color), textAlign: TextAlign.center,),
                            ),
                        ElevatedButton(
                            onPressed: _promptForTadaJson,
                            child: const Text('Select Game File (.tada.json)'),
                        ),
                    ],
                ),
            ),
             floatingActionButton: FloatingActionButton(
                onPressed: _showAppLog,
                tooltip: 'Show Application Log',
                child: const Icon(Icons.receipt_long),
            ),
        );
    }

    final orientation = MediaQuery.of(context).orientation;
    final screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 600;

    Widget imageWidget = currentImageData != null
        ? ImageDisplay(
            key: ValueKey(currentImageData), // Ensure widget rebuilds on URL change
          imageData: currentImageData!,
            isSmallScreen: isSmallScreen,
          )
        : const SizedBox.shrink();

    Widget storyArea = Expanded(
      child: StoryDisplay(storyLog: storyLog, imageForSmallScreen: isSmallScreen && currentImageData != null ? imageWidget : null),
    );
    Widget inputArea = TextInput(controller: _inputController, onSubmitted: _handleUserInput);

    return Scaffold(
      appBar: AppBar(
        title: const Text('The Beloved Dead'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: _showAppLog,
            tooltip: 'Show Application Log',
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (isSmallScreen) {
              return Column(
                children: [
                  storyArea, // StoryDisplay handles inline image if imageForSmallScreen is provided
                  inputArea,
                ],
              );
            } else if (orientation == Orientation.landscape) {
              return Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [storyArea, inputArea],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Center(child: Padding(padding: const EdgeInsets.all(8.0), child: imageWidget)),
                  ),
                ],
              );
            } else { // Portrait
              return Column(
                children: [
                  Expanded(
                    flex: 1,
                    child: Center(child: Padding(padding: const EdgeInsets.all(8.0), child: imageWidget)),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [storyArea, inputArea],
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}
