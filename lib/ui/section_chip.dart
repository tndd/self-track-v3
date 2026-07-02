import 'package:flutter/material.dart';

/// mock/calendar.htmlの.sectionChip（コンテンツを幅いっぱいの灰色タイトル
/// バーで区切るルール）の共通実装。CalendarのセクションタイトルとTrackの
/// 日付区切りで共用し、画面間の世界観を統一する。
/// 寸法はモックのpx × 1.37ベース（縦paddingは目立ちすぎないよう控えめ）。
class SectionChip extends StatelessWidget {
  const SectionChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: Color(0xFF334155),
        ),
      ),
    );
  }
}
