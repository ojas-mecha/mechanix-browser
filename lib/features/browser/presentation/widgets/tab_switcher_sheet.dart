import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_browser/core/utils/app_theme.dart';
import 'package:mechanix_browser/core/utils/constants.dart';
import 'package:mechanix_browser/features/browser/bloc/browser_bloc.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/tab_switcher/tab_card_item.dart';
import 'package:mechanix_browser/l10n/app_localizations.dart';

class TabSwitcherSheet extends StatelessWidget {
  final BrowserBloc bloc;

  const TabSwitcherSheet({super.key, required this.bloc});

  static void show(BuildContext context, BrowserBloc bloc) {
    bloc.add(const BrowserTabSwitcherOpened());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return BlocProvider.value(
          value: bloc,
          child: TabSwitcherSheet(bloc: bloc),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final statusBarHeight = MediaQuery.paddingOf(context).top;
    final targetHeight = screenHeight - statusBarHeight - 24;

    return BlocBuilder<BrowserBloc, BrowserState>(
      buildWhen: (prev, next) =>
          prev.tabSwitcherMode != next.tabSwitcherMode ||
          prev.normalTabs != next.normalTabs ||
          prev.privateTabs != next.privateTabs ||
          prev.activeNormalTabIndex != next.activeNormalTabIndex ||
          prev.activePrivateTabIndex != next.activePrivateTabIndex,
      builder: (context, state) {
        final isPrivateView = state.tabSwitcherMode == BrowserMode.private;
        final tabList = isPrivateView ? state.privateTabs : state.normalTabs;
        final activeIndex = isPrivateView
            ? state.activePrivateTabIndex
            : state.activeNormalTabIndex;

        final colors = Theme.of(context).extension<AppColorsExtension>()!;

        return Container(
          height: targetHeight,
          color: colors.popupBottomBackground,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              const _DragHandle(),
              const SizedBox(height: 12),

              _Header(isPrivateView: isPrivateView),
              const SizedBox(height: 16),

              Flexible(
                child: Stack(
                  children: [
                    tabList.isEmpty
                        ? _EmptyState(
                            isPrivateView: isPrivateView,
                            iconColor: colors.textTertiary,
                            textColor: colors.textSecondary,
                          )
                        : _TabGrid(
                            tabList: tabList,
                            activeIndex: activeIndex,
                            bloc: bloc,
                          ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _BottomBar(
                        isPrivateView: isPrivateView,
                        hasTabs: tabList.isNotEmpty,
                        bloc: bloc,
                        state: state,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    return Container(
      width: 36,
      height: 5,
      decoration: BoxDecoration(
        color: colors.dragHandle,
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool isPrivateView;

  const _Header({required this.isPrivateView});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorsExtension>()!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isPrivateView) ...[
          const Icon(Icons.visibility_off_rounded, size: 16),
          const SizedBox(width: 8),
          Text(
            'Private Tabs',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ] else
          Text(
            'Normal Tabs',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.searchBarText,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isPrivateView;
  final Color iconColor;
  final Color textColor;

  const _EmptyState({
    required this.isPrivateView,
    required this.iconColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPrivateView ? Icons.visibility_off_rounded : Icons.public,
              size: 48,
              color: iconColor,
            ),
            const SizedBox(height: 16),
            Text(
              isPrivateView ? 'No Private Tabs' : 'No Tabs',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabGrid extends StatelessWidget {
  final List tabList;
  final int activeIndex;
  final BrowserBloc bloc;

  const _TabGrid({
    required this.tabList,
    required this.activeIndex,
    required this.bloc,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: tabList.length,
      itemBuilder: (context, index) {
        final tab = tabList[index];
        final isActive = index == activeIndex;

        return Dismissible(
          key: ValueKey('dismiss_${tab.id}'),
          direction: DismissDirection.horizontal,
          onDismissed: (_) => bloc.add(BrowserCloseTabRequested(tab.id)),
          child: TabCardItem(
            key: ValueKey('card_${tab.id}'),
            tab: tab,
            isActive: isActive,
            onTap: () {
              bloc.add(BrowserSwitchTabRequested(tab.id));
              Navigator.pop(context);
            },
            onClose: () => bloc.add(BrowserCloseTabRequested(tab.id)),
          ),
        );
      },
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool isPrivateView;
  final bool hasTabs;
  final BrowserBloc bloc;
  final BrowserState state;

  const _BottomBar({
    required this.isPrivateView,
    required this.hasTabs,
    required this.bloc,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorsExtension>()!;
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Toggle normal / private mode
        IconButton(
          onPressed: () {
            final targetIsPrivate = !isPrivateView;
            final targetTabs = targetIsPrivate
                ? state.privateTabs
                : state.normalTabs;
            if (targetTabs.isEmpty) {
              // No tabs in the target mode — open a fresh one.
              bloc.add(BrowserNewTabRequested(isPrivate: targetIsPrivate));
            } else {
              // Switch to whichever tab was last active in the target mode.
              final targetActiveIndex = targetIsPrivate
                  ? state.activePrivateTabIndex
                  : state.activeNormalTabIndex;
              final safeIndex = targetActiveIndex.clamp(
                0,
                targetTabs.length - 1,
              );
              bloc.add(BrowserSwitchTabRequested(targetTabs[safeIndex].id));
            }
            Navigator.pop(context);
          },

          tooltip: isPrivateView
              ? 'Switch to Normal Tabs'
              : 'Switch to Private Tabs',
          hoverColor: colors.shortcutHoverBackground,
          highlightColor: colors.closeButtonBackground,
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: EdgeInsets.zero,
            backgroundColor: colors.popupBottomButtonBackground,
          ),
          icon: Image.asset(
            AppImages.incognitoImage,
            width: 24,
            height: 24,
            color: colors.searchBarText,
          ),
        ),

        // Close All button (only when tabs exist)
        if (hasTabs)
          TextButton(
            onPressed: () {
              bloc.add(const BrowserCloseAllTabsRequested());
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: colors.searchBarText,
              backgroundColor: colors.popupBottomButtonBackground,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              maximumSize: Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              l10n.closeAll,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
