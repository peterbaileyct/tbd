import 'package:dart_openai/dart_openai.dart';
import '../models/story.dart'; // For ApiException

class OpenAIService {
  final String apiKey;

  OpenAIService({required this.apiKey}) {
    // Initialize the OpenAI package with your API key
    OpenAI.apiKey = apiKey;
  }

  Future<String?> generateImage(String prompt) async {
    try {
      final response = await OpenAI.instance.image.create(
        prompt: prompt,
        model: 'dall-e-3',
        responseFormat: OpenAIImageResponseFormat.b64Json,
      );

      if (response.data.isNotEmpty) {
        // Return the base64 encoded image data
        return response.data[0].b64Json;
      }
      return null;
    } catch (e) {
      throw ApiException('Failed to connect to OpenAI API: $e', serviceName: 'OpenAI');
    }
  }
}
