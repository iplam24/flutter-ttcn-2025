// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../database/database_helper.dart';
import '../model/schedule_item.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _checkLogin();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.7, curve: Curves.easeOut)),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.3, 1.0, curve: Curves.elasticOut)),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ================== LOGIC GIỮ NGUYÊN ==================
  static List<ScheduleItem> _flattenScheduleJson(Map<String, dynamic> responseData, String mssv) {
    final List<ScheduleItem> finalSchedule = [];
    final timeableList = responseData['timeableList'] as List<dynamic>?;
    if (timeableList == null) return finalSchedule;

    for (final weekData in timeableList) {
      final weekMap = weekData as Map<String, dynamic>;
      final weekInTerm = weekMap['week_in_term'] as int?;
      final listInWeek = weekMap['timeable_list_in_week_list'] as List<dynamic>?;

      if (listInWeek == null || weekInTerm == null) continue;

      for (final lesson in listInWeek) {
        final lessonMap = lesson as Map<String, dynamic>;
        lessonMap['week_in_term'] = weekInTerm;
        lessonMap['mssv'] = mssv;

        try {
          finalSchedule.add(ScheduleItem.fromJson(lessonMap));
        } catch (e) {
          if (kDebugMode) debugPrint('Error parsing lesson: $e');
        }
      }
    }
    return finalSchedule;
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final lastLoginMillis = prefs.getInt('last_login_at');
    final token = prefs.getString('access_token');

    if (lastLoginMillis == null || token == null) return;

    final lastLogin = DateTime.fromMillisecondsSinceEpoch(lastLoginMillis);
    final diff = DateTime.now().difference(lastLogin);

    if (diff.inDays < 3) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
      await prefs.clear(); // Xóa hết cho chắc
    }
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập đầy đủ thông tin');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse(AppConfig.loginEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        final userData = jsonResponse['data'] as Map<String, dynamic>;
        final accessToken = userData['token'] as String?;

        if (accessToken == null || accessToken.isEmpty) {
          setState(() => _errorMessage = 'Thiếu token');
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', username);
        await prefs.setString('access_token', accessToken);

        await _showTermSelectionDialog(accessToken, username);
      } else {
        setState(() => _errorMessage = jsonResponse['message'] ?? 'Sai tài khoản hoặc mật khẩu');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Lỗi kết nối: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showTermSelectionDialog(String token, String username) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Text("Đang tải học kỳ...")]),
      ),
    );

    List<Map<String, dynamic>> terms = [];
    String? selectedTermCode;

    try {
      final termRes = await http.get(
        Uri.parse(AppConfig.termsEndpoint),
        headers: {'Authorization': 'Bearer $token'},
      );

      final jsonResp = jsonDecode(utf8.decode(termRes.bodyBytes));

      if (termRes.statusCode == 200 && jsonResp['success'] == true) {
        terms = List<Map<String, dynamic>>.from(jsonResp['data'] as List);
        if (terms.isNotEmpty) selectedTermCode = terms.first['term_code'] as String;
      } else {
        if (mounted) {
          Navigator.pop(context);
          setState(() => _errorMessage = jsonResp['message'] ?? 'Lỗi tải học kỳ');
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        setState(() => _errorMessage = 'Lỗi mạng: $e');
      }
      return;
    }

    if (mounted) Navigator.pop(context);

    if (terms.isEmpty) {
      setState(() => _errorMessage = 'Không có học kỳ nào');
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Chọn học kỳ", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
            content: DropdownButton<String>(
              value: selectedTermCode,
              isExpanded: true,
              hint: const Text("Chọn học kỳ"),
              items: terms.map((term) {
                return DropdownMenuItem<String>(
                  value: term['term_code'] as String,
                  child: Text(term['term_name'] as String),
                );
              }).toList(),
              onChanged: (value) => setDialogState(() => selectedTermCode = value),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadScheduleAndGoHome(selectedTermCode!, token, username);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A5F3F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Tiếp tục"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _loadScheduleAndGoHome(String termCode, String token, String username) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Text("Đang tải TKB...")]),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse(AppConfig.scheduleEndpoint),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({"termCode": termCode}),
      );

      final jsonResp = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && jsonResp['success'] == true) {
        final scheduleList = _flattenScheduleJson(jsonResp['data'], username);
        await DatabaseHelper.instance.replaceAllSchedule(scheduleList);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('last_login_at', DateTime.now().millisecondsSinceEpoch);

        if (!mounted) return;
        Navigator.pop(context);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen()));
      } else {
        if (mounted) {
          Navigator.pop(context);
          setState(() => _errorMessage = jsonResp['message'] ?? 'Lỗi tải TKB');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        setState(() => _errorMessage = 'Không tải được TKB: $e');
      }
    }
  }

  // ========================== UI SIÊU ĐẸP ==========================
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F5E8), Color(0xFFB2DFDB), Colors.white],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(32, size.height * 0.1, 32, 40),
            child: Column(
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 30, offset: Offset(0, 10))],
                        ),
                        child: const Icon(Icons.school_rounded, size: 90, color: Color(0xFF1A5F3F)),
                      ),
                      const SizedBox(height: 24),
                      const Text("VNUA SCHEDULE", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A5F3F))),
                      const SizedBox(height: 8),
                      Text("Học viện Nông nghiệp Việt Nam", style: TextStyle(color: Colors.grey.shade700, fontSize: 15)),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 15))],
                  ),
                  child: Column(
                    children: [
                      _buildTextField(controller: _usernameController, hint: "Mã sinh viên", icon: Icons.person_outline),
                      const SizedBox(height: 20),
                      _buildTextField(controller: _passwordController, hint: "Mật khẩu", icon: Icons.lock_outline, isPassword: true),
                      const SizedBox(height: 20),

                      if (_errorMessage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                          child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                        ),

                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A5F3F),
                            foregroundColor: Colors.white,
                            elevation: 10,
                            shadowColor: const Color(0xFF1A5F3F).withOpacity(0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                              : const Text("ĐĂNG NHẬP", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
                Text("© 2025 VNUA Mobile Team", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        prefixIcon: Icon(icon, color: const Color(0xFF1A5F3F)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF1A5F3F), width: 2.5)),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      ),
    );
  }
}