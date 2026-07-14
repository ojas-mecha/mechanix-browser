import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_browser/features/browser/bloc/browser_bloc.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/bottom_icon_button.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/browser_menu_popup.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/browser_suggestions_panel.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/find_in_page.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/tab_count_button.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/tab_switcher_sheet.dart';

class BrowserBottomBar extends StatefulWidget {
  const BrowserBottomBar({super.key});

  @override
  State<BrowserBottomBar> createState() => _BrowserBottomBarState();
}

class _BrowserBottomBarState extends State<BrowserBottomBar> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  OverlayEntry? _menuOverlayEntry;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!mounted) return;
    setState(() {});
    if (_focusNode.hasFocus) {
      _showOverlay();
      context.read<BrowserBloc>().add(
        BrowserSearchQueryChanged(_textController.text),
      );
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    final bloc = context.read<BrowserBloc>();

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: 0,
          right: 0,
          bottom: 72, // Float above the 72px bottom bar
          child: Material(
            color: Colors.transparent,
            child: TapRegion(
              groupId: 'browser_search',
              child: BlocProvider.value(
                value: bloc,
                child: BlocBuilder<BrowserBloc, BrowserState>(
                  builder: (context, state) {
                    if (state.searchResults.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return BrowserSuggestionsPanel(
                      textController: _textController,
                      focusNode: _focusNode,
                      bloc: bloc,
                      state: state,
                      onTapItem: () {
                        _hideOverlay();
                        _focusNode.unfocus();
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  void _showMenu() {
    if (_menuOverlayEntry != null) return;

    final bloc = context.read<BrowserBloc>();

    _menuOverlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Full screen dismissible barrier
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _hideMenu,
              child: Container(
                color: Colors.black26, // Subtle dimming overlay
              ),
            ),
            // Floating menu popover positioned above the bottom bar
            Positioned(
              right: 16,
              bottom: 76, // Float exactly above the bottom bar
              width: 320, // Width matches the screenshot popover
              child: Material(
                color: Colors.transparent,
                child: BrowserMenuPopupContent(
                  bloc: bloc,
                  onDismiss: _hideMenu,
                  onFindInPage: () {
                    _hideMenu();
                    bloc.add(BrowserFindInPageInitRequested());
                  },
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_menuOverlayEntry!);
  }

  void _hideMenu() {
    if (_menuOverlayEntry != null) {
      _menuOverlayEntry!.remove();
      _menuOverlayEntry = null;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _hideOverlay();
    _hideMenu();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<BrowserBloc>();

    return BlocListener<BrowserBloc, BrowserState>(
      listenWhen: (previous, current) =>
          previous.currentUrl != current.currentUrl ||
          previous.title != current.title ||
          previous.isHomePage != current.isHomePage,
      listener: (context, state) {
        if (state.isHomePage) {
          _textController.text = '';
        } else {
          _textController.text = state.title.isNotEmpty
              ? state.title
              : state.currentUrl;
        }
      },
      child: BlocBuilder<BrowserBloc, BrowserState>(
        buildWhen: (previous, current) =>
            previous.isInitialized != current.isInitialized ||
            previous.tabs.length != current.tabs.length ||
            previous.isFindInPageActive != current.isFindInPageActive,
        builder: (context, state) {
          if (state.isFindInPageActive) {
            return const FindInPageBar();
          }
          return TapRegion(
            groupId: 'browser_search',
            onTapOutside: (event) {
              _hideOverlay();
              _focusNode.unfocus();
              context.read<BrowserBloc>().add(
                const BrowserSearchQueryChanged(''),
              );
            },
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SearchBar(
                      focusNode: _focusNode,
                      controller: _textController,
                      elevation: const WidgetStatePropertyAll(0),
                      backgroundColor: const WidgetStatePropertyAll(
                        Color(0xFF1C1C1E),
                      ),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: const BorderSide(
                            color: Colors.white10,
                            width: 1,
                          ),
                        ),
                      ),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 16),
                      ),
                      constraints: const BoxConstraints(
                        minHeight: 48,
                        maxHeight: 48,
                      ),
                      leading: const Icon(
                        Icons.lock_outline,
                        color: Color(0xFF8E8E93),
                        size: 18,
                      ),
                      hintText: "Search or enter address",
                      hintStyle: const WidgetStatePropertyAll(
                        TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
                      ),
                      textStyle: const WidgetStatePropertyAll(
                        TextStyle(color: Colors.white, fontSize: 15),
                      ),
                      onChanged: (value) {
                        _debounceTimer?.cancel();
                        _debounceTimer = Timer(
                          const Duration(milliseconds: 200),
                          () {
                            bloc.add(BrowserSearchQueryChanged(value));
                          },
                        );
                      },
                      onSubmitted: (url) {
                        if (state.isInitialized) {
                          bloc.add(BrowserUrlLoadRequested(url));
                          bloc.add(const BrowserSearchQueryChanged(''));
                          _hideOverlay();
                          _focusNode.unfocus();
                        }
                      },
                    ),
                  ),
                  if (!_focusNode.hasFocus) ...[
                    const SizedBox(width: 16),
                    BottomIconButton(
                      icon: Icons.add,
                      onTap: () {
                        if (state.isInitialized) {
                          bloc.add(const BrowserNewTabRequested());
                          bloc.add(const BrowserSearchQueryChanged(''));
                          _hideOverlay();
                          _focusNode.unfocus();
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    TabCountButton(
                      count: state.tabs.length,
                      onTap: () {
                        if (state.isInitialized) {
                          _hideOverlay();
                          _focusNode.unfocus();
                          TabSwitcherSheet.show(context, bloc);
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    BottomIconButton(
                      icon: Icons.menu,
                      onTap: () {
                        _hideOverlay();
                        _focusNode.unfocus();
                        _showMenu();
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
