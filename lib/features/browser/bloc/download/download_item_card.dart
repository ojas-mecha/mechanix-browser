import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_browser/core/utils/app_theme.dart';
import 'package:mechanix_browser/features/browser/bloc/download/browser_download.dart';
import 'package:mechanix_browser/features/browser/bloc/download/download_bloc.dart';
import 'package:mechanix_browser/features/browser/bloc/download/download_service.dart';

import 'download_file_badge.dart';
import 'download_progress_bar.dart';

class DownloadItemCard extends StatelessWidget {
  final BrowserDownload download;

  const DownloadItemCard({super.key, required this.download});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorsExtension>()!;

    return InkWell(
      onTap: download.status == DownloadStatus.completed
          ? () => DownloadService.openDownloadedFile(download.destinationPath)
          : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.panelBackground.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colors.dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                DownloadFileBadge(download: download),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        download.filename,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.searchBarText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _buildMetaText(context, theme, colors),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildActionButtons(context, colors),
              ],
            ),
            if (download.status == DownloadStatus.downloading ||
                download.status == DownloadStatus.paused ||
                download.status == DownloadStatus.pending ||
                download.status == DownloadStatus.failed ||
                download.status == DownloadStatus.cancelled) ...[
              const SizedBox(height: 12),
              DownloadProgressBar(download: download),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetaText(
    BuildContext context,
    ThemeData theme,
    AppColorsExtension colors,
  ) {
    if (download.status == DownloadStatus.failed ||
        download.status == DownloadStatus.cancelled) {
      final reason =
          download.errorMessage ??
          (download.status == DownloadStatus.cancelled
              ? 'Cancelled'
              : 'Network error');
      return RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.textSecondary,
          ),
          children: [
            TextSpan(text: '${download.domain} · '),
            const TextSpan(
              text: 'Failed',
              style: TextStyle(
                color: Color(0xFFE54D42),
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(text: ' · $reason'),
          ],
        ),
      );
    }

    return Text(
      download.metaText,
      style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildActionButtons(BuildContext context, AppColorsExtension colors) {
    final bloc = context.read<DownloadBloc>();

    if (download.status == DownloadStatus.downloading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.pause_rounded, size: 20),
            color: colors.textSecondary,
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                bloc.add(DownloadPauseRequested(download.downloadId)),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: colors.textSecondary,
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                bloc.add(DownloadCancelRequested(download.downloadId)),
          ),
        ],
      );
    }

    if (download.status == DownloadStatus.paused) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            color: colors.textSecondary,
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                bloc.add(DownloadResumeRequested(download.downloadId)),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: colors.textSecondary,
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                bloc.add(DownloadCancelRequested(download.downloadId)),
          ),
        ],
      );
    }

    if (download.status == DownloadStatus.failed ||
        download.status == DownloadStatus.cancelled) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: colors.textSecondary,
            visualDensity: VisualDensity.compact,
            onPressed: () => bloc.add(DownloadRetryRequested(download)),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: colors.textSecondary,
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                bloc.add(DownloadRemoveRequested(download.downloadId)),
          ),
        ],
      );
    }

    // Completed
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.folder_open_rounded, size: 20),
          color: colors.textSecondary,
          tooltip: 'Open Folder',
          visualDensity: VisualDensity.compact,
          onPressed: () =>
              DownloadService.openDownloadFolder(download.destinationPath),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 20),
          color: colors.textSecondary,
          visualDensity: VisualDensity.compact,
          onPressed: () =>
              bloc.add(DownloadRemoveRequested(download.downloadId)),
        ),
      ],
    );
  }
}
