import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../tag_colors.dart';
import '../theme.dart';

/// タイムラインの1レコード。寸法はmock/track.html（幅300pxフレーム）の
/// px値 × 1.37 を dp に丸めた値（例: 時刻11→15、スコア円28→38、チップ11→15）。
class TimelineItem extends StatelessWidget {
  const TimelineItem({super.key, required this.record, required this.onLongPress});

  final RecordWithTags record;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final level = ConditionLevel.fromDbValue(record.value);
    // mock準拠の24時間表記（14:20）。ロケール依存の12時間表記だと
    // 「11:08 AM」のように時刻カラム幅を超えて折り返してしまう。
    final time = record.timestamp;
    final timeLabel = '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 19),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 62,
              child: Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(
                  timeLabel,
                  style: const TextStyle(fontSize: 15, color: Color(0xFF667085)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 58),
                    padding: const EdgeInsets.only(left: 16),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Color(0xFFDFE4EE), width: 3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 19,
                              backgroundColor: level.color,
                              child: Text(
                                '${level.uiValue}',
                                style: TextStyle(
                                  // mockでは普通（グレー円）のみ濃色数字、他は白。
                                  color: level == ConditionLevel.normal
                                      ? const Color(0xFF111827)
                                      : Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              level.label,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        if (record.tags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final tag in record.tags) _TagChip(label: tag.name),
                              ],
                            ),
                          ),
                        if (record.comment != null && record.comment!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              record.comment!,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.45,
                                color: Color(0xFF344054),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // mockの.tlbody:before相当。レール（左ボーダー中心 x=1.5）に
                  // ドット中心を重ねる。
                  Positioned(
                    left: -5.5,
                    top: 11,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Color(0xFF9CA3AF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = tagChipColorsFor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(fontSize: 15, color: colors.foreground)),
    );
  }
}
