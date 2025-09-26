import 'package:flutter/material.dart';

class FeatureButton extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onPressed;

  const FeatureButton({
    super.key,
    required this.label,
    required this.on,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      height: 75,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: on ? Colors.green : Colors.grey.shade500,
          foregroundColor: Colors.black54,
          textStyle: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}