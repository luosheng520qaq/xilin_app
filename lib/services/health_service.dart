import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health _health = Health();
  bool _isConfigured = false;

  /// 配置 Health 插件
  Future<void> _configure() async {
    if (_isConfigured) return;

    try {
      await _health.configure();
      _isConfigured = true;
    } catch (e) {
      print('Health 配置失败: $e');
    }
  }

  /// 请求健康数据权限（必须由用户手势触发）
  Future<bool> requestPermissions() async {
    // 先配置 Health 插件
    await _configure();

    // Android 需要请求活动识别权限
    if (Platform.isAndroid) {
      await Permission.activityRecognition.request();
    }

    // 定义需要读取的健康数据类型
    final types = [
      HealthDataType.STEPS,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_IN_BED,
    ];

    final permissions = types.map((e) => HealthDataAccess.READ).toList();

    try {
      // 请求授权，iOS 会弹出 HealthKit 授权界面
      final authorized = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );
      print('健康权限请求结果: $authorized');
      return authorized;
    } catch (e) {
      print('健康权限请求失败: $e');
      return false;
    }
  }

  /// 获取今日步数
  Future<int> getTodaySteps() async {
    await _configure();

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
    await _configure();

    final now = DateTime.now();
    final startTime = DateTime(now.year, now.month, now.day - 1, 18, 0);
    final endTime = DateTime(now.year, now.month, now.day, 12, 0);

    try {
      final sleepData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_IN_BED],
        startTime: startTime,
        endTime: endTime,
      );

      final uniqueData = _health.removeDuplicates(sleepData);

      int totalMinutes = 0;
      for (final data in uniqueData) {
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
