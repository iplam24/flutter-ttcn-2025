import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

import '../mock/mock_data.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static bool _tzInitialized = false;

  static Future<void> init() async {
    // Khởi tạo timezone 1 lần
    if (!_tzInitialized) {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
      _tzInitialized = true;
    }

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    // 🔔 Xin quyền hiển thị notification
    if (Platform.isAndroid) {
      final androidImpl =
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
    }

    if (Platform.isIOS) {
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await iosImpl?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Build TKB theo buổi trong NGÀY HÔM NAY
  /// [morning] = true  => lấy các tiết bắt đầu trước 12:00
  /// [morning] = false => lấy các tiết bắt đầu từ 12:00 trở đi
  static String? _buildTodaySchedulePart({required bool morning}) {
    final now = DateTime.now();
    final todayStr = DateFormat('d/M/yyyy').format(now);

    final todays =
    demoData.where((item) => item['day'] == todayStr).toList();

    if (todays.isEmpty) return null;

    final filtered = todays.where((s) {
      final startStr = (s['start'] ?? '').toString();
      if (!startStr.contains(':')) return false;
      final hour = int.tryParse(startStr.split(':')[0]) ?? 0;
      if (morning) {
        return hour < 12; // buổi sáng
      } else {
        return hour >= 12; // buổi chiều
      }
    }).toList();

    if (filtered.isEmpty) return null;

    final buffer = StringBuffer();

    for (final s in filtered) {
      final start = s['start'] ?? '';
      final end = s['end'] ?? '';
      final subject = s['subject_name'] ?? '';
      final room = s['room_name'] ?? '';
      final sessionType = s['session_type'] ?? '';

      buffer.writeln('⏰ $start–$end | $subject');
      buffer.writeln('   $sessionType • Phòng $room');
      buffer.writeln('');
    }

    return buffer.toString().trim();
  }

  /// Build toàn bộ TKB hôm nay (cả sáng + chiều) – dùng cho test
  static String? buildTodayScheduleText() {
    final now = DateTime.now();
    final todayStr = DateFormat('d/M/yyyy').format(now);

    final todays =
    demoData.where((item) => item['day'] == todayStr).toList();

    if (todays.isEmpty) return null;

    final buffer = StringBuffer();

    for (final s in todays) {
      final start = s['start'] ?? '';
      final end = s['end'] ?? '';
      final subject = s['subject_name'] ?? '';
      final room = s['room_name'] ?? '';
      final sessionType = s['session_type'] ?? '';

      buffer.writeln('⏰ $start–$end | $subject');
      buffer.writeln('   $sessionType • Phòng $room');
      buffer.writeln('');
    }

    return buffer.toString().trim();
  }

  /// Gửi notification NGAY (dùng text toàn ngày) – chủ yếu để test
  static Future<void> showTodayScheduleNow() async {
    final body = buildTodayScheduleText();
    if (body == null || body.isEmpty) return;

    const androidDetails = AndroidNotificationDetails(
      'timetable_channel',
      'Thời khóa biểu',
      channelDescription: 'Hiển thị toàn bộ thời khóa biểu hôm nay',
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      1,
      'Thời khóa biểu hôm nay',
      body,
      notificationDetails,
    );
  }

  // 🧪 TEST: gửi thông báo sau N giây bằng Future.delayed (không dùng alarm)
  static Future<void> scheduleTestAfterSeconds(int seconds) async {
    final body = buildTodayScheduleText();
    if (body == null || body.isEmpty) {
      print('[NotificationService] Không có TKB hôm nay, không schedule test');
      return;
    }

    print(
        '[NotificationService] Sẽ gửi thông báo TEST sau $seconds giây kể từ bây giờ');

    Future.delayed(Duration(seconds: seconds), () async {
      await showTodayScheduleNow();
    });
  }

  /// 🔔 Lên lịch gửi TKB BUỔI SÁNG lúc 6:00
  static Future<void> scheduleMorningAt6() async {
    final bodyMorning = _buildTodaySchedulePart(morning: true);
    if (bodyMorning == null || bodyMorning.isEmpty) {
      print(
          '[NotificationService] Không có TKB buổi sáng hôm nay, không schedule 6h');
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
    tz.TZDateTime(tz.local, now.year, now.month, now.day, 6, 0);

    // Nếu 6h hôm nay đã qua thì chuyển sang ngày mai
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    print(
        '[NotificationService] Schedule MORNING lúc: $scheduled (6h sáng – buổi sáng)');

    const androidDetails = AndroidNotificationDetails(
      'timetable_channel_morning',
      'Thời khóa biểu buổi sáng',
      channelDescription: 'Thông báo TKB buổi sáng hằng ngày',
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      10, // id riêng cho buổi sáng
      'Thời khóa biểu buổi sáng hôm nay',
      bodyMorning,
      scheduled,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.wallClockTime,
      matchDateTimeComponents: DateTimeComponents.time, // lặp mỗi ngày 6h
    );
  }

  /// 🔔 Lên lịch gửi TKB BUỔI CHIỀU lúc 12:00 trưa
  static Future<void> scheduleAfternoonAt12() async {
    final bodyAfternoon = _buildTodaySchedulePart(morning: false);
    if (bodyAfternoon == null || bodyAfternoon.isEmpty) {
      print(
          '[NotificationService] Không có TKB buổi chiều hôm nay, không schedule 12h');
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
    tz.TZDateTime(tz.local, now.year, now.month, now.day, 12, 0);

    // Nếu 12h hôm nay đã qua thì chuyển sang ngày mai
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    print(
        '[NotificationService] Schedule AFTERNOON lúc: $scheduled (12h trưa – buổi chiều)');

    const androidDetails = AndroidNotificationDetails(
      'timetable_channel_afternoon',
      'Thời khóa biểu buổi chiều',
      channelDescription: 'Thông báo TKB buổi chiều hằng ngày',
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      11, // id riêng cho buổi chiều
      'Thời khóa biểu buổi chiều hôm nay',
      bodyAfternoon,
      scheduled,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.wallClockTime,
      matchDateTimeComponents: DateTimeComponents.time, // lặp mỗi ngày 12h
    );
  }

  /// 📅 Hàm tổng: gọi 1 lần để đăng ký cả 2 lịch (sáng 6h + trưa 12h)
  ///
  /// Trước đây anh dùng scheduleEveryMorning(), giờ em đổi hàm này
  /// thành "đăng ký cả sáng + chiều" luôn cho tiện.
  static Future<void> scheduleEveryMorning() async {
    await scheduleMorningAt6();
    await scheduleAfternoonAt12();
  }
}
