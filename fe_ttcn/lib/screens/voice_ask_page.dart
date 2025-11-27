// lib/screens/voice_ask_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/voice_ask_button.dart';
import '../model/schedule_item.dart';
import '../widgets/schedule_cards.dart';

class VoiceAskPage extends StatefulWidget {
  const VoiceAskPage({super.key});

  @override
  State<VoiceAskPage> createState() => _VoiceAskPageState();
}

class _VoiceAskPageState extends State<VoiceAskPage> {
  String _transcript = 'Chưa có gì...';
  String _message = 'Nhấn micro và hỏi: "TKB hôm nay", "Lịch thứ 4", "Môn tuần này"...';
  List<ScheduleItem> _schedule = [];

  String _fmtDate(DateTime d) =>
      DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(d);

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hỏi TKB bằng giọng nói (Local DB)'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Hôm nay: ${_fmtDate(today)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Thử nói:\n'
                      '• "TKB hôm nay" • "Lịch thứ ba tuần sau"\n'
                      '• "Môn ngày mai" • "Cả tuần này có những môn gì"',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
              ],
            ),
          ),

          // DÙNG VOICE ASK BUTTON MỚI – DỮ LIỆU TỪ SQLITE LOCAL
          // ** LƯU Ý: CẦN TẠO FILE `voice_ask_button.dart` **
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: VoiceAskButton(
              onResult: ({
                required String transcript,
                required List<ScheduleItem> schedule,
                required String message,
              }) {
                setState(() {
                  _transcript = transcript;
                  _message = message;
                  _schedule = schedule;
                });
              },
            ),
          ),

          const SizedBox(height: 20),

          // Hiển thị kết quả (Giao diện mới)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎤 Bạn nói:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                    ),
                    Text(_transcript, style: const TextStyle(fontSize: 16)),
                    const Divider(height: 20),
                    Text(
                      '💡 Trợ lý trả lời:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                    ),
                    Text(_message, style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Danh sách môn học (Giao diện mới)
          Expanded(
            child: _schedule.isEmpty
                ? const Center(child: Text('Chưa có lịch nào'))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _schedule.length,
              itemBuilder: (context, index) {
                final item = _schedule[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        item.tietHoc.split('-').first,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(item.tenMonHoc, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('${item.phongHoc} • Tiết ${item.tietHoc}'),
                    trailing: Text(item.giangVien, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}