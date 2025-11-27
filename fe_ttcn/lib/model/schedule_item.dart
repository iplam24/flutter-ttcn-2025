// lib/model/schedule_item.dart

import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class ScheduleItem {
  final int? id;
  final String mssv;
  final String? maMon;
  final String tenMon;
  final int? nhom;
  final int? toNhom;
  final int? soTinChi;
  final String? lop;
  final int? thu; // 2=Thứ 2, 3=Thứ 3, ...
  final int tietBatDau;
  final int soTiet;
  final String phong;
  final String giangVien;
  final int? tuanSo; // week_in_term
  final String date; // yyyy-MM-dd

  String get tietHoc {
    final end = tietBatDau + soTiet - 1;
    return '$tietBatDau-${end >= tietBatDau ? end : tietBatDau}';
  }

  String get tenMonHoc => tenMon;
  String get phongHoc => phong;

  ScheduleItem({
    this.id,
    required this.mssv,
    this.maMon,
    required this.tenMon,
    this.nhom,
    this.toNhom,
    this.soTinChi,
    this.lop,
    this.thu,
    required this.tietBatDau,
    required this.soTiet,
    required this.phong,
    required this.giangVien,
    this.tuanSo,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mssv': mssv,
      'maMon': maMon,
      'tenMon': tenMon,
      'nhom': nhom,
      'toNhom': toNhom,
      'soTinChi': soTinChi,
      'lop': lop,
      'thu': thu,
      'tietBatDau': tietBatDau,
      'soTiet': soTiet,
      'phong': phong,
      'giangVien': giangVien,
      'tuanSo': tuanSo,
      'date': date,
    };
  }

  static ScheduleItem fromMap(Map<String, dynamic> map) {
    return ScheduleItem(
      id: map['id'],
      mssv: map['mssv'] ?? '',
      maMon: map['maMon'],
      tenMon: map['tenMon'] ?? 'Không rõ môn',
      nhom: map['nhom'],
      toNhom: map['toNhom'],
      soTinChi: map['soTinChi'],
      lop: map['lop'],
      thu: map['thu'],
      tietBatDau: map['tietBatDau'] ?? 1,
      soTiet: map['soTiet'] ?? 1,
      phong: map['phong'] ?? 'Chưa có',
      giangVien: map['giangVien'] ?? 'Chưa có',
      tuanSo: map['tuanSo'],
      date: map['date'] ?? '',
    );
  }

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {

    // Hàm làm sạch room_code (chỉ lấy phần đầu trước dấu gạch ngang và trim)
    String cleanRoomCode(String room) {
      final parts = room.split('-');
      return parts.isNotEmpty ? parts[0].trim() : room.trim();
    }

    // API trả về weekday (2=Thứ 2, 3=Thứ 3, ... 7=Thứ 7).
    final int rawWeekday = json['weekday'] is int
        ? json['weekday']
        : int.tryParse(json['weekday']?.toString() ?? '0') ?? 0;

    // Credit là String, cần parse
    final String rawCredit = json['credit']?.toString() ?? '0';
    final int soTinChi = int.tryParse(rawCredit) ?? 0;

    // Lấy phần ngày (yyyy-MM-dd) từ trường learn_day (ví dụ: "2025-08-12T00:00:00")
    final String learnDate = json['learn_day']?.toString().split('T').first
        ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

    return ScheduleItem(
      mssv: json['mssv']?.toString() ?? 'N/A', // Đã được thêm vào khi flatten
      maMon: json['course_code']?.toString(),
      tenMon: json['course_name']?.toString() ?? 'Chưa có tên môn',
      nhom: int.tryParse(json['group_code']?.toString() ?? '0') ?? 0,
      toNhom: int.tryParse(json['group_practice_code']?.toString() ?? '0') ?? 0,
      soTinChi: soTinChi,
      lop: json['class_code']?.toString(),
      thu: rawWeekday,
      tietBatDau: json['lesson_period_start'] is int
          ? json['lesson_period_start']
          : int.tryParse(json['lesson_period_start']?.toString() ?? '1') ?? 1,
      soTiet: json['lesson_count'] is int
          ? json['lesson_count']
          : int.tryParse(json['lesson_count']?.toString() ?? '1') ?? 1,
      phong: cleanRoomCode(json['room_code']?.toString() ?? 'Chưa có'),
      giangVien: json['lecturer_name']?.toString() ?? 'Chưa có',
      tuanSo: json['week_in_term'] is int
          ? json['week_in_term']
          : int.tryParse(json['week_in_term']?.toString() ?? '0') ?? 0,
      date: learnDate,
    );
  }
}