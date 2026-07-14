import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_browser/features/browser/data/models/browser_tab.dart';
import 'package:webview_cef/webview_cef.dart';

import '../../../core/utils/constants.dart';
import '../data/models/browser_history.dart';
import '../data/repositories/history_repository.dart';

part 'browser_event.dart';
part 'browser_state.dart';

class BrowserBloc extends Bloc<BrowserEvent, BrowserState> {
  HistoryRepository? _historyRepository;
  int _tabIdCounter = 0;

  WebViewController get controller {
    final tab = state.activeTab;
    if (tab != null) return tab.controller;
    throw StateError("No active tab controller available.");
  }

  BrowserBloc() : super(BrowserState.initial()) {
    on<BrowserInitialized>(_onInitialized);
    on<BrowserUrlLoadRequested>(_onUrlLoadRequested);
    on<BrowserGoBackRequested>(_onGoBack);
    on<BrowserGoForwardRequested>(_onGoForward);
    on<BrowserReloadRequested>(_onReload);
    on<BrowserDevToolsRequested>(_onDevTools);
    on<BrowserGoHomeRequested>(_onGoHome);
    on<BrowserUrlChanged>(_onUrlChanged);
    on<BrowserTitleChanged>(_onTitleChanged);
    on<BrowserHistoryClearRequested>(_onHistoryClearRequested);
    on<BrowserSearchQueryChanged>(_onSearchQueryChanged);
    on<BrowserHistoryItemDeleted>(_onHistoryItemDeleted);
    on<BrowserNewTabRequested>(_onNewTabRequested);
    on<BrowserCloseTabRequested>(_onCloseTab);
    on<BrowserSwitchTabRequested>(_onSwitchTab);
    on<BrowserCloseAllTabsRequested>(_onCloseAllTabs);
    on<BrowserFindInPageInitRequested>(_onFindInPageInit);
    on<BrowserFindInPageQueryChanged>(_onFindInPageQueryChanged);
    on<BrowserFindInPageNextRequested>(_onFindInPageNext);
    on<BrowserFindInPagePrevRequested>(_onFindInPagePrev);
    on<BrowserFindInPageCloseRequested>(_onFindInPageClose);
  }

  BrowserTab _createNewTab(String initialUrl) {
    final injectUserScripts = InjectUserScripts();
    injectUserScripts.add(
      UserScript(
        "console.log('injectScript_in_LoadStart')",
        ScriptInjectTime.LOAD_START,
      ),
    );
    injectUserScripts.add(
      UserScript(
        "console.log('injectScript_in_LoadEnd')",
        ScriptInjectTime.LOAD_END,
      ),
    );

    final controller = WebviewManager().createWebView(
      loading: const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      ),
      injectUserScripts: injectUserScripts,
    );

    final tabId =
        'tab_${DateTime.now().millisecondsSinceEpoch}_${_tabIdCounter++}';
    final listener = _createEventListenerForTab(tabId, controller);
    controller.setWebviewListener(listener);
    controller.initialize(initialUrl);

    return BrowserTab(
      id: tabId,
      controller: controller,
      currentUrl: initialUrl == AppConstants.homepageUrl ? '' : initialUrl,
      title: '',
      isHomePage: initialUrl == AppConstants.homepageUrl,
    );
  }

  WebviewEventsListener _createEventListenerForTab(
    String tabId,
    WebViewController controller,
  ) {
    return WebviewEventsListener(
      onTitleChanged: (t) {
        add(BrowserTitleChanged(tabId: tabId, title: t));
      },
      onUrlChanged: (url) {
        if (url.startsWith('data:')) return;
        add(BrowserUrlChanged(tabId: tabId, url: url));

        final Set<JavascriptChannel> jsChannels = {
          JavascriptChannel(
            name: 'Print',
            onMessageReceived: (JavascriptMessage message) {
              debugPrint(message.message);
              controller.sendJavaScriptChannelCallBack(
                false,
                "{'code':'200','message':'print succeed!'}",
                message.callbackId,
                message.frameId,
              );
            },
          ),
        };
        controller.setJavaScriptChannels(jsChannels);
        controller.executeJavaScript("function abc(e){return 'abc:'+ e}");
        controller
            .evaluateJavascript("abc('test')")
            .then((value) => debugPrint(value));
      },
      onLoadStart: (c, url) {
        if (url.startsWith('data:')) return;
        debugPrint("onLoadStart => $url");
      },
      onLoadEnd: (c, url) {
        if (url.startsWith('data:')) return;
        debugPrint("onLoadEnd => $url");
      },
    );
  }

  Future<void> _onInitialized(
    BrowserInitialized event,
    Emitter<BrowserState> emit,
  ) async {
    try {
      _historyRepository = await HistoryRepository.create();

      await WebviewManager().initialize(
        userAgent: AppConstants.defaultUserAgent,
      );

      final firstTab = _createNewTab(AppConstants.homepageUrl);

      emit(
        state.copyWith(
          isInitialized: true,
          tabs: [firstTab],
          activeTabIndex: 0,
        ),
      );
    } catch (e) {
      debugPrint("Webview initialization error: $e");
    }
  }

  Future<void> _onNewTabRequested(
    BrowserNewTabRequested event,
    Emitter<BrowserState> emit,
  ) async {
    if (!state.isInitialized) return;

    final oldTab = state.activeTab;
    if (oldTab != null) {
      if (oldTab.controller.value) {
        await oldTab.controller.setClientFocus(false);
        await oldTab.controller.executeJavaScript(
          "document.dispatchEvent(new Event('visibilitychange'))",
        );
      }
    }

    final newTab = _createNewTab(event.initialUrl ?? AppConstants.homepageUrl);
    final updatedTabs = List<BrowserTab>.from(state.tabs)..add(newTab);
    final newActiveIndex = updatedTabs.length - 1;

    emit(
      state.copyWith(
        tabs: updatedTabs,
        activeTabIndex: newActiveIndex,
        isFindInPageActive: false,
        findMatchCountText: "0/0",
      ),
    );

    newTab.controller.ready.then((_) async {
      final currentActiveTab = state.activeTab;
      if (currentActiveTab != null && currentActiveTab.id == newTab.id) {
        await newTab.controller.setClientFocus(true);
      }
    });
  }

  Future<void> _onCloseTab(
    BrowserCloseTabRequested event,
    Emitter<BrowserState> emit,
  ) async {
    final index = event.index;
    if (index < 0 || index >= state.tabs.length) return;

    if (state.tabs.length == 1) {
      final activeTab = state.tabs[index];
      final updatedTab = activeTab.copyWith(
        isHomePage: true,
        currentUrl: '',
        title: '',
      );
      emit(
        state.copyWith(
          tabs: [updatedTab],
          activeTabIndex: 0,
          isFindInPageActive: false,
          findMatchCountText: "0/0",
        ),
      );
      if (activeTab.controller.value) {
        await activeTab.controller.loadUrl(AppConstants.homepageUrl);
      }
      return;
    }

    final tabToClose = state.tabs[index];
    await tabToClose.controller.dispose();

    final updatedTabs = List<BrowserTab>.from(state.tabs)..removeAt(index);

    int newActiveIndex = state.activeTabIndex;
    if (index == state.activeTabIndex) {
      if (newActiveIndex >= updatedTabs.length) {
        newActiveIndex = updatedTabs.length - 1;
      }
    } else if (index < state.activeTabIndex) {
      newActiveIndex = state.activeTabIndex - 1;
    }

    emit(
      state.copyWith(
        tabs: updatedTabs,
        activeTabIndex: newActiveIndex,
        isFindInPageActive: false,
        findMatchCountText: "0/0",
      ),
    );

    final newActiveTab = updatedTabs[newActiveIndex];
    if (newActiveTab.controller.value) {
      await newActiveTab.controller.setClientFocus(true);
    } else {
      newActiveTab.controller.ready.then((_) async {
        final currentActiveTab = state.activeTab;
        if (currentActiveTab != null &&
            currentActiveTab.id == newActiveTab.id) {
          await newActiveTab.controller.setClientFocus(true);
        }
      });
    }
  }

  Future<void> _onSwitchTab(
    BrowserSwitchTabRequested event,
    Emitter<BrowserState> emit,
  ) async {
    final index = event.index;
    if (index < 0 || index >= state.tabs.length) return;
    if (state.activeTabIndex == index) return;

    final oldTab = state.activeTab;
    final newTab = state.tabs[index];

    if (oldTab != null) {
      if (oldTab.controller.value) {
        await oldTab.controller.setClientFocus(false);
        await oldTab.controller.executeJavaScript(
          "document.dispatchEvent(new Event('visibilitychange'))",
        );
      }
    }

    emit(
      state.copyWith(
        activeTabIndex: index,
        isFindInPageActive: false,
        findMatchCountText: "0/0",
      ),
    );

    if (newTab.controller.value) {
      await newTab.controller.setClientFocus(true);
    } else {
      newTab.controller.ready.then((_) async {
        final currentActiveTab = state.activeTab;
        if (currentActiveTab != null && currentActiveTab.id == newTab.id) {
          await newTab.controller.setClientFocus(true);
        }
      });
    }
  }

  Future<void> _onCloseAllTabs(
    BrowserCloseAllTabsRequested event,
    Emitter<BrowserState> emit,
  ) async {
    for (final tab in state.tabs) {
      await tab.controller.dispose();
    }

    final firstTab = _createNewTab(AppConstants.homepageUrl);

    emit(
      state.copyWith(
        tabs: [firstTab],
        activeTabIndex: 0,
        isFindInPageActive: false,
        findMatchCountText: "0/0",
      ),
    );

    firstTab.controller.ready.then((_) async {
      final currentActiveTab = state.activeTab;
      if (currentActiveTab != null && currentActiveTab.id == firstTab.id) {
        await firstTab.controller.setClientFocus(true);
      }
    });
  }

  Future<void> _onUrlLoadRequested(
    BrowserUrlLoadRequested event,
    Emitter<BrowserState> emit,
  ) async {
    if (!state.isInitialized || state.activeTab == null) return;

    String finalUrl = event.url.trim();
    if (finalUrl.isEmpty) return;

    final isUri = Uri.tryParse(event.url.trim())?.isAbsolute;

    if (!isUri!) {
      if (finalUrl.contains('.') && !finalUrl.contains(' ')) {
        finalUrl = '${AppConstants.defaultScheme}$finalUrl';
      } else {
        finalUrl =
            '${AppConstants.searchUrlPrefix}${Uri.encodeComponent(finalUrl)}';
      }
    }

    final activeTab = state.activeTab!;
    final updatedTab = activeTab.copyWith(
      isHomePage: false,
      currentUrl: finalUrl,
    );
    final updatedTabs = List<BrowserTab>.from(state.tabs);
    updatedTabs[state.activeTabIndex] = updatedTab;

    emit(
      state.copyWith(
        tabs: updatedTabs,
        searchResults: [],
        isFindInPageActive: false,
        findMatchCountText: "0/0",
      ),
    );
    if (activeTab.controller.value) {
      await activeTab.controller.loadUrl(finalUrl);
    }
  }

  Future<void> _onGoBack(
    BrowserGoBackRequested event,
    Emitter<BrowserState> emit,
  ) async {
    final activeTab = state.activeTab;
    if (activeTab != null && activeTab.controller.value) {
      await activeTab.controller.goBack();
    }
  }

  Future<void> _onGoForward(
    BrowserGoForwardRequested event,
    Emitter<BrowserState> emit,
  ) async {
    final activeTab = state.activeTab;
    if (activeTab != null && activeTab.controller.value) {
      await activeTab.controller.goForward();
    }
  }

  Future<void> _onReload(
    BrowserReloadRequested event,
    Emitter<BrowserState> emit,
  ) async {
    final activeTab = state.activeTab;
    if (activeTab != null && activeTab.controller.value) {
      await activeTab.controller.reload();
    }
  }

  Future<void> _onDevTools(
    BrowserDevToolsRequested event,
    Emitter<BrowserState> emit,
  ) async {
    final activeTab = state.activeTab;
    if (activeTab != null && activeTab.controller.value) {
      await activeTab.controller.openDevTools();
    }
  }

  Future<void> _onGoHome(
    BrowserGoHomeRequested event,
    Emitter<BrowserState> emit,
  ) async {
    final activeTab = state.activeTab;
    if (activeTab != null) {
      final updatedTab = activeTab.copyWith(isHomePage: true, currentUrl: '');
      final updatedTabs = List<BrowserTab>.from(state.tabs);
      updatedTabs[state.activeTabIndex] = updatedTab;
      emit(
        state.copyWith(
          tabs: updatedTabs,
          isFindInPageActive: false,
          findMatchCountText: "0/0",
        ),
      );
      if (activeTab.controller.value) {
        await activeTab.controller.loadUrl(AppConstants.homepageUrl);
      }
    }
  }

  void _onUrlChanged(BrowserUrlChanged event, Emitter<BrowserState> emit) {
    final index = state.tabs.indexWhere((t) => t.id == event.tabId);
    if (index == -1) return;

    final isHome = event.url == AppConstants.homepageUrl || event.url.isEmpty;
    final updatedTab = state.tabs[index].copyWith(
      isHomePage: isHome,
      currentUrl: isHome ? '' : event.url,
    );

    final updatedTabs = List<BrowserTab>.from(state.tabs);
    updatedTabs[index] = updatedTab;

    emit(
      state.copyWith(
        tabs: updatedTabs,
        isFindInPageActive: false,
        findMatchCountText: "0/0",
      ),
    );
  }

  void _onTitleChanged(BrowserTitleChanged event, Emitter<BrowserState> emit) {
    final index = state.tabs.indexWhere((t) => t.id == event.tabId);
    if (index == -1) return;

    final updatedTab = state.tabs[index].copyWith(title: event.title);

    final updatedTabs = List<BrowserTab>.from(state.tabs);
    updatedTabs[index] = updatedTab;

    emit(state.copyWith(tabs: updatedTabs));
  }

  Future<void> _onHistoryClearRequested(
    BrowserHistoryClearRequested event,
    Emitter<BrowserState> emit,
  ) async {
    if (_historyRepository != null) {
      _historyRepository!.clearHistory();
    }
  }

  void _onSearchQueryChanged(
    BrowserSearchQueryChanged event,
    Emitter<BrowserState> emit,
  ) {
    if (_historyRepository == null) return;

    if (event.query.trim().isEmpty) {
      final allHistory = _historyRepository!.getHistory();
      emit(state.copyWith(searchResults: allHistory));
      return;
    }

    final results = _historyRepository!.searchHistory(event.query);

    final seenUrls = <String>{};
    final uniqueResults = <BrowserHistory>[];
    for (final item in results) {
      final normalizedUrl = item.url.trim().toLowerCase();
      if (normalizedUrl.isNotEmpty && seenUrls.add(normalizedUrl)) {
        uniqueResults.add(item);
      }
    }

    emit(state.copyWith(searchResults: uniqueResults));
  }

  void _onHistoryItemDeleted(
    BrowserHistoryItemDeleted event,
    Emitter<BrowserState> emit,
  ) {
    if (_historyRepository != null) {
      _historyRepository!.historyBox.remove(event.item.id);

      if (event.currentQuery.trim().isEmpty) {
        final allHistory = _historyRepository!.getHistory();
        emit(state.copyWith(searchResults: allHistory));
      } else {
        final results = _historyRepository!.searchHistory(event.currentQuery);

        final seenUrls = <String>{};
        final uniqueResults = <BrowserHistory>[];
        for (final item in results) {
          final normalizedUrl = item.url.trim().toLowerCase();
          if (normalizedUrl.isNotEmpty && seenUrls.add(normalizedUrl)) {
            uniqueResults.add(item);
          }
        }

        emit(state.copyWith(searchResults: uniqueResults));
      }
    }
  }

  @override
  Future<void> close() async {
    for (final tab in state.tabs) {
      tab.controller.dispose();
    }
    await WebviewManager().quit();
    _historyRepository?.close();
    return super.close();
  }

  Future<void> _onFindInPageInit(
    BrowserFindInPageInitRequested event,
    Emitter<BrowserState> emit,
  ) async {
    if (!state.isInitialized || state.activeTab == null) return;

    try {
      await controller.executeJavaScript(_findInPageJs);
    } catch (e) {
      debugPrint("Error injecting find in page JS: $e");
    }

    emit(state.copyWith(isFindInPageActive: true, findMatchCountText: "0/0"));
  }

  Future<void> _onFindInPageQueryChanged(
    BrowserFindInPageQueryChanged event,
    Emitter<BrowserState> emit,
  ) async {
    if (!state.isInitialized || state.activeTab == null) return;

    try {
      final escapedQuery = event.query.replaceAll("'", "\\'");
      final dynamic result = await controller.evaluateJavascript(
        "window.__cefFindInPage.highlight('$escapedQuery')",
      );
      emit(state.copyWith(findMatchCountText: result?.toString() ?? "0/0"));
    } catch (e) {
      debugPrint("Error finding text: $e");
    }
  }

  Future<void> _onFindInPageNext(
    BrowserFindInPageNextRequested event,
    Emitter<BrowserState> emit,
  ) async {
    if (!state.isInitialized || state.activeTab == null) return;

    try {
      final dynamic result = await controller.evaluateJavascript(
        "window.__cefFindInPage.next()",
      );
      emit(state.copyWith(findMatchCountText: result?.toString() ?? "0/0"));
    } catch (e) {
      debugPrint("Error finding next: $e");
    }
  }

  Future<void> _onFindInPagePrev(
    BrowserFindInPagePrevRequested event,
    Emitter<BrowserState> emit,
  ) async {
    if (!state.isInitialized || state.activeTab == null) return;

    try {
      final dynamic result = await controller.evaluateJavascript(
        "window.__cefFindInPage.prev()",
      );
      emit(state.copyWith(findMatchCountText: result?.toString() ?? "0/0"));
    } catch (e) {
      debugPrint("Error finding prev: $e");
    }
  }

  Future<void> _onFindInPageClose(
    BrowserFindInPageCloseRequested event,
    Emitter<BrowserState> emit,
  ) async {
    if (state.isInitialized && state.activeTab != null) {
      try {
        await controller.executeJavaScript("window.__cefFindInPage.clear()");
      } catch (e) {
        debugPrint("Error clearing find in page: $e");
      }
    }

    emit(state.copyWith(isFindInPageActive: false, findMatchCountText: "0/0"));
  }
}

const String _findInPageJs = r'''
(function() {
  if (window.__cefFindInPage) return;
  class CefFindInPage {
    constructor() {
      this.matches = [];
      this.currentIndex = -1;
      this.query = "";
      this.injectStyle();
    }
    injectStyle() {
      if (document.getElementById('cef-find-style')) return;
      const style = document.createElement('style');
      style.id = 'cef-find-style';
      style.textContent = `
        mark.cef-find-match {
          background-color: #fce83a !important;
          color: #000000 !important;
          padding: 0 !important;
          margin: 0 !important;
        }
        mark.cef-find-active {
          background-color: #ff9800 !important;
          color: #000000 !important;
          box-shadow: 0 0 3px rgba(0,0,0,0.5) !important;
        }
      `;
      document.head.appendChild(style);
    }
    clear() {
      this.removeHighlights();
      const style = document.getElementById('cef-find-style');
      if (style) style.remove();
      this.matches = [];
      this.currentIndex = -1;
      this.query = "";
    }
    removeHighlights() {
      const highlighted = document.querySelectorAll('mark.cef-find-match');
      for (let i = highlighted.length - 1; i >= 0; i--) {
        const el = highlighted[i];
        const parent = el.parentNode;
        if (parent) {
          const textNode = document.createTextNode(el.textContent);
          parent.replaceChild(textNode, el);
          parent.normalize();
        }
      }
      this.matches = [];
      this.currentIndex = -1;
    }
    highlight(query) {
      this.removeHighlights();
      if (!query || query.trim() === "") {
        return "0/0";
      }
      this.query = query;
      this.injectStyle();
      
      const textNodes = [];
      const walk = document.createTreeWalker(
        document.body,
        NodeFilter.SHOW_TEXT,
        {
          acceptNode: function(node) {
            const parent = node.parentNode;
            if (!parent) return NodeFilter.FILTER_REJECT;
            const tag = parent.tagName.toUpperCase();
            if (['SCRIPT', 'STYLE', 'TEXTAREA', 'INPUT', 'NOSCRIPT', 'IFRAME'].includes(tag)) {
              return NodeFilter.FILTER_REJECT;
            }
            return NodeFilter.FILTER_ACCEPT;
          }
        }
      );
      
      let node;
      while (node = walk.nextNode()) {
        textNodes.push(node);
      }
      
      const escaped = query.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&');
      const regex = new RegExp("(" + escaped + ")", "gi");
      
      for (let i = textNodes.length - 1; i >= 0; i--) {
        const textNode = textNodes[i];
        const text = textNode.nodeValue;
        if (regex.test(text)) {
          const parent = textNode.parentNode;
          if (!parent) continue;
          regex.lastIndex = 0;
          const fragments = document.createDocumentFragment();
          let lastIdx = 0;
          let match;
          while ((match = regex.exec(text)) !== null) {
            if (match.index > lastIdx) {
              fragments.appendChild(document.createTextNode(text.substring(lastIdx, match.index)));
            }
            const mark = document.createElement('mark');
            mark.className = 'cef-find-match';
            mark.textContent = match[0];
            fragments.appendChild(mark);
            lastIdx = regex.lastIndex;
          }
          if (lastIdx < text.length) {
            fragments.appendChild(document.createTextNode(text.substring(lastIdx)));
          }
          parent.replaceChild(fragments, textNode);
        }
      }
      
      this.matches = Array.from(document.querySelectorAll('mark.cef-find-match'));
      if (this.matches.length > 0) {
        this.currentIndex = 0;
        this.activateMatch(0);
        return "1/" + this.matches.length;
      }
      return "0/0";
    }
    activateMatch(index) {
      if (this.matches.length === 0) return;
      const active = document.querySelector('mark.cef-find-active');
      if (active) {
        active.classList.remove('cef-find-active');
      }
      const current = this.matches[index];
      if (current) {
        current.classList.add('cef-find-active');
        current.scrollIntoView({ behavior: 'auto', block: 'center' });
      }
    }
    next() {
      if (this.matches.length === 0) return "0/0";
      this.currentIndex = (this.currentIndex + 1) % this.matches.length;
      this.activateMatch(this.currentIndex);
      return (this.currentIndex + 1) + "/" + this.matches.length;
    }
    prev() {
      if (this.matches.length === 0) return "0/0";
      this.currentIndex = (this.currentIndex - 1 + this.matches.length) % this.matches.length;
      this.activateMatch(this.currentIndex);
      return (this.currentIndex + 1) + "/" + this.matches.length;
    }
  }
  window.__cefFindInPage = new CefFindInPage();
})();
''';
