import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/story.dart'; // For ApiException

class GeminiService {
  final String apiKey;
  String? _initialContext;
  // Use gemini-1.5-flash for faster responses, or gemini-pro for more complex generation
  final String _model = "gemini-1.5-flash-latest"; // or "gemini-pro"
  late final String _baseUrl;

  GeminiService({required this.apiKey}) {
    _baseUrl = "https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent";
  }

  void setInitialContext(String context) {
    _initialContext = context;
  }

  Future<String> getResponse(String userInput, String recentContext) async {
    // Combine the initial context with recent context for better continuity
    final String fullContext = _initialContext != null 
        ? "$_initialContext\n\nRecent conversation:\n$recentContext"
        : recentContext;

    final promptPayload = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {"text": "You are a text adventure game engine. Continue the story based on the history and the latest user input. Provide context for image generation if a new scene is described, by ending your response with a line like 'GENERATE IMAGE: [detailed prompt for image]' or 'NEW SCENE IMAGE: [prompt]'. Keep responses concise and engaging."},
          ]
        },
        {
          "role": "model",
          "parts": [
            {"text": "Understood. I will continue the story and provide image prompts where appropriate."}
          ]
        },
        // Consider context window limits with history. Gemini 1.5 has large context.
        if (fullContext.isNotEmpty) {
          "role": "user", // Or could be part of a system instruction / previous turns
          "parts": [{"text": "Previous story turns (most recent last):\n$fullContext"}]
        },
        {
          "role": "user",
          "parts": [{"text": "User's current action: $userInput"}]
        }
      ],
      "generationConfig": { 
        "temperature": 0.7,
        "maxOutputTokens": 300, // Adjust as needed
      }
    };

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(promptPayload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          if (data['candidates'][0]['content'] != null && 
              data['candidates'][0]['content']['parts'] != null && 
              data['candidates'][0]['content']['parts'].isNotEmpty) {
            return data['candidates'][0]['content']['parts'][0]['text']?.trim() ?? "Error: No text in response part.";
          }
        }
        // Check for safety ratings or finish reasons if content is empty
        if (data['candidates'] != null && data['candidates'].isNotEmpty && data['candidates'][0]['finishReason'] != null) {
          return "Generation stopped: ${data['candidates'][0]['finishReason']}. ${data['candidates'][0]['safetyRatings']?.toString() ?? ''}";
        }
        return "Error: Could not parse Gemini response structure. ${data.toString()}";
      } else if (response.statusCode == 401 || response.statusCode == 403) {
          throw ApiException('Authentication error with Gemini API. Please check your API key.', serviceName: 'Gemini', isAuthError: true);
      } else if (response.statusCode == 429) {
          throw ApiException('Gemini API rate limit exceeded. Please try again later or check your plan.', serviceName: 'Gemini', isLimitError: true);
      }
      else {
        throw ApiException('Gemini API Error: ${response.statusCode} ${response.body}', serviceName: 'Gemini');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      // print('Error calling Gemini API: $e');
      throw ApiException('Failed to connect to Gemini API: $e', serviceName: 'Gemini');
    }
  }
}
