import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Track画面の記録入力フォーム（Composer）のUI状態。
/// design.md §5.1のパネル（体調5段階 + タグ選択 + コメント）に対応する。
class ComposerState {
  const ComposerState({
    this.isExpanded = false,
    this.isTagZoneOpen = false,
    this.conditionUiValue = 3,
    this.selectedTagIds = const {},
    this.editingRecordId,
    this.editingTimestamp,
  });

  /// パネル（Status/コメント欄を含むカード）が展開されているか。
  final bool isExpanded;

  /// タグ選択エリアがアコーディオン展開されているか。
  final bool isTagZoneOpen;

  /// 体調値。UI表示は1〜5、デフォルトは3（普通）。DB保存時は-2〜2に変換する。
  final int conditionUiValue;

  final Set<String> selectedTagIds;

  /// nullなら新規作成、非nullなら該当レコードの編集中。
  final String? editingRecordId;

  /// 編集中レコードの元のtimestamp。新規作成時は送信時にDateTime.now()を使う。
  final DateTime? editingTimestamp;

  bool get isEditing => editingRecordId != null;

  ComposerState copyWith({
    bool? isExpanded,
    bool? isTagZoneOpen,
    int? conditionUiValue,
    Set<String>? selectedTagIds,
  }) {
    return ComposerState(
      isExpanded: isExpanded ?? this.isExpanded,
      isTagZoneOpen: isTagZoneOpen ?? this.isTagZoneOpen,
      conditionUiValue: conditionUiValue ?? this.conditionUiValue,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      editingRecordId: editingRecordId,
      editingTimestamp: editingTimestamp,
    );
  }
}

class ComposerNotifier extends Notifier<ComposerState> {
  @override
  ComposerState build() => const ComposerState();

  void expand() {
    if (!state.isExpanded) state = state.copyWith(isExpanded: true);
  }

  void toggleTagZone() {
    state = state.copyWith(isTagZoneOpen: !state.isTagZoneOpen);
  }

  /// パネル外タップ（scrim）で閉じる。
  ///
  /// 新規作成の下書き（選択済みタグ・体調）は保持してパネルだけを畳むが、
  /// 編集中だった場合は編集を破棄して初期状態に戻す。編集状態を残したまま
  /// 畳むと「編集中」バナーが見えないまま送信ボタンが押せてしまい、
  /// 新規作成のつもりの送信が過去レコードを黙って上書きするため。
  void collapse() {
    if (state.isEditing) {
      state = const ComposerState();
    } else if (state.isExpanded || state.isTagZoneOpen) {
      state = state.copyWith(isExpanded: false, isTagZoneOpen: false);
    }
  }

  /// 編集中のレコードが削除された時に呼ぶ。該当レコードを編集中で
  /// なければ何もしない。宙に浮いた編集状態からの送信は、存在しない
  /// レコードへのタグ紐付けINSERT（外部キー違反）になるため。
  void onRecordDeleted(String recordId) {
    if (state.editingRecordId == recordId) {
      state = const ComposerState();
    }
  }

  void selectCondition(int uiValue) {
    state = state.copyWith(conditionUiValue: uiValue);
  }

  void toggleTag(String tagId) {
    final next = {...state.selectedTagIds};
    if (!next.remove(tagId)) {
      next.add(tagId);
    }
    state = state.copyWith(selectedTagIds: next);
  }

  /// 長押し編集メニューからComposerを既存レコードの内容で開く。
  void startEditing({
    required String recordId,
    required DateTime timestamp,
    required int conditionUiValue,
    required Set<String> tagIds,
  }) {
    state = ComposerState(
      isExpanded: true,
      conditionUiValue: conditionUiValue,
      selectedTagIds: tagIds,
      editingRecordId: recordId,
      editingTimestamp: timestamp,
    );
  }

  /// 送信後・キャンセル後に初期状態へ戻す。
  void reset() {
    state = const ComposerState();
  }
}

final composerProvider = NotifierProvider<ComposerNotifier, ComposerState>(
  ComposerNotifier.new,
);
