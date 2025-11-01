import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../mock/mock_data.dart';

class ParsedIntent {
  final String type;
  final Map<String, dynamic> params;
  ParsedIntent(this.type, this.params);
}

class NlpRouter {
  // Chuẩn hoá câu nói
  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[!?(),.:;]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Quy ra ngày cụ thể để gọi API (vd: "mai" -> yyyy-MM-dd của mai)
  static DateTime resolveDateForApi(String utterance, DateTime nowLocal) {
    final q = _norm(utterance);
    return _resolveVietnameseDate(q, nowLocal);
  }

  /// Điều hướng intent cơ bản (tkb | lich_1_ngay)
  static ParsedIntent parse(String utterance, DateTime nowLocal) {
    final q = _norm(utterance);

    final hasTkb = q.contains('thời khóa biểu') ||
        q.contains('thời khoá biểu') ||
        q.contains('tkb') ||
        q.contains('môn');
    if (hasTkb) {
      final date = _resolveVietnameseDate(q, nowLocal);
      return ParsedIntent('tkb', {'date': date});
    }

    final hasLich = RegExp(r'\blịch\b').hasMatch(q) || q.contains('schedule');
    if (hasLich) {
      final date = _resolveVietnameseDate(q, nowLocal);
      return ParsedIntent('lich_1_ngay', {'date': date});
    }

    return ParsedIntent('unknown', {});
  }

  // ====== Date resolvers ======
  static DateTime? _parseExplicitDateInParentheses(String q, DateTime now) {
    final m = RegExp(r'\(\s*(\d{1,2})[\/\-](\d{1,2})(?:[\/\-](\d{4}))?\s*\)').firstMatch(q);
    if (m == null) return null;
    final dd = int.parse(m.group(1)!);
    final mm = int.parse(m.group(2)!);
    final yyyy = m.group(3) != null ? int.parse(m.group(3)!) : now.year;
    return DateTime(yyyy, mm, dd);
  }

  static int? _weekdayFromVietnamese(String q) {
    if (RegExp(r'ch(ủ|u)\s*nh(ậ|a)t').hasMatch(q)) return DateTime.sunday;
    if (RegExp(r'(th(ứ|u)\s*hai|\bth\s*2\b)').hasMatch(q)) return DateTime.monday;
    if (RegExp(r'(th(ứ|u)\s*ba|\bth\s*3\b)').hasMatch(q)) return DateTime.tuesday;
    if (RegExp(r'(th(ứ|u)\s*t(ư|u)|\bth\s*4\b)').hasMatch(q)) return DateTime.wednesday;
    if (RegExp(r'(th(ứ|u)\s*n(ă|a)m|\bth\s*5\b)').hasMatch(q)) return DateTime.thursday;
    if (RegExp(r'(th(ứ|u)\s*s(á|a)u|\bth\s*6\b)').hasMatch(q)) return DateTime.friday;
    if (RegExp(r'(th(ứ|u)\s*b(ả|a)y|\bth\s*7\b)').hasMatch(q)) return DateTime.saturday;
    return null;
  }

  static DateTime? _resolveWeekdayPhrase(String q, DateTime now) {
    final wd = _weekdayFromVietnamese(q);
    if (wd == null) return null;

    final explicit = _parseExplicitDateInParentheses(q, now);
    if (explicit != null) return explicit;

    int weekShift = 0;
    bool pinnedThisWeek = false;
    if (q.contains('tuần sau') || q.contains('tuần tới')) { weekShift = 1; pinnedThisWeek = true; }
    else if (q.contains('tuần trước')) { weekShift = -1; pinnedThisWeek = true; }
    else if (q.contains('tuần này')) { weekShift = 0; pinnedThisWeek = true; }

    if (pinnedThisWeek) {
      final mondayThisWeek = now.subtract(Duration(days: now.weekday - DateTime.monday));
      final target = mondayThisWeek.add(Duration(days: 7 * weekShift + (wd - DateTime.monday)));
      return DateTime(target.year, target.month, target.day);
    }

    final delta = (wd - now.weekday + 7) % 7; // gần nhất, kể cả hôm nay
    final target = now.add(Duration(days: delta));
    return DateTime(target.year, target.month, target.day);
  }

  static DateTime _resolveVietnameseDate(String q, DateTime now) {
    final explicitParen = _parseExplicitDateInParentheses(q, now);
    if (explicitParen != null) return explicitParen;

    if (q.contains('hôm nay')) return DateTime(now.year, now.month, now.day);
    if (RegExp(r'(^|\s)mai($|\s)|\bngày mai\b').hasMatch(q)) {
      final d = now.add(const Duration(days: 1));
      return DateTime(d.year, d.month, d.day);
    }
    if (q.contains('ngày kia') || q.contains('ngày mốt')) {
      final d = now.add(const Duration(days: 2));
      return DateTime(d.year, d.month, d.day);
    }
    if (q.contains('hôm qua')) {
      final d = now.subtract(const Duration(days: 1));
      return DateTime(d.year, d.month, d.day);
    }

    final byWeekday = _resolveWeekdayPhrase(q, now);
    if (byWeekday != null) return byWeekday;

    final fullDate = RegExp(r'(\b\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})').firstMatch(q);
    if (fullDate != null) {
      final dd = int.parse(fullDate.group(1)!);
      final mm = int.parse(fullDate.group(2)!);
      final yyyy = int.parse(fullDate.group(3)!);
      return DateTime(yyyy, mm, dd);
    }

    final shortDate = RegExp(r'(?:\bngày\s+)?(\d{1,2})[\/\-](\d{1,2})(?!\d)').firstMatch(q);
    if (shortDate != null) {
      final dd = int.parse(shortDate.group(1)!);
      final mm = int.parse(shortDate.group(2)!);
      return DateTime(now.year, mm, dd);
    }

    return DateTime(now.year, now.month, now.day);
  }
}

class TkbApi {
  final String baseUrl;
  final http.Client _client;
  final bool useMock;
  TkbApi({required this.baseUrl, http.Client? client, this.useMock = false})
      : _client = client ?? http.Client();

  /// Dùng DUY NHẤT demoData (day: d/M/yyyy)
  Future<List<dynamic>> fetchByDate(DateTime date) async {
    if (useMock || baseUrl.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 120));

      final dayKey = DateFormat('d/M/yyyy').format(date);

      final list = demoData
          .where((e) => (e['day']?.toString() ?? '') == dayKey)
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();

      list.sort((a, b) => (a['start'] ?? '').toString().compareTo((b['start'] ?? '').toString()));
      return list;
    }

    // API thật (nếu sau này bật) — vẫn giữ để khỏi sửa code nơi khác
    final ymd = DateFormat('yyyy-MM-dd').format(date);
    final uri = Uri.parse('$baseUrl/tkb').replace(queryParameters: {'date': ymd});
    late http.Response resp;
    try {
      resp = await _client.get(uri, headers: {'Accept': 'application/json'});
    } catch (e) {
      throw Exception('Không gọi được API TKB: $e');
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body);
      if (data is Map && data['items'] is List) return (data['items'] as List);
      if (data is List) return data;
      return [];
    } else {
      throw Exception('Lỗi API TKB: ${resp.statusCode} - ${resp.body}');
    }
  }
}

class LichApi {
  final String baseUrl;
  final http.Client _client;
  final bool useMock;
  LichApi({required this.baseUrl, http.Client? client, this.useMock = false})
      : _client = client ?? http.Client();

  /// Cũng dùng DUY NHẤT demoData (lọc theo ngày giống TKB)
  Future<List<dynamic>> fetchByDate(DateTime date) async {
    if (useMock || baseUrl.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 120));
      final dayKey = DateFormat('d/M/yyyy').format(date);

      final list = demoData
          .where((e) => (e['day']?.toString() ?? '') == dayKey)
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();

      list.sort((a, b) => (a['start'] ?? '').toString().compareTo((b['start'] ?? '').toString()));
      return list;
    }

    // API thật (giữ nguyên để không phá interface)
    final ymd = DateFormat('yyyy-MM-dd').format(date);
    final uri = Uri.parse('$baseUrl/lich').replace(queryParameters: {'date': ymd});
    late http.Response resp;
    try {
      resp = await _client.get(uri, headers: {'Accept': 'application/json'});
    } catch (e) {
      throw Exception('Không gọi được API Lịch: $e');
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body);
      if (data is Map && data['items'] is List) return (data['items'] as List);
      if (data is List) return data;
      return [];
    } else {
      throw Exception('Lỗi API Lịch: ${resp.statusCode} - ${resp.body}');
    }
  }
}

class VoiceAskButton extends StatefulWidget {
  final String apiBaseUrl;
  final bool useMock;
  final void Function({
  required String transcript,
  ParsedIntent? intent,
  List<dynamic>? payload,
  Object? error,
  String? apiDate, // yyyy-MM-dd đã format sẵn cho API
  })? onCompleted;

  const VoiceAskButton({
    super.key,
    required this.apiBaseUrl,
    this.useMock = true,
    this.onCompleted,
  });

  @override
  State<VoiceAskButton> createState() => _VoiceAskButtonState();
}

class _VoiceAskButtonState extends State<VoiceAskButton> {
  late stt.SpeechToText _speech;
  final FlutterTts _tts = FlutterTts();
  bool _isListening = false;
  String _lastTranscript = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      final engines = await _tts.getEngines;
      if (engines is List && engines.contains('com.google.android.tts')) {
        await _tts.setEngine('com.google.android.tts');
      }
    } catch (_) {}
    try {
      final voices = await _tts.getVoices;
      if (voices is List && voices.isNotEmpty) {
        final chosen = Map<String, dynamic>.from(voices.first);
        await _tts.setVoice(chosen.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')));
      }
    } catch (_) {}
    await _tts.setLanguage('vi-VN');
    await _tts.setSpeechRate(0.9);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _toggleRecord() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      if (_lastTranscript.trim().isNotEmpty) {
        await _onFinalTranscript(_lastTranscript);
      }
      return;
    }

    final available = await _speech.initialize(
      onStatus: (s) {
        if (s == 'notListening' && _lastTranscript.isNotEmpty) {
          _onFinalTranscript(_lastTranscript);
        }
      },
      onError: (e) => widget.onCompleted?.call(transcript: _lastTranscript, error: e),
    );

    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không khởi tạo được nhận dạng giọng nói')),
        );
      }
      widget.onCompleted?.call(transcript: _lastTranscript, error: 'Speech init unavailable');
      return;
    }

    setState(() => _isListening = true);

    await _speech.listen(
      localeId: 'vi_VN',
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 2),
      onResult: (result) {
        setState(() => _lastTranscript = result.recognizedWords);
        if (result.finalResult && _lastTranscript.isNotEmpty) {
          _speech.stop();
          setState(() => _isListening = false);
          _onFinalTranscript(_lastTranscript);
        }
      },
    );
  }

  Future<void> _onFinalTranscript(String text) async {
    unawaited(_tts.speak(text));

    final nowLocal = DateTime.now();
    final resolvedDate = NlpRouter.resolveDateForApi(text, nowLocal);
    final apiDate = DateFormat('yyyy-MM-dd').format(resolvedDate);

    final intent = NlpRouter.parse(text, nowLocal);

    try {
      List<dynamic>? payload;
      if (intent.type == 'tkb') {
        payload = await TkbApi(
          baseUrl: widget.apiBaseUrl,
          useMock: widget.useMock,
        ).fetchByDate(resolvedDate);
      } else if (intent.type == 'lich_1_ngay') {
        payload = await LichApi(
          baseUrl: widget.apiBaseUrl,
          useMock: widget.useMock,
        ).fetchByDate(resolvedDate);
      } else {
        payload = const [];
      }

      widget.onCompleted?.call(
        transcript: text,
        intent: intent,
        payload: payload,
        apiDate: apiDate,
      );
    } catch (e) {
      widget.onCompleted?.call(
        transcript: text,
        intent: intent,
        error: e,
        apiDate: apiDate,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _toggleRecord,
      icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
      label: Text(_isListening ? 'Đang nghe…' : 'Nhấn để hỏi bằng giọng'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
