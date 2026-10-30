import 'package:flutter_learning/models/post.dart';

/// Returns the posts whose content or author name contains [query].
///
/// The query is trimmed and matching ignores letter case. An empty or
/// spaces-only query returns every post. [posts] is never modified; a new
/// list is always returned, in the same order.
List<Post> searchPosts(List<Post> posts, String query) {
  final normalizedQuery = query.trim().toLowerCase();
  return posts.where((post) {
    if (normalizedQuery.isEmpty) return true;
    return post.content.toLowerCase().contains(normalizedQuery) ||
        post.author.name.toLowerCase().contains(normalizedQuery);
  }).toList();
}
