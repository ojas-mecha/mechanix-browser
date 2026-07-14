part of 'browser_bloc.dart';

class BrowserState extends Equatable {
  final bool isInitialized;
  final List<BrowserTab> tabs;
  final int activeTabIndex;
  final List<BrowserHistory> searchResults;
  final bool isFindInPageActive;
  final String findMatchCountText;

  const BrowserState({
    required this.isInitialized,
    required this.tabs,
    required this.activeTabIndex,
    required this.searchResults,
    required this.isFindInPageActive,
    required this.findMatchCountText,
  });

  const BrowserState.initial()
      : isInitialized = false,
        tabs = const [],
        activeTabIndex = 0,
        searchResults = const [],
        isFindInPageActive = false,
        findMatchCountText = "0/0";

  BrowserTab? get activeTab =>
      tabs.isNotEmpty && activeTabIndex >= 0 && activeTabIndex < tabs.length
          ? tabs[activeTabIndex]
          : null;
  bool get isHomePage => activeTab?.isHomePage ?? true;
  String get currentUrl => activeTab?.currentUrl ?? '';
  String get title => activeTab?.title ?? '';

  BrowserState copyWith({
    bool? isInitialized,
    List<BrowserTab>? tabs,
    int? activeTabIndex,
    List<BrowserHistory>? searchResults,
    bool? isFindInPageActive,
    String? findMatchCountText,
  }) {
    return BrowserState(
      isInitialized: isInitialized ?? this.isInitialized,
      tabs: tabs ?? this.tabs,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      searchResults: searchResults ?? this.searchResults,
      isFindInPageActive: isFindInPageActive ?? this.isFindInPageActive,
      findMatchCountText: findMatchCountText ?? this.findMatchCountText,
    );
  }

  @override
  List<Object?> get props => [
        isInitialized,
        tabs,
        activeTabIndex,
        searchResults,
        isFindInPageActive,
        findMatchCountText,
      ];
}
