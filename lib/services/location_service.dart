import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// 请求位置权限（包括后台定位）
  Future<bool> requestPermissions() async {
    // 检查定位服务是否开启
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // 先请求前台定位权限
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    // 请求后台定位权限（始终允许）
    if (Platform.isAndroid) {
      // Android 需要单独请求后台定位权限
      final bgStatus = await Permission.locationAlways.status;
      if (!bgStatus.isGranted) {
        final result = await Permission.locationAlways.request();
        if (!result.isGranted) {
          // 后台权限未授予，但前台权限已有，仍可使用
          print('后台定位权限未授予，仅使用前台定位');
        }
      }
    } else if (Platform.isIOS) {
      // iOS 通过 Geolocator 请求 always 权限
      if (permission == LocationPermission.whileInUse) {
        // 已有前台权限，尝试请求始终权限
        // iOS 会自动弹出"始终允许"的选项
        permission = await Geolocator.requestPermission();
      }
    }

    return true;
  }

  /// 检查是否有后台定位权限
  Future<bool> hasBackgroundPermission() async {
    if (Platform.isAndroid) {
      return await Permission.locationAlways.isGranted;
    } else {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always;
    }
  }

  /// 获取当前位置
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestPermissions();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      print('获取位置失败: $e');
      return null;
    }
  }

  /// 打开应用设置（用于引导用户手动开启权限）
  Future<bool> openSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// 打开位置服务设置
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }
}
