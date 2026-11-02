/// The state of a list that one tab loads from the server by id: a feed tab
/// or a notification filter. The items themselves live in MainScreen's
/// single lists; the tab only says which of them belong to it.
class ServerTabState {
  /// Ids of the items in this tab. Null until the first page has arrived.
  final Set<String>? ids;
  final bool loading;
  final String? error;

  const ServerTabState({this.ids, this.loading = false, this.error});
}
