import 'package:flutter/material.dart';

class TextInput extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSubmitted;

  const TextInput({
    super.key,
    required this.controller,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 16.0), // More padding at bottom
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Enter your command...',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: const Icon(Icons.send),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                onSubmitted(controller.text);
              }
            },
          )
        ),
        onSubmitted: onSubmitted,
      ),
    );
  }
}
