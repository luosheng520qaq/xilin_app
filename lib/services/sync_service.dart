import 'package:workmanager/workmanager.dart';
import 'health_service.dart';
import 'location_service.dart';
import 'storage_service.dart';

const String syncTaskName = 'healthSyncTask';

/// 后台任务回调
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == syncTaskName) {
      await SyncService().syncHealthData();
    }
    return true;
  });
}

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final HealthService _healthService = HealthService();
  final LocationService _locationService = LocationService();
  final StorageService _storageService = StorageService();

  /// 初始化后台任务
  Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }

  /// 注册定时同步任务
  Future<void> registerPeriodicSync() async {
    final interval = await _storageService.getSyncInterval();

    await Workmanager().cancelAll();
    await Workmanager().registerPeriodicTask(
      'healthSync',
      syncTaskName,
      frequency: Duration(minutes: interval),
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
  }

  /// 立即同步健康数据
  Future<HealthRecord?> syncHealthData() async {
    try {
      final steps = await _healthService.getTodaySteps();
      final sleepMinutes = await _healthService.getLastNightSleepMinutes();

      // 确保先请求位置权限
      final hasLocationPermission = await _locationService.requestPermissions();
      final position = hasLocationPermission
          ? await _locationService.getCurrentPosition()
          : null;

      final record = HealthRecord(
        timestamp: DateTime.now(),
        steps: steps,
        sleepMinutes: sleepMinutes,
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      await _storageService.saveRecord(record);
      return record;
    } catch (e) {
      print('同步健康数据失败: $e');
      return null;
    }
  }

  /// 更新同步间隔
  Future<void> updateSyncInterval(int minutes) async {
    await _storageService.setSyncInterval(minutes);
    await registerPeriodicSync();
  }
}
