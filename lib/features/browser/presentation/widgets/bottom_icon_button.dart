import 'package:flutter/material.dart';

class BottomIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const BottomIconButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: Colors.white.withValues(alpha: 0.12),
      hoverColor: Colors.white.withValues(alpha: 0.24),
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
