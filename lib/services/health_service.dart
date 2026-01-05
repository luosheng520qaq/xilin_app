import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  // 创建 Health 实例
  final Health _health = Health();
  bool _isConfigured = false;

  // 定义要获取的数据类型
  // iOS 睡眠类型: SLEEP_IN_BED, SLEEP_ASLEEP, SLEEP_AWAKE, SLEEP_DEEP, SLEEP_LIGHT, SLEEP_REM
  static final List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
  ];

  // 对应的权限（只读）
  static final List<HealthDataAccess> _permissions = _types
      .map((e) => HealthDataAccess.READ)
      .toList();

  /// 配置 Health 插件（必须在使用前调用）
  Future<void> configure() async {
    if (_isConfigured) return;
    try {
      await _health.configure();
      _isConfigured = true;
      print('Health 插件配置成功');
    } catch (e) {
      print('Health 插件配置失败: $e');
    }
  }

  /// 请求健康数据权限（必须由用户手势触发）
  Future<bool> requestPermissions() async {
    // 先配置插件
    await configure();

    // Android 需要先请求活动识别权限
    if (Platform.isAndroid) {
      await Permission.activityRecognition.request();
      await Permission.location.request();
    }

    try {
      // 请求 HealthKit/Health Connect 授权
      // iOS 会弹出系统授权界面
      bool authorized = await _health.requestAuthorization(
        _types,
        permissions: _permissions,
      );
      print('健康权限请求结果: $authorized');
      return authorized;
    } catch (e) {
      print('健康权限请求异常: $e');
      return false;
    }
  }

  /// 检查是否有权限
  Future<bool> hasPermissions() async {
    await configure();
    try {
      bool? has = await _health.hasPermissions(
        _types,
        permissions: _permissions,
      );
      return has ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 获取今日步数
  Future<int> getTodaySteps() async {
    await configure();

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    try {
      int? steps = await _health.getTotalStepsInInterval(midnight, now);
      print('今日步数: $steps');
      return steps ?? 0;
    } catch (e) {
      print('获取步数失败: $e');
      return 0;
    }
  }

  /// 获取昨晚睡眠时长（分钟）
  Future<int> getLastNightSleepMinutes() async {
    await configure();

    final now = DateTime.now();
    // 昨天 18:00 到今天 12:00（覆盖正常睡眠时间）
    final startTime = DateTime(now.year, now.month, now.day - 1, 18, 0);
    final endTime = DateTime(now.year, now.month, now.day, 12, 0);

    try {
      // 获取所有睡眠相关数据类型
      List<HealthDataPoint> sleepData = await _health.getHealthDataFromTypes(
        types: [
          HealthDataType.SLEEP_IN_BED,
          HealthDataType.SLEEP_ASLEEP,
          HealthDataType.SLEEP_DEEP,
          HealthDataType.SLEEP_LIGHT,
          HealthDataType.SLEEP_REM,
        ],
        startTime: startTime,
        endTime: endTime,
      );

      // 去重
      sleepData = _health.removeDuplicates(sleepData);

      print('获取到 ${sleepData.length} 条睡眠数据');

      // 优先使用 SLEEP_IN_BED（总睡眠时间），如果没有则累加其他类型
      int totalMinutes = 0;

      // 先找 SLEEP_IN_BED 数据
      final inBedData = sleepData
          .where((d) => d.type == HealthDataType.SLEEP_IN_BED)
          .toList();
      if (inBedData.isNotEmpty) {
        for (final data in inBedData) {
          final duration = data.dateTo.difference(data.dateFrom);
          totalMinutes += duration.inMinutes;
        }
      } else {
        // 没有 SLEEP_IN_BED，累加实际睡眠阶段
        final actualSleepData = sleepData
            .where(
              (d) =>
                  d.type == HealthDataType.SLEEP_ASLEEP ||
                  d.type == HealthDataType.SLEEP_DEEP ||
                  d.type == HealthDataType.SLEEP_LIGHT ||
                  d.type == HealthDataType.SLEEP_REM,
            )
            .toList();

        for (final data in actualSleepData) {
          final duration = data.dateTo.difference(data.dateFrom);
          totalMinutes += duration.inMinutes;
        }
      }

      print('睡眠时长: $totalMinutes 分钟');
      return totalMinutes;
    } catch (e) {
      print('获取睡眠数据失败: $e');
      return 0;
    }
  }

  /// 获取健康数据列表（用于调试）
  Future<List<HealthDataPoint>> getHealthData() async {
    await configure();

    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    try {
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        types: _types,
        startTime: yesterday,
        endTime: now,
      );

      // 去重
      healthData = _health.removeDuplicates(healthData);

      print('获取到 ${healthData.length} 条健康数据');
      for (var data in healthData) {
        print(
          '  ${data.type}: ${data.value} (${data.dateFrom} - ${data.dateTo})',
        );
      }

      return healthData;
    } catch (e) {
      print('获取健康数据失败: $e');
      return [];
    }
  }

  /// 格式化睡眠时长
  String formatSleepDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '$hours小时$mins分钟';
  }
}
