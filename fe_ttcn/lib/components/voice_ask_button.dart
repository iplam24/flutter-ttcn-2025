import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../mock/mock_data.dart'; // Giả định mock_data.dart tồn tại

class ParsedIntent {
  final String type;
  final Map<String, dynamic> params;
  ParsedIntent(this.type, this.params);
}

class NlpRouter {
  // Chuẩn hoá câu nói: Loại bỏ dấu câu, chuyển về chữ thường, loại bỏ khoảng trắng thừa
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

  /// Điều hướng intent cơ bản (tkb | lich_1_ngay | lich_ca_tuan)
  static ParsedIntent parse(String utterance, DateTime nowLocal) {
    final q = _norm(utterance);

    // Intent: THỜI KHÓA BIỂU
    final hasTkb = q.contains('thời khóa biểu') ||
        q.contains('thời khoá biểu') ||
        q.contains('tkb') ||
        q.contains('môn');
    if (hasTkb) {
      // Phân biệt TKB 1 ngày hay cả tuần
      if (q.contains('cả tuần') || q.contains('toàn tuần') || q.contains('hết tuần')) {
        final date = _resolveWeekStartForApi(q, nowLocal); // Ngày bắt đầu tuần (thứ 2)
        return ParsedIntent('tkb_ca_tuan', {'date': date});
      }
      final date = _resolveVietnameseDate(q, nowLocal);
      return ParsedIntent('tkb_1_ngay', {'date': date});
    }

    // Intent: LỊCH (Chung chung)
    final hasLich = RegExp(r'\blịch\b').hasMatch(q) || q.contains('schedule');
    if (hasLich) {
      // Phân biệt Lịch 1 ngày hay cả tuần
      if (q.contains('cả tuần') || q.contains('toàn tuần') || q.contains('hết tuần')) {
        final date = _resolveWeekStartForApi(q, nowLocal);
        return ParsedIntent('lich_ca_tuan', {'date': date});
      }
      final date = _resolveVietnameseDate(q, nowLocal);
      return ParsedIntent('lich_1_ngay', {'date': date});
    }

    return ParsedIntent('unknown', {});
  }

  // ====== Date resolvers ======

  /// Lấy ngày Thứ Hai của tuần được nhắc đến
  static DateTime _resolveWeekStartForApi(String q, DateTime now) {
    final normalizedQ = _norm(q);
    int weekShift = 0;

    if (normalizedQ.contains('tuần sau') || normalizedQ.contains('tuần tới')) {
      weekShift = 1;
    } else if (normalizedQ.contains('tuần trước')) {
      weekShift = -1;
    }
    // Mặc định tuần này nếu không có từ khóa

    // Thứ Hai của tuần hiện tại (hoặc tuần tương ứng)
    final mondayThisWeek = now.subtract(Duration(days: now.weekday - DateTime.monday));
    final target = mondayThisWeek.add(Duration(days: 7 * weekShift));
    return DateTime(target.year, target.month, target.day);
  }


  static DateTime? _parseExplicitDateInParentheses(String q, DateTime now) {
    // Định dạng (d/m) hoặc (d/m/yyyy)
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
    bool pinnedToWeek = false; // Đã xác định rõ tuần (trước/này/sau)
    if (q.contains('tuần sau') || q.contains('tuần tới')) { weekShift = 1; pinnedToWeek = true; }
    else if (q.contains('tuần trước')) { weekShift = -1; pinnedToWeek = true; }
    else if (q.contains('tuần này')) { weekShift = 0; pinnedToWeek = true; }

    if (pinnedToWeek) {
      // Ngày Thứ Hai của tuần được chỉ định
      final mondayOfWeek = now.subtract(Duration(days: now.weekday - DateTime.monday))
          .add(Duration(days: 7 * weekShift));
      final target = mondayOfWeek.add(Duration(days: (wd - DateTime.monday)));
      return DateTime(target.year, target.month, target.day);
    }

    // Gần nhất (kể cả hôm nay)
    final delta = (wd - now.weekday + 7) % 7;
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

    // Định dạng đầy đủ (d/m/yyyy)
    final fullDate = RegExp(r'(\b\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})').firstMatch(q);
    if (fullDate != null) {
      final dd = int.parse(fullDate.group(1)!);
      final mm = int.parse(fullDate.group(2)!);
      final yyyy = int.parse(fullDate.group(3)!);
      return DateTime(yyyy, mm, dd);
    }

    // Định dạng ngắn (d/m) hoặc 'ngày d/m'
    final shortDate = RegExp(r'(?:\bngày\s+)?(\d{1,2})[\/\-](\d{1,2})(?!\d)').firstMatch(q);
    if (shortDate != null) {
      final dd = int.parse(shortDate.group(1)!);
      final mm = int.parse(shortDate.group(2)!);
      // Sử dụng năm hiện tại
      return DateTime(now.year, mm, dd);
    }

    // Mặc định là hôm nay nếu không tìm thấy thông tin ngày tháng cụ thể
    return DateTime(now.year, now.month, now.day);
  }
}

// API TkbApi được giữ nguyên, chỉ đổi tên intent tkb -> tkb_1_ngay
class TkbApi {
  final String baseUrl;
  final http.Client _client;
  final bool useMock;
  TkbApi({required this.baseUrl, http.Client? client, this.useMock = false})
      : _client = client ?? http.Client();

  /// Dùng DUY NHẤT demoData (day: d/M/yyyy)
  /// Có thể dùng cho cả 1 ngày và cả tuần (nếu API có hỗ trợ lọc tuần)
  Future<List<dynamic>> fetchByDate(DateTime date, {bool isWeek = false}) async {
    if (useMock || baseUrl.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 120));

      // Lọc theo ngày (cho 1 ngày)
      final dayKey = DateFormat('d/M/yyyy').format(date);
      final list = demoData
          .where((e) => isWeek
          ? true // Với mock data, có thể cần logic phức tạp hơn. Giả sử mock chứa dữ liệu đủ 1 tuần.
          : (e['day']?.toString() ?? '') == dayKey)
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();

      list.sort((a, b) => (a['start'] ?? '').toString().compareTo((b['start'] ?? '').toString()));
      return list;
    }

    // Giữ nguyên logic API thật, có thể cần chỉnh sửa nếu API hỗ trợ 'week'
    final ymd = DateFormat('yyyy-MM-dd').format(date);
    final queryParams = isWeek ? {'week_start_date': ymd} : {'date': ymd};
    final path = isWeek ? 'tkb_week' : 'tkb';

    final uri = Uri.parse('$baseUrl/$path').replace(queryParameters: queryParams);
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

// API LichApi được giữ nguyên, có thêm logic isWeek
class LichApi {
  final String baseUrl;
  final http.Client _client;
  final bool useMock;
  LichApi({required this.baseUrl, http.Client? client, this.useMock = false})
      : _client = client ?? http.Client();

  /// Cũng dùng DUY NHẤT demoData (lọc theo ngày giống TKB)
  Future<List<dynamic>> fetchByDate(DateTime date, {bool isWeek = false}) async {
    if (useMock || baseUrl.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 120));
      final dayKey = DateFormat('d/M/yyyy').format(date);

      final list = demoData
          .where((e) => isWeek
          ? true // Với mock data, có thể cần logic phức tạp hơn. Giả sử mock chứa dữ liệu đủ 1 tuần.
          : (e['day']?.toString() ?? '') == dayKey)
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();

      list.sort((a, b) => (a['start'] ?? '').toString().compareTo((b['start'] ?? '').toString()));
      return list;
    }

    // Giữ nguyên logic API thật, có thể cần chỉnh sửa nếu API hỗ trợ 'week'
    final ymd = DateFormat('yyyy-MM-dd').format(date);
    final queryParams = isWeek ? {'week_start_date': ymd} : {'date': ymd};
    final path = isWeek ? 'lich_week' : 'lich';

    final uri = Uri.parse('$baseUrl/$path').replace(queryParameters: queryParams);
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
  // Biến để theo dõi việc gọi hàm hoàn thành để tránh gọi nhiều lần
  bool _isHandlingTranscript = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initTts();
  }

  // Cải thiện cấu hình TTS để có giọng nói chuẩn hơn
  Future<void> _initTts() async {
    try {
      final engines = await _tts.getEngines;
      // Ưu tiên Google TTS cho chất lượng cao hơn trên Android
      const preferredEngine = 'com.google.android.tts';
      if (engines is List && engines.contains(preferredEngine)) {
        await _tts.setEngine(preferredEngine);
      }
    } catch (_) {
      // Bỏ qua lỗi engine
    }
    try {
      final voices = await _tts.getVoices;
      if (voices is List && voices.isNotEmpty) {
        // Cố gắng tìm giọng "nữ" cho tiếng Việt nếu có
        final femaleVoice = voices.firstWhere(
                (v) => (v as Map)['locale']?.startsWith('vi') == true && (v as Map)['name']?.toLowerCase().contains('female') == true,
            orElse: () => voices.firstWhere((v) => (v as Map)['locale']?.startsWith('vi') == true, orElse: () => voices.first));

        final chosen = Map<String, dynamic>.from(femaleVoice as Map);
        await _tts.setVoice(chosen.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')));
      }
    } catch (_) {
      // Bỏ qua lỗi voice
    }
    await _tts.setLanguage('vi-VN');
    await _tts.setSpeechRate(0.95); // Tăng tốc độ nhẹ
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _toggleRecord() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      if (_lastTranscript.trim().isNotEmpty && !_isHandlingTranscript) {
        // Gọi _onFinalTranscript khi người dùng chủ động dừng (nhấn nút lần 2)
        await _onFinalTranscript(_lastTranscript);
      }
      return;
    }

    _lastTranscript = '';
    _isHandlingTranscript = false;

    // Tăng thời gian chờ và thử lại khi init STT
    final available = await _initSpeechToText(retries: 3);

    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không khởi tạo được nhận dạng giọng nói, vui lòng thử lại')),
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
        // Logic sửa lỗi: confidence > 0.6 là đủ để chấp nhận kết quả tốt
        if (result.confidence > 0.6) {
          setState(() => _lastTranscript = result.recognizedWords);
        } else {
          // Vẫn lưu trữ kết quả, nhưng không cập nhật UI nếu quá rè/tin cậy thấp
          _lastTranscript = result.recognizedWords;
        }

        if (result.finalResult && _lastTranscript.isNotEmpty && !_isHandlingTranscript) {
          // Khi nhận dạng xong (finalResult), dừng nghe và xử lý
          unawaited(_speech.stop());
          setState(() => _isListening = false);
          _onFinalTranscript(_lastTranscript);
        }
      },
    );
  }

  // Thử lại khi khởi tạo SpeechToText
  Future<bool> _initSpeechToText({int retries = 1}) async {
    // 💡 Tinh chỉnh: Thêm delay nhỏ trước khi init để tăng độ mượt mà/ổn định
    await Future.delayed(const Duration(milliseconds: 100));

    for (int i = 0; i < retries; i++) {
      try {
        final available = await _speech.initialize(
          onStatus: (s) {
            // 💡 Tinh chỉnh: Loại bỏ việc gọi _onFinalTranscript ở đây
            // vì nó có thể trùng lặp với logic trong onResult hoặc _toggleRecord.
            // Chỉ cần xử lý lỗi ở đây.
            if (s == 'error' && _lastTranscript.isNotEmpty) {
              widget.onCompleted?.call(transcript: _lastTranscript, error: 'STT Error: $s');
            }
          },
          onError: (e) => widget.onCompleted?.call(transcript: _lastTranscript, error: e),
        );
        if (available) return true;
      } catch (e) {
        // Đợi một chút rồi thử lại
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return false;
  }


  Future<void> _onFinalTranscript(String text) async {
    // Ngăn chặn việc gọi lại khi đã xử lý
    if (_isHandlingTranscript) return;
    _isHandlingTranscript = true;

    // 🏆 Đảm bảo chỉ phát lại câu nói của người dùng (transcript)
    if (text.isNotEmpty) {
      unawaited(_tts.speak(text));
    }

    final nowLocal = DateTime.now();
    final intent = NlpRouter.parse(text, nowLocal);
    // Vẫn cần resolve date để gọi API, ngay cả khi không dùng kết quả để đọc
    final resolvedDate = intent.params['date'] as DateTime? ?? nowLocal;
    final apiDate = DateFormat('yyyy-MM-dd').format(resolvedDate);

    try {
      List<dynamic>? payload;
      // ... (Phần gọi API vẫn giữ nguyên để lấy dữ liệu gửi lên onCompleted)

      if (intent.type == 'tkb_ca_tuan') {
        payload = await TkbApi(
          baseUrl: widget.apiBaseUrl,
          useMock: widget.useMock,
        ).fetchByDate(resolvedDate, isWeek: true);
      } else if (intent.type == 'lich_ca_tuan') {
        payload = await LichApi(
          baseUrl: widget.apiBaseUrl,
          useMock: widget.useMock,
        ).fetchByDate(resolvedDate, isWeek: true);
      }
      else if (intent.type == 'tkb_1_ngay') {
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

      // Gọi onCompleted để chuyển kết quả (payload) về widget cha
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
    } finally {
      _isHandlingTranscript = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _toggleRecord,
      icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
      label: Text(_isListening ? 'Đang nghe…' : 'Nhấn để hỏi bằng giọng'),
      style: ElevatedButton.styleFrom(
        // Thay đổi màu sắc khi đang nghe để feedback rõ hơn
        backgroundColor: _isListening ? Colors.red.shade600 : Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
    );
  }
}