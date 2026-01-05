# 健康追踪 APP 配置说明

## 功能
- ✅ 获取今日步数（HealthKit / Health Connect）
- ✅ 获取昨晚睡眠时长
- ✅ GPS 位置获取
- ✅ 定时自动同步（可设置 15/30/60/120/240 分钟）
- ✅ 本地历史记录保存（最近 30 天）

## iOS 配置（必须）

### 1. 打开 HealthKit Capability
1. 用 Xcode 打开 `ios/Runner.xcworkspace`
2. 选择 Runner → Signing & Capabilities
3. 点击 `+ Capability` → 添加 `HealthKit`
4. 勾选 `Clinical Health Records`（如需要）

### 2. Info.plist（已配置）
权限描述已添加到 `ios/Runner/Info.plist`

## Android 配置

### 1. Health Connect（Android 14+）
用户需要安装 [Health Connect](https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata) 应用

### 2. 权限（已配置）
AndroidManifest.xml 已添加必要权限

## 运行
```bash
# 安装依赖
flutter pub get

# 运行 Android
flutter run

# 运行 iOS
cd ios && pod install && cd ..
flutter run
```

## 文件结构
```
lib/
├── main.dart                    # 主界面
└── services/
    ├── health_service.dart      # 健康数据服务
    ├── location_service.dart    # 位置服务
    ├── storage_service.dart     # 本地存储
    └── sync_service.dart        # 后台同步服务
```
