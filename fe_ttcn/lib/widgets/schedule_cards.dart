// lib/widgets/schedule_cards.dart
import 'package:flutter/material.dart';

/// Card hiển thị lịch kiểu “đại học” (có start/end, tiết, phòng, giảng viên…)
class UniScheduleCard extends StatelessWidget {
  final Map<String, dynamic> map;
  const UniScheduleCard(this.map, {super.key});

  String _safe(Map m, String k) => (m[k] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final subject = _safe(map, 'subject_name');
    final sessionType = _safe(map, 'session_type');
    final group = _safe(map, 'group');
    final room = _safe(map, 'room_name');
    final roomDesc = _safe(map, 'room_desc');
    final start = _safe(map, 'start');
    final end = _safe(map, 'end');
    final pf = map['period_from']?.toString() ?? '';
    final pt = map['period_to']?.toString() ?? '';
    final lecturer = _safe(map, 'lecturer');
    final code = _safe(map, 'course_code');
    final clazz = _safe(map, 'class_name');

    final color = Theme.of(context).colorScheme;
    final chipBg = color.primaryContainer;
    final chipFg = color.onPrimaryContainer;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: thời gian + tiết
            Row(
              children: [
                Icon(Icons.schedule, size: 18, color: color.primary),
                const SizedBox(width: 8),
                Text('$start – $end',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('Tiết $pf → $pt',
                      style:
                      TextStyle(fontSize: 12, color: chipFg, height: 1.1)),
                ),
                const Spacer(),
                if (sessionType.isNotEmpty)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(sessionType,
                        style: TextStyle(
                            fontSize: 12,
                            color: color.onSecondaryContainer,
                            height: 1.1)),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Tên môn
            Text(
              subject.isEmpty ? '(Không rõ môn)' : subject,
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),

            // Dòng thông tin phụ
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                if (group.isNotEmpty && group != '-')
                  IconText(icon: Icons.group, text: group),
                if (code.isNotEmpty) IconText(icon: Icons.qr_code, text: code),
                if (clazz.isNotEmpty)
                  IconText(icon: Icons.class_, text: clazz),
              ],
            ),
            const SizedBox(height: 8),

            // Phòng học
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    roomDesc.isNotEmpty ? '$room • $roomDesc' : room,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Giảng viên
            if (lecturer.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(lecturer)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Card đơn giản fallback khi payload không theo cấu trúc lịch đại học
class SimpleCard extends StatelessWidget {
  final Map<String, dynamic> map;
  const SimpleCard(this.map, {super.key});

  @override
  Widget build(BuildContext context) {
    final keys = map.keys.toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mục lịch',
                style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...keys.map((k) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                      width: 120,
                      child: Text(
                        '$k:',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      )),
                  Expanded(child: Text('${map[k]}')),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

/// Tiện ích nhỏ: icon + text gọn gàng
class IconText extends StatelessWidget {
  final IconData icon;
  final String text;
  const IconText({required this.icon, required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }
}