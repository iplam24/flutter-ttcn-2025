// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui'; // Import cho BackdropFilter

import 'voice_ask_page.dart';
import 'calendar_screen.dart';
import 'todo_screen.dart';
import '../database/database_helper.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;

  late final AnimationController _fabAnimationController;
  late final Animation<double> _fabScaleAnimation;

  @override
  void initState() {
    super.initState();
    NotificationService.scheduleEveryMorning();

    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeOutBack),
    );
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  static final List<Widget> _pages = <Widget>[
    const _HomeTab(),
    const CalendarScreen(),
    const ToDoScreen(),
    const VoiceAskPage(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _fabAnimationController.forward(from: 0.0);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await DatabaseHelper.instance.clearSchedule();

    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _openSettings() {
    _logout();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF1A5F3F);
    const Color accentGreen = Color(0xFF2E7D62);

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryGreen, accentGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        titleSpacing: 0,

        title: const Row(
          children: [
            // Logo
            Padding(
              padding: EdgeInsets.only(left: 16, right: 12),
              child: Icon(Icons.school_rounded, color: Colors.white, size: 30),
            ),
            Text(
                'VNUA Schedule',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)
            ),
          ],
        ),

        centerTitle: false,
        elevation: 10,
        shadowColor: Colors.black26,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Cài đặt',
            onPressed: _openSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),

      // === BOTTOM NAVIGATION BAR CẢI TIẾN ===
      bottomNavigationBar: Container(
        margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 15), // Giảm margin ngang, cân đối dọc
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 25, offset: const Offset(0, 10)), // Shadow mạnh hơn
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(

            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              // Tăng cường độ tương phản cho nền
              backgroundColor: Colors.white.withOpacity(0.95),
              selectedItemColor: primaryGreen,
              unselectedItemColor: Colors.grey.shade600,
              // Tăng kích thước phông
              selectedFontSize: 13,
              unselectedFontSize: 11,
              elevation: 0,
              items: const [
                // === THAY ĐỔI: THÊM PADDING VÀO ICON ===
                BottomNavigationBarItem(
                    icon: Padding(
                      padding: EdgeInsets.only(top: 10, bottom: 4.0), // Padding trên/dưới
                      child: Icon(Icons.home_rounded, size: 28),
                    ),
                    label: 'Trang chủ'
                ),
                BottomNavigationBarItem(
                    icon: Padding(
                      padding: EdgeInsets.only(top: 10, bottom: 4.0),
                      child: Icon(Icons.calendar_month_rounded, size: 28),
                    ),
                    label: 'Lịch học'
                ),
                BottomNavigationBarItem(
                    icon: Padding(
                      padding: EdgeInsets.only(top: 10, bottom: 4.0),
                      child: Icon(Icons.checklist_rounded, size: 28),
                    ),
                    label: 'Việc làm'
                ),
                BottomNavigationBarItem(
                    icon: Padding(
                      padding: EdgeInsets.only(top: 10, bottom: 4.0),
                      child: Icon(Icons.mic_rounded, size: 28),
                    ),
                    label: 'Hỏi nhanh'
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// TRANG CHỦ ĐẸP NHƯ APP CAO CẤP (Giữ nguyên)
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  void _navigateToTab(BuildContext context, int index) {
    context.findAncestorStateOfType<_MainScreenState>()?._onItemTapped(index);
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF1A5F3F);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8F5E8), Colors.white],
          stops: [0.0, 0.4],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),

            // Card chào mừng
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [primaryGreen, Color(0xFF2E7D62)]),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.school_rounded, size: 80, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    'Chào mừng trở lại!',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Học viện Nông nghiệp Việt Nam',
                    style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.9)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Hôm nay bạn có việc gì cần làm?\nDùng menu dưới để quản lý thời gian hiệu quả!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.85)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Các nút nhanh
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _quickActionButton(
                  context,
                  icon: Icons.calendar_today_rounded,
                  label: "Xem lịch",
                  color: primaryGreen,
                  onTap: () => _navigateToTab(context, 1),
                ),
                _quickActionButton(
                  context,
                  icon: Icons.add_task_rounded,
                  label: "Thêm việc",
                  color: Colors.orange,
                  onTap: () => _navigateToTab(context, 2),
                ),
                _quickActionButton(
                  context,
                  icon: Icons.mic_rounded,
                  label: "Hỏi nhanh",
                  color: Colors.blue.shade700!,
                  onTap: () => _navigateToTab(context, 3),
                ),
              ],
            ),

            const SizedBox(height: 40),

            ElevatedButton.icon(
              onPressed: () => NotificationService.showTestScheduleNotification(),
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text("Test thông báo ngay"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionButton(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}