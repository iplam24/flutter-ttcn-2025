// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'todo_list_page.dart';
import 'voice_ask_page.dart';
import '../services/notification_service.dart';
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  @override
  void initState() {
    super.initState();
    // Khi vào màn hình chính, hiện luôn thông báo thời khóa biểu hôm nay
    //NotificationService.showTodayScheduleNow();

    // Nếu anh muốn: chỉ cần bật 1 lần, sau đó mỗi ngày 6h sẽ tự hiện
     NotificationService.scheduleEveryMorning();
  }
  // Danh sách các trang đã được tách ra
  static const List<Widget> _pages = <Widget>[
    TodoListPage(),
    VoiceAskPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'To-Do List',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mic),
            label: 'Voice Ask',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}