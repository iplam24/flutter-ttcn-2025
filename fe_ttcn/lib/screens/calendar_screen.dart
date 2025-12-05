// lib/screens/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../database/database_helper.dart';
import '../model/schedule_item.dart';
import 'todo_screen.dart'; // Import để chuyển sang màn hình To-Do

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> with TickerProviderStateMixin {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<ScheduleItem>> _events = {};

  static const Color primaryGreen = Color(0xFF1A5F3F);
  static const Color accentGreen = Color(0xFF2E7D62);
  static const double bottomNavHeight = 56.0 + 30.0;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final all = await DatabaseHelper.instance.getAllSchedule();
    final Map<DateTime, List<ScheduleItem>> events = {};

    for (final item in all) {
      final date = DateTime.parse(item.date);
      final key = DateTime(date.year, date.month, date.day);
      events.putIfAbsent(key, () => []).add(item);
    }

    setState(() => _events = events);
  }

  List<String> _getMarkersForDay(DateTime day) {
    final items = _getEventsForDay(day);
    if (items.isEmpty) return [];

    bool hasMorning = false;
    bool hasAfternoon = false;

    for (var item in items) {
      if (item.tietBatDau <= 5) {
        hasMorning = true;
      } else {
        hasAfternoon = true;
      }
    }

    final List<String> markers = [];
    if (hasMorning) markers.add('S');
    if (hasAfternoon) markers.add('C');

    return markers;
  }

  List<ScheduleItem> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  String _getShift(int startPeriod) {
    return startPeriod <= 5 ? 'S' : 'C';
  }

  Widget _info(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        const Icon(Icons.circle, size: 6, color: Colors.white),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    ),
  );

  Widget _buildEmptyState(String message) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.event_available_rounded, size: 90, color: Colors.grey.shade400),
        const SizedBox(height: 20),
        Text(message, style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
      ],
    ),
  );

  void _viewDetails(ScheduleItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.tenMon, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mã môn: ${item.maMon ?? 'N/A'}'),
            Text('Phòng: ${item.phongHoc}'),
            Text('Giảng viên: ${item.giangVien}'),
            Text('Tiết: ${item.tietHoc} (Ca ${_getShift(item.tietBatDau)})'),
            Text('Ngày: ${item.date}'),
            Text('Tuần: ${item.tuanSo ?? 'N/A'}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng', style: TextStyle(color: primaryGreen))),
        ],
      ),
    );
  }

  void _navigateToAddTodo() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ToDoScreen()),
    );
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final selectedDay = _selectedDay;
    final Color blueAccent = Colors.blue.shade600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: AppBar(elevation: 0, backgroundColor: Colors.white),
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // === CALENDAR VIEW (CHỈ DÙNG 1 LỊCH) ===
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TableCalendar(
              firstDay: DateTime.utc(2020),
              lastDay: DateTime.utc(2030),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: _onDaySelected,
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                setState(() {});
              },
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              eventLoader: _getEventsForDay,
              headerVisible: true,
              daysOfWeekHeight: 30,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Tháng',
                CalendarFormat.week: 'Tuần',
              },

              calendarStyle: const CalendarStyle(
                defaultTextStyle: TextStyle(color: Colors.black87, fontSize: 15),
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(color: Colors.red, fontSize: 15),
                todayTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                selectedTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),

                markerDecoration: BoxDecoration(),

                todayDecoration: BoxDecoration(
                  color: accentGreen,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                    color: primaryGreen,
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 1.5))
                ),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14),
                weekendStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14),
              ),
              locale: 'vi_VN',

              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: true,
                formatButtonDecoration: BoxDecoration(
                  border: Border.all(color: primaryGreen, width: 1.5),
                  borderRadius: BorderRadius.circular(15),
                ),
                formatButtonTextStyle: TextStyle(color: primaryGreen, fontSize: 13, fontWeight: FontWeight.bold),
                leftChevronIcon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black),
                rightChevronIcon: const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.black),
              ),

              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  final markers = _getMarkersForDay(day);
                  if (markers.isEmpty) return const SizedBox.shrink();

                  return Positioned(
                    bottom: 5,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: markers.map((shift) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.0),
                          child: Container(
                            width: 10,
                            height: 10,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: shift == 'S' ? Colors.orange : Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              shift,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 6,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ),

          // === TIÊU ĐỀ NGÀY CHỌN ===
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 20, color: primaryGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedDay == null
                        ? "Chưa chọn ngày"
                        : DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(selectedDay),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Hiện tại: Tuần 15",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),


          // === DANH SÁCH MÔN HỌC (Card List) ===
          Expanded(
            child: FutureBuilder<List<ScheduleItem>>(
              future: DatabaseHelper.instance.getScheduleForDay(
                DateTime(selectedDay?.year ?? DateTime.now().year, selectedDay?.month ?? DateTime.now().month, selectedDay?.day ?? DateTime.now().day),
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryGreen));
                }

                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return _buildEmptyState("Hôm nay nghỉ ngơi nhé!");
                }

                return ListView.builder(
                  // Dùng Padding bottom để không bị FAB và Bottom Nav che mất
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final s = items[i];

                    return GestureDetector(
                      onTap: () => _viewDetails(s), // GỌI HÀM XEM CHI TIẾT
                      child: Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 12),
                        // NỀN TRẮNG, VIỀN XANH
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.blue.shade600!, width: 2.0),
                        ),
                        color: Colors.white,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade600!.withOpacity(0.1),
                            child: Text(_getShift(s.tietBatDau), style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 18),),
                          ),
                          title: Text(
                            s.tenMonHoc,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // HIỂN THỊ MÃ MÔN VÀ NHÓM
                              Text(
                                  'Mã môn: ${s.maMon ?? 'N/A'} - Nhóm: ${s.nhom ?? 'N/A'}',
                                  style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.w600, fontSize: 13)
                              ),
                              const SizedBox(height: 4),
                              Text('Tiết: ${s.tietHoc}'),
                              Text('Phòng: ${s.phongHoc}'),
                              Text('GV: ${s.giangVien}'),
                            ],
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue.shade600), // Icon chuyển hướng
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // === CHÚ THÍCH S/C ===
          const Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 10),
            child: Text(
              'Chú thích: S = Sáng (Tiết 1-5); C = Chiều (Tiết 6+)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          )
        ],
      ),

      // === NÚT NỔI (FAB) ĐỂ CHUYỂN SANG TO-DO ===
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 105.0), // Đẩy nút FAB lên 50px
        child: FloatingActionButton(
          onPressed: _navigateToAddTodo,
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,

          child: const Icon(Icons.add_task),
        ),
      ),
    );
  }
}