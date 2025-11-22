import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/main_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Intl.defaultLocale = 'vi_VN';
  await initializeDateFormatting('vi_VN');

  //  Khởi tạo notification plugin
  await NotificationService.init();

  //await NotificationService.scheduleTestAfterSeconds(60);
  await NotificationService.scheduleEveryMorning();
 // await NotificationService.scheduleTestInNextMinute();
  runApp(const IntegratedApp());
}

class IntegratedApp extends StatelessWidget {
  const IntegratedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thời khóa biểu',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi', 'VN'),
      ],
      home: const MainScreen(),
    );
  }
}
