import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health _health = Health();
  bool _isAuthorized = false;

  /// 请求健康数据权限
  Future<bool> requestPermissions() async {
    // 请求活动识别权限 (Android)
    if (Platform.isAndroid) {
      await Permission.activityRecognition.request();
    }

    // 定义需要读取的健康数据类型
    final types = [
      HealthDataType.STEPS,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_IN_BED,
    ];

    // 请求 HealthKit/Health Connect 权限
    try {
      _isAuthorized = await _health.requestAuthorization(
        types,
        permissions: [
          HealthDataAccess.READ,
          HealthDataAccess.READ,
          HealthDataAccess.READ,
        ],
      );
      return _isAuthorized;
    } catch (e) {
      print('健康权限请求失败: $e');
      return false;
    }
  }

  /// 获取今日步数
  Future<int> getTodaySteps() async {
    if (!_isAuthorized) {
      await requestPermissions();
    }

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    try {
      final steps = await _health.getTotalStepsInInterval(midnight, now);
      return steps ?? 0;
    } catch (e) {
      print('获取步数失败: $e');
      return 0;
    }
  }

  /// 获取昨晚睡眠时长（分钟）
  Future<int> getLastNightSleepMinutes() async {
    if (!_isAuthorized) {
      await requestPermissions();
    }

    final now = DateTime.now();
    // 昨天 18:00 到今天 12:00 的范围（覆盖正常睡眠时间）
    final startTime = DateTime(now.year, now.month, now.day - 1, 18, 0);
    final endTime = DateTime(now.year, now.month, now.day, 12, 0);

    try {
      final sleepData = await _health.getHealthDataFromTypes(
        types: [
          HealthDataType.SLEEP_ASLEEP,
          HealthDataType.SLEEP_IN_BED,
        ],
        startTime: startTime,
        endTime: endTime,
      );

      // 计算总睡眠时间
      int totalMinutes = 0;
      final processedIntervals = <String>{};

      for (final data in sleepData) {
        // 避免重复计算相同时间段
        final key = '${data.dateFrom}-${data.dateTo}';
        if (processedIntervals.contains(key)) continue;
        processedIntervals.add(key);

        final duration = data.dateTo.difference(data.dateFrom);
        totalMinutes += duration.inMinutes;
      }

      return totalMinutes;
    } catch (e) {
      print('获取睡眠数据失败: $e');
      return 0;
    }
  }

  /// 格式化睡眠时长
  String formatSleepDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '$hours小时$mins分钟';
  }
}
