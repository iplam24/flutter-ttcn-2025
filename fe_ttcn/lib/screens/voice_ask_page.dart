// lib/screens/voice_ask_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/voice_ask_button.dart';
import '../widgets/schedule_cards.dart'; // Import widget mới

class VoiceAskPage extends StatefulWidget {
  const VoiceAskPage({super.key});

  @override
  State<VoiceAskPage> createState() => _VoiceAskPageState();
}

class _VoiceAskPageState extends State<VoiceAskPage> {
  String? transcript;
  String? intentType;
  DateTime? intentDate;
  String? apiDate; // yyyy-MM-dd để gọi API/mock
  List<dynamic>? payload; // dữ liệu mock trả về
  Object? error;

  String _fmtDate(DateTime d) =>
      DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(d);

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Demo Voice Ask (Mock)')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Hôm nay: ${_fmtDate(today)}\n'
                  'Ví dụ nói:\n'
                  '• "thời khóa biểu ngày mai"\n'
                  '• "lịch thứ hai (29/9/2025)"',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: VoiceAskButton(
              apiBaseUrl: '', // rỗng => dùng mock
              useMock: true, // khi có API thật: đổi thành false + set baseUrl
              onCompleted: ({
                required String transcript,
                intent,
                payload,
                error,
                apiDate,
              }) {
                setState(() {
                  this.transcript = transcript;
                  this.intentType = intent?.type;
                  this.intentDate = intent?.params['date'];
                  this.apiDate = apiDate;
                  this.payload = payload;
                  this.error = error;
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _kv('Bạn nói', transcript),
                _kv('Intent', intentType),
                if (intentDate != null)
                  _kv('Ngày (đã quy đổi)', _fmtDate(intentDate!)),
                _kv('API date', apiDate),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text('Lỗi: $error',
                      style: const TextStyle(color: Colors.red)),
                ],
                const Divider(height: 24),
                Text('Kết quả (mock):',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (payload == null)
                  const Text('— Chưa có —')
                else if (payload!.isEmpty)
                  const Text('— Không có dữ liệu —')
                else
                  ...payload!.map((e) {
                    final map = Map<String, dynamic>.from(e);
                    final looksUni =
                        map.containsKey('start') && map.containsKey('end');
                    // Sử dụng các Card đã được tách ra
                    return looksUni ? UniScheduleCard(map) : SimpleCard(map);
                  }).toList(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget _kv này chỉ dùng trong trang này, nên giữ nó ở đây
  Widget _kv(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value ?? '—')),
        ],
      ),
    );
  }
}