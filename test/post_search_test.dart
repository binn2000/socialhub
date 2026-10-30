import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/data/mock_data.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/utils/post_search.dart';

// The shared matching rule used by both Home and Explore search.
void main() {
  final hello = Post(
    id: 'hello',
    author: mockUsers[1], // Minh Ánh
    content: 'Hello everyone',
    createdAt: 'Vừa xong',
    likes: 0,
    comments: 0,
    shares: 0,
    isLiked: false,
  );
  final coffee = Post(
    id: 'coffee',
    author: mockUsers[2], // Duy Khang
    content: 'Cà phê sáng',
    createdAt: 'Vừa xong',
    likes: 0,
    comments: 0,
    shares: 0,
    isLiked: false,
  );
  final posts = [hello, coffee];

  List<String> ids(List<Post> result) => result.map((p) => p.id).toList();

  test('matches content, ignoring case and surrounding spaces', () {
    expect(ids(searchPosts(posts, 'hello')), ['hello']);
    expect(ids(searchPosts(posts, '  HELLO  ')), ['hello']);
    expect(ids(searchPosts(posts, 'every')), ['hello']);
  });

  test('matches the author name', () {
    expect(ids(searchPosts(posts, 'minh')), ['hello']);
    expect(ids(searchPosts(posts, 'duy kh')), ['coffee']);
  });

  test('empty or spaces-only query returns every post in order', () {
    expect(ids(searchPosts(posts, '')), ['hello', 'coffee']);
    expect(ids(searchPosts(posts, '   ')), ['hello', 'coffee']);
  });

  test('no match returns an empty list', () {
    expect(searchPosts(posts, 'zzz'), isEmpty);
  });

  test('returns a new list and leaves the input unchanged', () {
    final result = searchPosts(posts, '');
    expect(result, isNot(same(posts)));

    result.clear();
    expect(ids(posts), ['hello', 'coffee']);
  });
}
