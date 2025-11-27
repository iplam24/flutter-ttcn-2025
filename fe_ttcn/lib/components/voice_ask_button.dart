// lib/components/voice_ask_button.dart  (hoặc lib/widgets/voice_ask_button.dart)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../model/schedule_item.dart';

class ParsedIntent {
  final String type;
  final Map<String, dynamic> params;
  ParsedIntent(this.type, this.params);
}

class NlpRouter {
  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[!?(),.:;]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static ParsedIntent parse(String utterance, DateTime nowLocal) {
    final q = _norm(utterance);

    final hasTkb = q.contains('thời khóa biểu') ||
        q.contains('thời khoá biểu') ||
        q.contains('tkb') ||
        q.contains('môn');

    final hasLich = RegExp(r'\blịch\b').hasMatch(q);

    final isWeek = q.contains('cả tuần') || q.contains('toàn tuần') || q.contains('tuần này') || q.contains('tuần sau');

    final date = _resolveDate(q, nowLocal);

    if (hasTkb && isWeek) return ParsedIntent('tkb_ca_tuan', {'date': date});
    if (hasTkb) return ParsedIntent('tkb_1_ngay', {'date': date});
    if (hasLich && isWeek) return ParsedIntent('lich_ca_tuan', {'date': date});
    if (hasLich) return ParsedIntent('lich_1_ngay', {'date': date});

    return ParsedIntent('unknown', {'date': date});
  }

  static DateTime _resolveDate(String q, DateTime now) {
    final normalized = _norm(q);

    if (normalized.contains('hôm nay')) return DateTime(now.year, now.month, now.day);
    if (normalized.contains('ngày mai') || normalized.contains('mai')) return now.add(const Duration(days: 1));
    if (normalized.contains('ngày kia') || normalized.contains('mốt')) return now.add(const Duration(days: 2));
    if (normalized.contains('hôm qua')) return now.subtract(const Duration(days: 1));

    // Thứ trong tuần
    final weekdayMap = {
      'thứ 2': DateTime.monday, 'th 2': DateTime.monday, 'hai': DateTime.monday,
      'thứ 3': DateTime.tuesday, 'th 3': DateTime.tuesday, 'ba': DateTime.tuesday,
      'thứ 4': DateTime.wednesday, 'th 4': DateTime.wednesday, 'tư': DateTime.wednesday,
      'thứ 5': DateTime.thursday, 'th 5': DateTime.thursday, 'năm': DateTime.thursday,
      'thứ 6': DateTime.friday, 'th 6': DateTime.friday, 'sáu': DateTime.friday,
      'thứ 7': DateTime.saturday, 'th 7': DateTime.saturday, 'bảy': DateTime.saturday,
      'chủ nhật': DateTime.sunday, 'cn': DateTime.sunday,
    };

    for (final entry in weekdayMap.entries) {
      if (normalized.contains(entry.key)) {
        final targetWeekday = entry.value;
        final daysToAdd = (targetWeekday - now.weekday + 7) % 7;
        return now.add(Duration(days: daysToAdd == 0 ? 7 : daysToAdd));
      }
    }

    return DateTime(now.year, now.month, now.day);
  }

  static DateTime getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
  }
}

class VoiceAskButton extends StatefulWidget {
  final void Function({
  required String transcript,
  required List<ScheduleItem> schedule,
  required String message,
  })? onResult;

  const VoiceAskButton({super.key, this.onResult});

  @override
  State<VoiceAskButton> createState() => _VoiceAskButtonState();
}

class _VoiceAskButtonState extends State<VoiceAskButton> {
  late stt.SpeechToText _speech;
  final FlutterTts _tts = FlutterTts();
  bool _isListening = false;
  String _transcript = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('vi-VN');
    await _tts.setSpeechRate(0.9);
  }

  Future<void> _startListening() async {
    final available = await _speech.initialize();
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể dùng micro')),
      );
      return;
    }

    setState(() => _isListening = true);

    _speech.listen(
      localeId: 'vi_VN',
      onResult: (result) {
        setState(() => _transcript = result.recognizedWords);

        if (result.finalResult && _transcript.isNotEmpty) {
          _speech.stop();
          setState(() => _isListening = false);
          _processVoiceCommand(_transcript);
        }
      },
    );
  }

  Future<void> _processVoiceCommand(String text) async {
    await _tts.speak("Đã nghe $text");

    final now = DateTime.now();
    final intent = NlpRouter.parse(text, now);
    final date = intent.params['date'] as DateTime;

    List<ScheduleItem> schedule = [];
    String message = '';

    try {
      if (intent.type.contains('ca_tuan')) {
        final monday = NlpRouter.getWeekStart(date);
        schedule = await DatabaseHelper.instance.getScheduleForWeek(monday);
        message = schedule.isEmpty
            ? 'Tuần này bạn không có môn nào.'
            : 'Tuần này bạn có ${schedule.length} tiết học.';
      } else {
        schedule = await DatabaseHelper.instance.getScheduleByDate(date);
        final dateStr = DateFormat('dd/MM').format(date);
        message = schedule.isEmpty
            ? 'Ngày $dateStr bạn rảnh!'
            : 'Ngày $dateStr có ${schedule.length} môn.';
      }

      await _tts.speak(message);
    } catch (e) {
      message = 'Có lỗi xảy ra';
      await _tts.speak(message);
    }

    widget.onResult?.call(
      transcript: text,
      schedule: schedule,
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isListening ? _speech.stop : _startListening,
      icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
      label: Text(_isListening ? 'Đang nghe...' : 'Hỏi bằng giọng nói'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _isListening ? Colors.red.shade600 : Colors.deepPurple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }
}