import 'package:flutter/material.dart';

class DashedShortcutButton extends StatelessWidget {
  final VoidCallback onTap;
  const DashedShortcutButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      width: 78,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          minimumSize: const Size(56, 56),
          maximumSize: const Size(56, 56),
          side: const BorderSide(color: Color(0xFF333333), width: 1.5),
          backgroundColor: Colors.transparent,
          foregroundColor: const Color(0xFF555555),
        ).copyWith(
          side: WidgetStateProperty.resolveWith<BorderSide>((states) {
            if (states.contains(WidgetState.hovered)) {
              return const BorderSide(color: Colors.white54, width: 1.5);
            }
            return const BorderSide(color: Color(0xFF333333), width: 1.5);
          }),
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.hovered)) {
              return Colors.white.withValues(alpha: 0.06);
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.hovered)) {
              return Colors.white;
            }
            return const Color(0xFF555555);
          }),
        ),
        child: const Icon(
          Icons.add,
          size: 20,
        ),
      ),
    );
  }
}
