import 'package:flutter_test/flutter_test.dart';
import 'package:hello/utils/chat_message_merge.dart';

void main() {
  group('mergeChatMessages', () {
    test('keeps a pending optimistic message the server does not know about yet', () {
      final local = [
        {
          'id': 'temp_1',
          'clientMessageId': 'client-abc',
          'message': 'hello',
          'pending': true,
          'failed': false,
          'createdAt': '2026-01-01T10:00:05.000Z',
        },
      ];

      // Simulates a poll landing before the POST has committed server-side —
      // the server snapshot does not contain this message yet.
      final merged = mergeChatMessages(serverMessages: const [], localMessages: local);

      expect(merged, hasLength(1));
      expect(merged.first['pending'], true);
      expect(merged.first['id'], 'temp_1');
    });

    test('replaces the pending entry with the server version once acknowledged', () {
      final local = [
        {
          'id': 'temp_1',
          'clientMessageId': 'client-abc',
          'message': 'hello',
          'pending': true,
          'failed': false,
          'createdAt': '2026-01-01T10:00:05.000Z',
        },
      ];
      final server = [
        {
          'id': 'server-real-id',
          'clientMessageId': 'client-abc',
          'message': 'hello',
          'senderRole': 'patient',
          'createdAt': '2026-01-01T10:00:05.000Z',
        },
      ];

      final merged = mergeChatMessages(serverMessages: server, localMessages: local);

      // The server's row wins — no duplicate, no leftover pending entry.
      expect(merged, hasLength(1));
      expect(merged.first['id'], 'server-real-id');
      expect(merged.first.containsKey('pending'), false);
    });

    test('never produces a duplicate when both a pending local entry and its server row are present', () {
      final local = [
        {
          'id': 'existing-server-id',
          'clientMessageId': 'client-existing',
          'message': 'earlier message',
          'createdAt': '2026-01-01T09:00:00.000Z',
        },
        {
          'id': 'temp_2',
          'clientMessageId': 'client-new',
          'message': 'new message',
          'pending': true,
          'failed': false,
          'createdAt': '2026-01-01T10:00:00.000Z',
        },
      ];
      final server = [
        {
          'id': 'existing-server-id',
          'clientMessageId': 'client-existing',
          'message': 'earlier message',
          'createdAt': '2026-01-01T09:00:00.000Z',
        },
      ];

      final merged = mergeChatMessages(serverMessages: server, localMessages: local);

      expect(merged, hasLength(2));
      expect(merged.map((m) => m['id']), containsAll(['existing-server-id', 'temp_2']));
    });

    test('keeps a failed message visible until retried/removed by the caller', () {
      final local = [
        {
          'id': 'temp_3',
          'clientMessageId': 'client-failed',
          'message': 'oops',
          'pending': false,
          'failed': true,
          'createdAt': '2026-01-01T11:00:00.000Z',
        },
      ];

      final merged = mergeChatMessages(serverMessages: const [], localMessages: local);

      expect(merged, hasLength(1));
      expect(merged.first['failed'], true);
    });

    test('drops a stale local entry once the server snapshot supersedes it', () {
      final local = [
        {
          'id': 'temp_4',
          'clientMessageId': 'client-4',
          'message': 'now confirmed',
          'pending': true,
          'failed': false,
          'createdAt': '2026-01-01T12:00:00.000Z',
        },
      ];
      final server = [
        {
          'id': 'server-4',
          'clientMessageId': 'client-4',
          'message': 'now confirmed',
          'createdAt': '2026-01-01T12:00:00.000Z',
        },
      ];

      final merged = mergeChatMessages(serverMessages: server, localMessages: local);

      expect(merged, hasLength(1));
      expect(merged.first['id'], 'server-4');
    });

    test('sorts by createdAt ascending with stable order for equal/unparsable timestamps', () {
      final server = [
        {'id': 'b', 'message': 'second', 'createdAt': '2026-01-01T10:00:02.000Z'},
        {'id': 'a', 'message': 'first', 'createdAt': '2026-01-01T10:00:01.000Z'},
      ];

      final merged = mergeChatMessages(serverMessages: server, localMessages: const []);

      expect(merged.map((m) => m['id']).toList(), ['a', 'b']);
    });

    test('appends local-only messages after server messages when timestamps are missing', () {
      final local = [
        {
          'id': 'temp_5',
          'clientMessageId': 'client-5',
          'message': 'brand new',
          'pending': true,
          'failed': false,
          'createdAt': '',
        },
      ];
      final server = [
        {'id': 'server-old', 'message': 'old', 'createdAt': '2026-01-01T09:00:00.000Z'},
      ];

      final merged = mergeChatMessages(serverMessages: server, localMessages: local);

      expect(merged.map((m) => m['id']).toList(), ['server-old', 'temp_5']);
    });
  });
}
