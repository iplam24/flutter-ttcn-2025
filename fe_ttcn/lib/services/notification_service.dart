// lib/services/notification_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../model/schedule_item.dart';

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notifications.initialize(settings);
  }

  static Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Channel',
      channelDescription: 'Kênh dùng để kiểm tra thông báo',
      importance: Importance.max,
      priority: Priority.high,
    );
    await _notifications.show(
      999,
      'Test OK!',
      'Thông báo chạy ngon lành từ app!',
      const NotificationDetails(android: androidDetails),
    );
  }

  // --- HÀM HỖ TRỢ XÂY DỰNG NỘI DUNG TKB ---
  static Future<Map<String, String>> _buildScheduleContent(DateTime dayToNotify) async {
    final schedule = await DatabaseHelper.instance.getScheduleForDay(dayToNotify);

    String title;
    String body;

    if (dayToNotify.weekday == DateTime.sunday || schedule.isEmpty) {
      title = 'Hôm nay không có lịch học!';
      body = 'Hãy dành thời gian làm To-Do hoặc nghỉ ngơi nhé.';
    } else {
      final dayOfWeek = DateFormat('EEEE', 'vi_VN').format(dayToNotify);
      final date = DateFormat('dd/MM', 'vi_VN').format(dayToNotify);
      title = '$dayOfWeek, $date: Bạn có ${schedule.length} môn học';

      final subjectDetails = schedule.map((s) =>
      '• ${s.tenMon} (Tiết ${s.tietHoc}, P. ${s.phong})'
      ).join('\n');

      body = 'Chi tiết:\n$subjectDetails';
    }

    return {'title': title, 'body': body};
  }

  // === HÀM TEST MỚI: HIỂN THỊ TKB NGAY LẬP TỨC CHO NGÀY HÔM NAY ===
  static Future<void> showTestScheduleNotification() async {
    final today = DateTime.now();
    final content = await _buildScheduleContent(today);

    final androidDetails = AndroidNotificationDetails(
      'test_schedule_channel',
      'Test TKB Ngay lập tức',
      channelDescription: 'Test nội dung TKB',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(content['body']!),
    );

    await _notifications.show(
      1000, // ID test riêng
      'TEST TKB: ${content['title']}',
      content['body'],
      NotificationDetails(android: androidDetails),
    );
  }

  // --- HÀM LÊN LỊCH CHÍNH (6h Sáng và 12h Trưa) ---
  static Future<void> scheduleDailyReminders() async {
    const notifications = [
      {'id': 0, 'hour': 6, 'name': 'Sáng'},
      {'id': 1, 'hour': 12, 'name': 'Trưa'},
    ];

    await _notifications.cancel(0);
    await _notifications.cancel(1);

    for (var config in notifications) {
      final notificationId = config['id'] as int;
      final hour = config['hour'] as int;
      final name = config['name'] as String;

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        0,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final dayToNotify = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
      final content = await _buildScheduleContent(dayToNotify);

      final androidDetails = AndroidNotificationDetails(
        'schedule_daily_channel_$notificationId',
        'Thông báo TKB $name',
        channelDescription: 'Thông báo TKB vào $hour:00 hàng ngày',
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(content['body']!),
      );

      final platformDetails = NotificationDetails(android: androidDetails);

      await _notifications.zonedSchedule(
        notificationId,
        content['title'],
        content['body'],
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.inexact,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      debugPrint('Scheduled ${name} reminder for ${DateFormat('dd/MM/yyyy HH:mm').format(scheduledDate)} daily (ID $notificationId).');
    }
  }

  static Future<void> scheduleEveryMorning() async {
    return scheduleDailyReminders();
  }
}