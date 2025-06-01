// Base class for elements in the story log
abstract class StoryElement {
  final String text; // Common text property for simplicity in some cases
  StoryElement(this.text);
}

class TextElement extends StoryElement {
  TextElement(super.text);
}

class ImageElement extends StoryElement {
  final String imageUrl; // URL of the image to display
  ImageElement(this.imageUrl) : super('Image: $imageUrl');
}

class UserInputElement extends StoryElement {
  UserInputElement(super.input);
}

// Data structure for the game loaded from .tada.json
class GameData {
  final String title;
  final String initialStoryText;
  final Map<String, dynamic> gameSpecificState;

  GameData({
    required this.title,
    required this.initialStoryText,
    required this.gameSpecificState,
  });

  factory GameData.fromJson(Map<String, dynamic> json) {
    return GameData(
      title: json['title'] ?? 'Untitled Game',
      initialStoryText: json['initial_story_text'] ?? 'The adventure begins...',
      gameSpecificState: Map<String, dynamic>.from(json['game_specific_state'] ?? {}),
    );
  }
}

class ApiException implements Exception {
  final String message;
  final String serviceName;
  final bool isAuthError;
  final bool isLimitError;

  ApiException(this.message, {required this.serviceName, this.isAuthError = false, this.isLimitError = false});

  @override
  String toString() => 'ApiException: $message (Service: $serviceName)';
}
