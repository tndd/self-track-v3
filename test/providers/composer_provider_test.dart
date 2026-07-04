import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_track_v3/providers/composer_provider.dart';

void main() {
  late ProviderContainer container;
  late ComposerNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(composerProvider.notifier);
  });

  tearDown(() => container.dispose());

  group('collapse', () {
    test('新規作成の下書き（タグ・体調）は保持してパネルだけを畳む', () {
      notifier.expand();
      notifier.selectCondition(5);
      notifier.toggleTag('t1');

      notifier.collapse();

      final state = container.read(composerProvider);
      expect(state.isExpanded, isFalse);
      expect(state.conditionUiValue, 5);
      expect(state.selectedTagIds, {'t1'});
    });

    test('編集中は編集状態ごと破棄して初期状態に戻す', () {
      notifier.startEditing(
        recordId: 'r1',
        timestamp: DateTime(2026, 6, 29, 12),
        conditionUiValue: 2,
        tagIds: {'t1'},
      );

      notifier.collapse();

      final state = container.read(composerProvider);
      expect(state.isEditing, isFalse);
      expect(state.editingRecordId, isNull);
      expect(state.selectedTagIds, isEmpty);
      expect(state.conditionUiValue, 3);
    });
  });

  group('onRecordDeleted', () {
    test('編集中のレコードが削除されたら編集状態を破棄する', () {
      notifier.startEditing(
        recordId: 'r1',
        timestamp: DateTime(2026, 6, 29, 12),
        conditionUiValue: 4,
        tagIds: {'t1'},
      );

      notifier.onRecordDeleted('r1');

      final state = container.read(composerProvider);
      expect(state.isEditing, isFalse);
      expect(state.selectedTagIds, isEmpty);
    });

    test('別レコードの削除では編集状態を維持する', () {
      notifier.startEditing(
        recordId: 'r1',
        timestamp: DateTime(2026, 6, 29, 12),
        conditionUiValue: 4,
        tagIds: {'t1'},
      );

      notifier.onRecordDeleted('other');

      final state = container.read(composerProvider);
      expect(state.editingRecordId, 'r1');
      expect(state.selectedTagIds, {'t1'});
    });

    test('編集中でなければ何もしない（下書きを消さない）', () {
      notifier.toggleTag('t1');

      notifier.onRecordDeleted('r1');

      expect(container.read(composerProvider).selectedTagIds, {'t1'});
    });
  });
}
