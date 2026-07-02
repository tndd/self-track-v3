import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../theme.dart';

class TimelineItem extends StatelessWidget {
  const TimelineItem({super.key, required this.record, required this.onLongPress});

  final RecordWithTags record;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final level = ConditionLevel.fromDbValue(record.value);
    final timeLabel = TimeOfDay.fromDateTime(record.timestamp).format(context);

    return InkWell(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 46,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  timeLabel,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: Colors.grey.shade300, width: 2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: level.color,
                          child: Text(
                            '${level.uiValue}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(level.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (record.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final tag in record.tags) _TagChip(label: tag.name),
                          ],
                        ),
                      ),
                    if (record.comment != null && record.comment!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(record.comment!, style: const TextStyle(fontSize: 13)),
                      ),
                  ],
                ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF3446A8))),
    );
  }
}
