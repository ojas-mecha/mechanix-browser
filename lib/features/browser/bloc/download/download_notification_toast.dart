import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_browser/core/routes/app_routes.dart';
import 'package:mechanix_browser/core/utils/app_logger.dart';
import 'package:mechanix_browser/core/utils/app_theme.dart';
import 'package:mechanix_browser/features/browser/bloc/browser_bloc.dart';
import 'package:mechanix_browser/features/browser/bloc/download/browser_download.dart';
import 'package:mechanix_browser/features/browser/bloc/download/download_bloc.dart';
import 'package:mechanix_browser/l10n/app_localizations.dart';

/// Overlay widget showing a temporary download notification toast at the bottom right of the browser.
/// Automatically hides after 4 seconds of inactivity or upon user interaction.
class DownloadNotificationOverlay extends StatefulWidget {
  const DownloadNotificationOverlay({super.key});

  @override
  State<DownloadNotificationOverlay> createState() =>
      _DownloadNotificationOverlayState();
}

class _DownloadNotificationOverlayState
    extends State<DownloadNotificationOverlay> {
  Timer? _autoHideTimer;
  bool _isVisible = false;
  BrowserDownload? _lastDownload;

  void _resetTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorsExtension>()!;
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<DownloadBloc, DownloadState>(
      listenWhen: (previous, current) {
        return previous.lastStartedOrUpdated != current.lastStartedOrUpdated ||
            previous.activeDownloadsCount != current.activeDownloadsCount;
      },
      listener: (context, state) {
        if (state.lastStartedOrUpdated != null ||
            state.activeDownloadsCount > 0) {
          setState(() {
            _isVisible = true;
            _lastDownload = state.lastStartedOrUpdated;
          });
          _resetTimer();
        }
      },
      child: _isVisible
          ? Positioned(
              bottom: 24,
              right: 24,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: colors.panelBackground,
                child: InkWell(
                  onTap: () => _openDownloads(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.dividerColor.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF5B96F7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _lastDownload != null
                                  ? l10n.downloadingFile(
                                      _lastDownload!.filename,
                                    )
                                  : l10n.downloadingFiles,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.searchBarText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_lastDownload != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                _lastDownload!.formattedSpeed,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Future<void> _openDownloads(BuildContext context) async {
    _autoHideTimer?.cancel();
    setState(() {
      _isVisible = false;
    });
    final bloc = context.read<BrowserBloc>();
    final navigator = Navigator.of(context);
    bloc.add(const BrowserWasHiddenRequested(true));
    try {
      await navigator.pushNamed(AppRoutes.downloads);
    } catch (e) {
      AppLogger.i('Error navigating to downloads: $e');
    } finally {
      bloc.add(const BrowserWasHiddenRequested(false));
    }
  }
}
