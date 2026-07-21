/// Merges a fresh server snapshot of chat messages with the current local
/// list instead of replacing it wholesale.
///
/// A poll/socket-triggered reload that lands while a send is still in
/// flight must never erase the optimistic (`pending`) or `failed` bubble
/// for a message the server doesn't know about yet — an unconditional
/// replace of the message list is what causes a just-sent message to
/// visibly disappear then reappear. Local `pending`/`failed` entries are
/// kept until the server snapshot actually contains their
/// `clientMessageId`; everything else defers to the server as the source
/// of truth.
///
/// Sorted by `createdAt` (server timestamp) ascending, with a stable
/// fallback (original merge order) when timestamps tie or are missing.
List<Map<String, dynamic>> mergeChatMessages({
  required List<Map<String, dynamic>> serverMessages,
  required List<Map<String, dynamic>> localMessages,
}) {
  final serverClientIds = serverMessages
      .map((entry) => (entry["clientMessageId"] ?? "").toString())
      .where((id) => id.isNotEmpty)
      .toSet();

  final stillLocalOnly = localMessages.where((entry) {
    final isLocalState = entry["pending"] == true || entry["failed"] == true;
    if (!isLocalState) return false;
    final clientId = (entry["clientMessageId"] ?? "").toString();
    return clientId.isEmpty || !serverClientIds.contains(clientId);
  });

  final merged = [...serverMessages, ...stillLocalOnly];
  final indexed = List.generate(merged.length, (i) => MapEntry(i, merged[i]));
  indexed.sort((a, b) {
    final aTime = DateTime.tryParse((a.value["createdAt"] ?? "").toString());
    final bTime = DateTime.tryParse((b.value["createdAt"] ?? "").toString());
    if (aTime != null && bTime != null) {
      final cmp = aTime.compareTo(bTime);
      if (cmp != 0) return cmp;
    } else if (aTime != null) {
      return -1;
    } else if (bTime != null) {
      return 1;
    }
    return a.key.compareTo(b.key);
  });
  return indexed.map((entry) => entry.value).toList(growable: false);
}
