import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/health_service.dart';
import 'services/location_service.dart';
import 'services/storage_service.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SyncService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '健康追踪',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HealthService _healthService = HealthService();
  final LocationService _locationService = LocationService();
  final StorageService _storageService = StorageService();
  final SyncService _syncService = SyncService();

  int _todaySteps = 0;
  int _sleepMinutes = 0;
  int _syncInterval = 60;
  bool _isLoading = false;
  bool _hasPermission = false;
  List<HealthRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() => _isLoading = true);

    // 请求权限
    final healthPermission = await _healthService.requestPermissions();
    final locationPermission = await _locationService.requestPermissions();
    _hasPermission = healthPermission && locationPermission;

    // 加载设置和数据
    _syncInterval = await _storageService.getSyncInterval();
    await _loadData();

    // 注册后台同步
    if (_hasPermission) {
      await _syncService.registerPeriodicSync();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadData() async {
    _todaySteps = await _healthService.getTodaySteps();
    _sleepMinutes = await _healthService.getLastNightSleepMinutes();
    _records = await _storageService.getRecords();
    if (mounted) setState(() {});
  }

  Future<void> _syncNow() async {
    setState(() => _isLoading = true);
    await _syncService.syncHealthData();
    await _loadData();
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('同步完成')),
      );
    }
  }

  void _showIntervalDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('设置同步间隔'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [15, 30, 60, 120, 240].map((minutes) {
            return ListTile(
              title: Text('$minutes 分钟'),
              leading: Icon(
                _syncInterval == minutes
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: Theme.of(context).colorScheme.primary,
              ),
              onTap: () async {
                await _syncService.updateSyncInterval(minutes);
                setState(() => _syncInterval = minutes);
                Navigator.pop(dialogContext);
              },
            );
          }).toList(),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('健康追踪'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showIntervalDialog,
            tooltip: '同步设置',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 权限状态
                    if (!_hasPermission)
                      Card(
                        color: Colors.orange.shade100,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: Colors.orange),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text('请授予健康和位置权限以使用完整功能'),
                              ),
                              TextButton(
                                onPressed: _initializeApp,
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // 今日数据卡片
                    Row(
                      children: [
                        Expanded(
                          child: _DataCard(
                            icon: Icons.directions_walk,
                            title: '今日步数',
                            value: '$_todaySteps',
                            unit: '步',
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DataCard(
                            icon: Icons.bedtime,
                            title: '昨晚睡眠',
                            value: _healthService.formatSleepDuration(_sleepMinutes),
                            unit: '',
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 同步间隔显示
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.sync),
                        title: const Text('自动同步间隔'),
                        subtitle: Text('每 $_syncInterval 分钟'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showIntervalDialog,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 历史记录
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '历史记录',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        TextButton(
                          onPressed: () async {
                            await _storageService.clearRecords();
                            await _loadData();
                          },
                          child: const Text('清除'),
                        ),
                      ],
                    ),

                    if (_records.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('暂无记录')),
                      )
                    else
                      ..._records.reversed.take(20).map((record) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                DateFormat('MM-dd HH:mm').format(record.timestamp),
                              ),
                              subtitle: Text(
                                '步数: ${record.steps} | 睡眠: ${_healthService.formatSleepDuration(record.sleepMinutes)}',
                              ),
                              trailing: record.latitude != null
                                  ? const Icon(Icons.location_on, size: 16)
                                  : null,
                            ),
                          )),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _syncNow,
        icon: const Icon(Icons.sync),
        label: const Text('立即同步'),
      ),
    );
  }
}

class _DataCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String unit;
  final Color color;

  const _DataCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            if (unit.isNotEmpty) Text(unit),
          ],
        ),
      ),
    );
  }
}
