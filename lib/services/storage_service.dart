import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HealthRecord {
  final DateTime timestamp;
  final int steps;
  final int sleepMinutes;
  final double? latitude;
  final double? longitude;

  HealthRecord({
    required this.timestamp,
    required this.steps,
    required this.sleepMinutes,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'steps': steps,
        'sleepMinutes': sleepMinutes,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory HealthRecord.fromJson(Map<String, dynamic> json) => HealthRecord(
        timestamp: DateTime.parse(json['timestamp']),
        steps: json['steps'] ?? 0,
        sleepMinutes: json['sleepMinutes'] ?? 0,
        latitude: json['latitude']?.toDouble(),
        longitude: json['longitude']?.toDouble(),
      );
}

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _recordsKey = 'health_records';
  static const String _intervalKey = 'sync_interval_minutes';

  /// 保存健康记录
  Future<void> saveRecord(HealthRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await getRecords();
    records.add(record);

    // 只保留最近 30 天的数据
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final filtered = records.where((r) => r.timestamp.isAfter(cutoff)).toList();

    final jsonList = filtered.map((r) => r.toJson()).toList();
    await prefs.setString(_recordsKey, jsonEncode(jsonList));
  }

  /// 获取所有记录
  Future<List<HealthRecord>> getRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_recordsKey);
    if (jsonStr == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.map((j) => HealthRecord.fromJson(j)).toList();
    } catch (e) {
      print('解析记录失败: $e');
      return [];
    }
  }

  /// 获取今日记录
  Future<List<HealthRecord>> getTodayRecords() async {
    final records = await getRecords();
    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);

    return records.where((r) => r.timestamp.isAfter(midnight)).toList();
  }

  /// 设置同步间隔（分钟）
  Future<void> setSyncInterval(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_intervalKey, minutes);
  }

  /// 获取同步间隔（分钟），默认 60 分钟
  Future<int> getSyncInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_intervalKey) ?? 60;
  }

  /// 清除所有记录
  Future<void> clearRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recordsKey);
  }
}
