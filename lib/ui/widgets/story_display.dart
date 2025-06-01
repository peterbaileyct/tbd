import 'package:flutter/material.dart';
import '../../models/story.dart';
import 'image_display.dart'; // For inline image on small screens

class StoryDisplay extends StatefulWidget {
  final List<StoryElement> storyLog;
  final Widget? imageForSmallScreen; // This is actually not used if ImageElement renders itself

  const StoryDisplay({
    super.key,
    required this.storyLog,
    this.imageForSmallScreen, // Kept for potential future use, but ImageElement handles its display
  });

  @override
  State<StoryDisplay> createState() => _StoryDisplayState();
}

class _StoryDisplayState extends State<StoryDisplay> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant StoryDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.storyLog.length > oldWidget.storyLog.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8.0),
      itemCount: widget.storyLog.length,
      itemBuilder: (context, index) {
        final element = widget.storyLog[index];
        if (element is TextElement) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(element.text, style: Theme.of(context).textTheme.bodyMedium),
          );
        } else if (element is UserInputElement) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text('> ${element.text}', 
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.blueAccent[100])),
          );
        } else if (element is ImageElement) {
          // For small screens, the image is rendered inline here.
          // For larger screens, currentImageUrl is handled by main layout, this log entry is for history.
          // We use the isSmallScreen check from main.dart to decide if this particular ImageDisplay
          // instance (for the log) should be full-width or not.
          final screenSize = MediaQuery.of(context).size;
          final bool isSmallScreen = screenSize.width < 600;
          if (isSmallScreen) {
             return ImageDisplay(imageData: element.imageUrl, isSmallScreen: true);
          }
          // On larger screens, we might just log that an image was shown, or show a smaller thumbnail.
          // For now, let's not render it again here if not small screen, as main layout handles the 'current' image.
          // Or, always render it as part of the log.
          // Let's choose to always render it as it appeared in the log for consistency.
          return ImageDisplay(imageData: element.imageUrl, isSmallScreen: true); // Render as if small for log consistency
        }
        return const SizedBox.shrink();
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
