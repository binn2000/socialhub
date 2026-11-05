import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/widgets/bottom_nav.dart';
import 'package:flutter_learning/models/youtube_video.dart';
import 'package:flutter_learning/screens/explore_screen.dart';
import 'package:flutter_learning/services/social_api.dart';

import 'test_helpers.dart';

YoutubeVideo _video(String id, String title, {int? seconds}) => YoutubeVideo(
  id: id,
  title: title,
  channelTitle: 'Kênh $title',
  durationSeconds: seconds,
);

void main() {
  test('video ids and durations', () {
    expect(YoutubeVideo.isValidId('dQw4w9WgXcQ'), isTrue);
    expect(YoutubeVideo.isValidId('dQw4w9WgXc'), isFalse);
    expect(YoutubeVideo.isValidId('dQw4w9WgXc"'), isFalse);
    expect(_video('aaaaaaaaaaa', 'a', seconds: 3723).durationLabel, '1:02:03');
    expect(_video('aaaaaaaaaaa', 'a', seconds: 75).durationLabel, '1:15');
    expect(_video('aaaaaaaaaaa', 'a').durationLabel, '');
  });

  testWidgets('the mock app has no Video tab in Explore', (tester) async {
    await pumpSocialHub(tester);
    await tapTab(tester, AppTab.explore);
    expect(find.text('Video'), findsNothing);
  });

  group('Explore with a server', () {
    late List<String> searches;
    late List<YoutubeVideo> played;

    Future<void> pumpExplore(
      WidgetTester tester, {
      Future<VideoPage> Function(String, String?)? search,
    }) async {
      searches = [];
      played = [];
      await tester.pumpWidget(
        MaterialApp(
          home: ExploreScreen(
            posts: const [],
            onPlayVideo: played.add,
            searchVideos:
                search ??
                (query, cursor) async {
                  searches.add('$query|${cursor ?? '-'}');
                  if (cursor == 'p2') {
                    return VideoPage(
                      videos: [_video('bbbbbbbbbbb', 'Trang hai')],
                    );
                  }
                  return VideoPage(
                    videos: [
                      _video(
                        'aaaaaaaaaaa',
                        query.isEmpty ? 'Thịnh hành' : 'Kết quả $query',
                        seconds: 75,
                      ),
                    ],
                    nextCursor: 'p2',
                  );
                },
          ),
        ),
      );
    }

    testWidgets('lists the popular videos, searches and plays', (tester) async {
      // A phone-sized screen: the 16:9 thumbnails are tall on 800x600.
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpExplore(tester);
      await tester.tap(find.text('Video'));
      await tester.pumpAndSettle();

      expect(searches, ['|-']);
      expect(find.text('Thịnh hành'), findsOneWidget);
      expect(find.text('1:15'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'nhạc');
      // The search waits for the typing to pause.
      await tester.pump(const Duration(milliseconds: 300));
      expect(searches, ['|-']);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(searches, ['|-', 'nhạc|-']);
      expect(find.text('Kết quả nhạc'), findsOneWidget);

      await tester.tap(find.text('Kết quả nhạc'));
      expect(played.single.id, 'aaaaaaaaaaa');
    });

    testWidgets('scrolling to the end loads the next page', (tester) async {
      await pumpExplore(tester);
      await tester.tap(find.text('Video'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(searches, ['|-', '|p2']);
      expect(find.text('Trang hai'), findsOneWidget);
    });

    testWidgets('a refused search says so and can be retried', (tester) async {
      var attempts = 0;
      await pumpExplore(
        tester,
        search: (query, cursor) async {
          attempts++;
          if (attempts == 1) {
            throw const ApiException(
              statusCode: 503,
              code: 'video_unavailable',
              message: 'x',
            );
          }
          return VideoPage(videos: [_video('aaaaaaaaaaa', 'Đã được')]);
        },
      );
      await tester.tap(find.text('Video'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hiện chưa tìm được video'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Đã được'), findsOneWidget);
    });
  });
}
