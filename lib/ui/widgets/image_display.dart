import 'package:flutter/material.dart';
import 'dart:convert'; // For base64 decoding
import 'dart:typed_data'; // For Uint8List

class ImageDisplay extends StatelessWidget {
  final String imageData; // Now base64-encoded image data instead of URL
  final bool isSmallScreen;

  const ImageDisplay({
    super.key,
    required this.imageData,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    // Convert base64 to Uint8List
    Uint8List imageBytes;
    try {
      String base64String = imageData;
      // Remove data URL prefix if present (e.g., "data:image/png;base64,")
      if (base64String.contains(',')) {
        base64String = base64String.split(',')[1];
      }
      imageBytes = base64Decode(base64String);
    } catch (e) {
      return Text('Invalid image data: $e');
    }

    Widget imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(8.0), // Optional: rounded corners
      child: Image.memory(
        imageBytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Text('Error loading image: $error');
        },
      ),
    );

    if (isSmallScreen) {
      // For small screens, display as a square image within the text flow.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
        child: Center(
          child: AspectRatio(
            aspectRatio: 1.0, // Square image
            child: imageWidget,
          ),
        ),
      );
    }

    // For larger screens, it's placed by LayoutBuilder in main.dart.
    // Ensure it's constrained and centered if it's not taking full space given by parent.
    return AspectRatio(
      aspectRatio: 1.0, // Maintain square aspect ratio
      child: imageWidget,
    );
  }
}
