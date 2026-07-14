import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_browser/features/browser/bloc/browser_bloc.dart';

class BrowserErrorPageBody extends StatelessWidget {
  final String url;

  const BrowserErrorPageBody({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    // Format the URL for clean display (e.g. strip https://)
    String cleanUrl = url;
    try {
      final uri = Uri.parse(url);
      cleanUrl = uri.host.isNotEmpty ? uri.host : url;
    } catch (_) {}

    return Container(
      color: const Color(0xFF121212), // Sleek dark mode background
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Premium error icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFF8E8E93),
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            // Title
            const Text(
              "This site can't be reached",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            // Description
            Text(
              "Check if there is a typo in $cleanUrl.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "DNS_PROBE_FINISHED_NXDOMAIN",
              style: TextStyle(
                color: Color(0xFF48484A),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 32),
            // Premium Reload Button
            ElevatedButton(
              onPressed: () {
                context.read<BrowserBloc>().add(BrowserUrlLoadRequested(url));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C2C2E),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 18),
                  SizedBox(width: 8),
                  Text(
                    "Reload",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
