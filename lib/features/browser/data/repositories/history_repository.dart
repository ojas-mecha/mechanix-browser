import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mechanix_browser/core/utils/constants.dart';
import 'package:mechanix_browser/features/browser/data/models/browser_history.dart';
import 'package:mechanix_browser/objectbox.g.dart';

class HistoryRepository {
  final Store store;
  late final Box<BrowserHistory> historyBox;

  HistoryRepository._(this.store) {
    historyBox = store.box<BrowserHistory>();
  }

  static Future<HistoryRepository> create() async {
    try {
      final home = Platform.environment['HOME'];

      if (home == null || home.isEmpty) {
        throw Exception('HOME environment variable is not set');
      }

      final storeDir = Directory('$home/${AppConstants.dbPath}');

      if (!await storeDir.exists()) {
        await storeDir.create(recursive: true);
      }

      final store = await openStore(directory: storeDir.path);

      return HistoryRepository._(store);
    } catch (e, stackTrace) {
      debugPrint('Unable to initialize history storage: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  List<BrowserHistory> getHistory() {
    try {
      final query =
          (historyBox.query()
                ..order(BrowserHistory_.timestamp, flags: Order.descending))
              .build();
      final results = query.find();
      query.close();
      return results;
    } catch (e, stackTrace) {
      debugPrint('Unable to load history: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  void saveHistory(BrowserHistory history) {
    // try {
    //   historyBox.put(history);
    // } catch (e, stackTrace) {
    //   debugPrint('Unable to save history: $e');
    //   debugPrint(stackTrace.toString());
    //   rethrow;
    // }
  }

  void clearHistory() {
    // try {
    //   historyBox.removeAll();
    // } catch (e, stackTrace) {
    //   debugPrint('Unable to clear history: $e');
    //   debugPrint(stackTrace.toString());
    //   rethrow;
    // }
  }

  Future<void> seedIfEmpty() async {
    try {
      if (historyBox.isEmpty()) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final seeds = [
          BrowserHistory(
            url: 'https://www.google.com/search?q=gesture+navigation',
            title: 'gesture navigation',
            timestamp: now - 13000,
          ),
          BrowserHistory(
            url: 'https://www.google.com/search?q=monkeytype+speed+test',
            title: 'monkeytype speed test',
            timestamp: now - 12000,
          ),
          BrowserHistory(
            url: 'https://www.google.com/search?q=foss+handbook',
            title: 'foss handbook',
            timestamp: now - 11000,
          ),
          BrowserHistory(
            url: 'https://www.google.com/search?q=Example+recent+search',
            title: 'Example recent search',
            timestamp: now - 10000,
          ),
          BrowserHistory(
            url:
                'https://www.google.com/search?q=How+to+make+a+startup+from+scratch',
            title: 'How to make a startup from scratch',
            timestamp: now - 9000,
          ),
          BrowserHistory(url: '', title: 'comet.design', timestamp: now - 8000),
          BrowserHistory(
            url: 'https://monkeytype.com',
            title: 'monkeytype.com',
            timestamp: now - 7000,
          ),
          BrowserHistory(url: '', title: '', timestamp: now - 6000),
          BrowserHistory(url: '', title: 'archlinux', timestamp: now - 5000),
          BrowserHistory(
            url: 'https://news.ycombinator.com',
            title: 'news.ycombinator.com',
            timestamp: now - 4000,
          ),
          BrowserHistory(
            url: 'https://www.google.com/search?q=handheld+ux+patterns',
            title: 'handheld ux patterns',
            timestamp: now - 3000,
          ),
          BrowserHistory(
            url: 'https://www.google.com/search?q=mechanical+keyboard+reviews',
            title: 'mechanical keyboard reviews',
            timestamp: now - 2000,
          ),
          BrowserHistory(
            url: 'https://www.google.com/search?q=linux+ricing+guide',
            title: 'linux ricing guide',
            timestamp: now - 1000,
          ),
        ];
        historyBox.putMany(seeds);
      }
    } catch (e, stackTrace) {
      debugPrint('Unable to seed history database: $e');
      debugPrint(stackTrace.toString());
    }
  }

  List<BrowserHistory> searchHistory(String queryText) {
    try {
      if (queryText.trim().isEmpty) return [];
      final query = (historyBox.query(
        BrowserHistory_.title
            .contains(queryText, caseSensitive: false)
            .or(BrowserHistory_.url.contains(queryText, caseSensitive: false)),
      )..order(BrowserHistory_.timestamp, flags: Order.descending)).build();
      final results = query.find();
      query.close();
      return results;
    } catch (e, stackTrace) {
      debugPrint('Unable to search history: $e');
      debugPrint(stackTrace.toString());
      return [];
    }
  }

  void close() {
    store.close();
  }
}
