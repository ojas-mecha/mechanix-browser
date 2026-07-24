import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_browser/core/utils/app_theme.dart';
import 'package:mechanix_browser/features/browser/bloc/browser_bloc.dart';
import 'package:mechanix_browser/features/browser/data/models/browser_tab.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/webview_body.dart';
import 'package:webview_cef/webview_cef.dart';

class FakeBrowserBloc extends BrowserBloc {
  final List<BrowserEvent> addedEvents = [];

  FakeBrowserBloc() : super();

  @override
  void add(BrowserEvent event) {
    addedEvents.add(event);
    super.add(event);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bottom Bar Auto Hide Tests', () {
    bool canGoBackResult = false;
    bool canGoForwardResult = false;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('webview_cef'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'create') {
            return [1, 1]; // browserId, textureId
          } else if (methodCall.method == 'canGoBack') {
            return canGoBackResult;
          } else if (methodCall.method == 'canGoForward') {
            return canGoForwardResult;
          }
          return null;
        },
      );
    });

    Future<void> initializeWebviewManager(WidgetTester tester) async {
      final initFuture = WebviewManager().initialize();
      await tester.pump(const Duration(milliseconds: 500));
      await initFuture;
    }

    testWidgets('scroll down beyond threshold -> hides bottom bar',
        (WidgetTester tester) async {
      await initializeWebviewManager(tester);

      final controller = WebviewManager().createWebView();
      final initControllerFuture = controller.initialize('https://example.com');
      await tester.pump(const Duration(milliseconds: 100));
      await initControllerFuture;

      final tab = BrowserTab(
        id: 'tab_1',
        controller: controller,
        currentUrl: 'https://example.com',
        title: 'Example',
        isHomePage: false,
        isLoading: false,
      );

      final fakeBloc = FakeBrowserBloc();
      expect(fakeBloc.state.isBottomBarVisible, true);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: BrowserGestureNavigator(
              tab: tab,
              bloc: fakeBloc,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

      // Perform a drag upward (scroll down) of 50 pixels (beyond 40 threshold)
      final gesture = await tester.startGesture(const Offset(200, 200), pointer: 1, kind: PointerDeviceKind.touch);
      await gesture.moveBy(const Offset(0, -50));
      await gesture.up();

      await tester.pumpAndSettle();

      expect(fakeBloc.addedEvents, contains(const BrowserBottomBarVisibilityChanged(false)));
    });

    testWidgets('scroll up beyond threshold -> shows bottom bar',
        (WidgetTester tester) async {
      await initializeWebviewManager(tester);

      final controller = WebviewManager().createWebView();
      final initControllerFuture = controller.initialize('https://example.com');
      await tester.pump(const Duration(milliseconds: 100));
      await initControllerFuture;

      final tab = BrowserTab(
        id: 'tab_1',
        controller: controller,
        currentUrl: 'https://example.com',
        title: 'Example',
        isHomePage: false,
        isLoading: false,
      );

      final fakeBloc = FakeBrowserBloc();
      fakeBloc.emit(fakeBloc.state.copyWith(isBottomBarVisible: false));
      expect(fakeBloc.state.isBottomBarVisible, false);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: BrowserGestureNavigator(
              tab: tab,
              bloc: fakeBloc,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

      // Perform a drag downward (scroll up) of 50 pixels (beyond 40 threshold)
      final gesture = await tester.startGesture(const Offset(200, 200), pointer: 1, kind: PointerDeviceKind.touch);
      await gesture.moveBy(const Offset(0, 50));
      await gesture.up();

      await tester.pumpAndSettle();

      expect(fakeBloc.addedEvents, contains(const BrowserBottomBarVisibilityChanged(true)));
    });

    testWidgets('tiny vertical movements -> unchanged state',
        (WidgetTester tester) async {
      await initializeWebviewManager(tester);

      final controller = WebviewManager().createWebView();
      final initControllerFuture = controller.initialize('https://example.com');
      await tester.pump(const Duration(milliseconds: 100));
      await initControllerFuture;

      final tab = BrowserTab(
        id: 'tab_1',
        controller: controller,
        currentUrl: 'https://example.com',
        title: 'Example',
        isHomePage: false,
        isLoading: false,
      );

      final fakeBloc = FakeBrowserBloc();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: BrowserGestureNavigator(
              tab: tab,
              bloc: fakeBloc,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

      // Drag up by 15 pixels (less than 40 threshold)
      final gesture = await tester.startGesture(const Offset(200, 200), pointer: 1, kind: PointerDeviceKind.touch);
      await gesture.moveBy(const Offset(0, -15));
      await gesture.up();

      await tester.pumpAndSettle();

      expect(fakeBloc.addedEvents, isNot(contains(isA<BrowserBottomBarVisibilityChanged>())));
    });

    testWidgets('alternating vertical movements (anti-flicker check) -> no changes',
        (WidgetTester tester) async {
      await initializeWebviewManager(tester);

      final controller = WebviewManager().createWebView();
      final initControllerFuture = controller.initialize('https://example.com');
      await tester.pump(const Duration(milliseconds: 100));
      await initControllerFuture;

      final tab = BrowserTab(
        id: 'tab_1',
        controller: controller,
        currentUrl: 'https://example.com',
        title: 'Example',
        isHomePage: false,
        isLoading: false,
      );

      final fakeBloc = FakeBrowserBloc();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: BrowserGestureNavigator(
              tab: tab,
              bloc: fakeBloc,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

      // Drag up by 25 pixels, then down by 25 pixels (alternating)
      final gesture = await tester.startGesture(const Offset(200, 200), pointer: 1, kind: PointerDeviceKind.touch);
      await gesture.moveBy(const Offset(0, -25));
      await gesture.moveBy(const Offset(0, 25));
      await gesture.up();

      await tester.pumpAndSettle();

      expect(fakeBloc.addedEvents, isNot(contains(isA<BrowserBottomBarVisibilityChanged>())));
    });

    testWidgets('horizontal back/forward gestures still work and don\'t trigger vertical scroll actions',
        (WidgetTester tester) async {
      canGoBackResult = true;
      await initializeWebviewManager(tester);

      final controller = WebviewManager().createWebView();
      final initControllerFuture = controller.initialize('https://example.com');
      await tester.pump(const Duration(milliseconds: 100));
      await initControllerFuture;

      final tab = BrowserTab(
        id: 'tab_1',
        controller: controller,
        currentUrl: 'https://example.com',
        title: 'Example',
        isHomePage: false,
        isLoading: false,
      );

      final fakeBloc = FakeBrowserBloc();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: BrowserGestureNavigator(
              tab: tab,
              bloc: fakeBloc,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

      // Perform horizontal swipe right
      final gesture = await tester.startGesture(const Offset(50, 200), pointer: 1, kind: PointerDeviceKind.touch);
      await gesture.moveBy(const Offset(150, 5));
      await gesture.up();

      await tester.pumpAndSettle();

      expect(fakeBloc.addedEvents, contains(isA<BrowserGoBackRequested>()));
      expect(fakeBloc.addedEvents, isNot(contains(isA<BrowserBottomBarVisibilityChanged>())));
    });
  });
}
