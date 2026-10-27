import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/photo.dart';
import '../models/diary.dart';
import '../models/quote.dart';
import '../repository/local_repository.dart';
import 'photo_scanner_service.dart';
import 'quote_service.dart';
import 'scene_classifier_service.dart';

class DatabaseService extends ChangeNotifier {
  static final DatabaseService _instance = DatabaseService._internal();
  late LocalRepository _repository;
  final PhotoScannerService _photoScanner = PhotoScannerService();

  /// 批次通知节流间隔（扫描开始/完成/权限变化不受此限制）
  static const Duration _notifyThrottle = Duration(milliseconds: 500);

  int _scannedCount = 0;
  int get scannedCount => _scannedCount;
  int _scanTotal = 0;
  int get scanTotal => _scanTotal;
  bool _scanningComplete = false;
  bool get scanningComplete => _scanningComplete;
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  Timer? _notifyTimer;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  PhotoPermissionStatus _permissionStatus = PhotoPermissionStatus.unknown;
  PhotoPermissionStatus get permissionStatus => _permissionStatus;
  bool get hasPermission => _photoScanner.hasPermission;

  static const _storageChannel = MethodChannel('com.shiguang/storage_permission');

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  static const _kSchemaVersion = 2;

  static const _incompatibleBoxes = <String>[
    'photos',
    'diary_entries',
    'monthly_diaries',
    'quotes',
  ];

  Future<void> initialize() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    try {
      Hive.init(appDocDir.path);
    } catch (_) {}

    await _migrateIfNeeded();

    _registerAdapters();

    final results = await _openBoxes();

    _repository = LocalRepository(
      photoBox: results[0] as Box<Photo>,
      diaryEntryBox: results[1] as Box<DiaryEntry>,
      monthlyDiaryBox: results[2] as Box<MonthlyDiary>,
      generalBox: results[4],
      sceneBox: results[5] as Box<String>,
    );
    SceneClassifier.instance.attach(_repository);
    QuoteService().init(Hive.box<Quote>('quotes'));
    // 旧版本的「相簿 id 列表」一次性降级为待应用队列（相簿=目录 新模型）
    _repository.migrateLegacyAlbumPhotos();

    _permissionStatus = await _photoScanner.requestPermission();
    debugPrint('[DB] 相册权限状态: $_permissionStatus');
    await requestStoragePermission();
    _notifyNow();
  }

  Future<void> requestStoragePermission() async {
    if (!Platform.isAndroid) return;
    try {
      final granted = await _storageChannel.invokeMethod<bool>('isStorageManagerGranted');
      if (granted == true) {
        debugPrint('[DB] MANAGE_EXTERNAL_STORAGE 已授权');
        return;
      }
      debugPrint('[DB] 请求 MANAGE_EXTERNAL_STORAGE 权限...');
      await _storageChannel.invokeMethod('requestStorageManager');
    } catch (e) {
      debugPrint('[DB] 请求存储权限失败: $e');
    }
  }

  Future<void> _migrateIfNeeded() async {
    try {
      final box = await Hive.openBox('general_settings');
      final currentVersion = box.get('schema_version', defaultValue: 0) as int;
      if (currentVersion < _kSchemaVersion) {
        debugPrint('[DB] schema 版本 $currentVersion → $_kSchemaVersion，清理不兼容的 box');
        await box.close();
        for (final name in _incompatibleBoxes) {
          await Hive.deleteBoxFromDisk(name);
          debugPrint('[DB] 已删除 box: $name');
        }
        final reopened = await Hive.openBox('general_settings');
        await reopened.put('schema_version', _kSchemaVersion);
        await reopened.close();
      } else {
        await box.close();
      }
    } catch (e) {
      debugPrint('[DB] 迁移检查失败: $e');
    }
  }

  void _registerAdapters() {
    final adapters = <TypeAdapter>[
      PhotoAdapter(),
      DiaryEntryAdapter(),
      WeeklySummaryAdapter(),
      MonthlyDiaryAdapter(),
      QuoteAdapter(),
    ];
    for (final adapter in adapters) {
      try {
        Hive.registerAdapter(adapter);
      } catch (_) {}
    }
  }

  Future<List<Box>> _openBoxes() async {
    final boxes = <String, Box Function()>{
      'photos': () => Hive.box<Photo>('photos'),
      'diary_entries': () => Hive.box<DiaryEntry>('diary_entries'),
      'monthly_diaries': () => Hive.box<MonthlyDiary>('monthly_diaries'),
      'quotes': () => Hive.box<Quote>('quotes'),
      'general_settings': () => Hive.box('general_settings'),
      'scene_tags': () => Hive.box<String>('scene_tags'),
    };
    final openers = <String, Future<Box> Function()>{
      'photos': () => Hive.openBox<Photo>('photos'),
      'diary_entries': () => Hive.openBox<DiaryEntry>('diary_entries'),
      'monthly_diaries': () => Hive.openBox<MonthlyDiary>('monthly_diaries'),
      'quotes': () => Hive.openBox<Quote>('quotes'),
      'general_settings': () => Hive.openBox('general_settings'),
      'scene_tags': () => Hive.openBox<String>('scene_tags'),
    };

    final results = <Box>[];
    for (final name in boxes.keys) {
      try {
        if (Hive.isBoxOpen(name)) {
          results.add(boxes[name]!());
        } else {
          results.add(await openers[name]!());
        }
      } catch (e) {
        debugPrint('[DB] 打开盒子 $name 失败: $e，尝试删除后重建');
        if (Hive.isBoxOpen(name)) {
          await Hive.box(name).close();
        }
        await _deleteBoxFile(name);
        results.add(await openers[name]!());
      }
    }
    return results;
  }

  Future<void> _deleteBoxFile(String name) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final boxFile = File('${appDocDir.path}/$name.hive');
      if (await boxFile.exists()) {
        await boxFile.delete();
        debugPrint('[DB] 已删除损坏的盒子文件: $name.hive');
      }
      final lockFile = File('${appDocDir.path}/$name.lock');
      if (await lockFile.exists()) {
        await lockFile.delete();
      }
    } catch (_) {}
  }

  Future<void> startScanning({bool forceScan = false}) async {
    if (_isScanning) return;
    if (_scanningComplete && !forceScan) return;

    if (!_photoScanner.hasPermission) {
      _permissionStatus = await _photoScanner.requestPermission();
      _notifyNow();
      if (!_photoScanner.hasPermission) {
        debugPrint('[DB] 无相册权限，取消扫描');
        return;
      }
    }

    _isScanning = true;
    _scannedCount = 0;
    _scanTotal = 0;
    _scanningComplete = false;
    _notifyNow();
    if (forceScan) {
      debugPrint('[DB] 强制重新扫描开始');
    }

    try {
      final existing = <String, Photo>{
        for (final photo in _repository.getAllPhotos()) photo.id: photo,
      };
      await _photoScanner.scanDevicePhotos(
        existing: existing,
        force: forceScan,
        onTotal: (total) {
          _scanTotal = total;
          _notifyThrottled();
        },
        onProgress: (processed) {
          _scannedCount = processed;
          _notifyThrottled();
        },
        onBatch: (batch) {
          _repository.savePhotosBatch(batch);
          _notifyThrottled();
        },
      );
      _scanningComplete = true;
    } catch (e) {
      debugPrint('[DB] 扫描设备照片失败: $e');
    } finally {
      _isScanning = false;
      if (_scanningComplete) {
        _scannedCount = _repository.getAllPhotos().length;
      }
      _notifyNow();
      debugPrint('[DB] 扫描结束，共 ${_repository.getAllPhotos().length} 张照片');
      // 扫描完再补场景词：后台串行、限时，不阻塞首页
      if (_scanningComplete) {
        unawaited(SceneClassifier.instance.warmUp());
      }
    }
  }

  /// 立即通知订阅者（扫描开始/完成/权限变化）。
  void _notifyNow() {
    _notifyTimer?.cancel();
    _notifyTimer = null;
    _lastNotify = DateTime.now();
    notifyListeners();
  }

  /// 批次/进度通知，至少间隔 [_notifyThrottle]，保证 ≤1 次/500ms。
  void _notifyThrottled() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastNotify);
    if (elapsed >= _notifyThrottle) {
      _notifyNow();
      return;
    }
    if (_notifyTimer != null) return;
    _notifyTimer = Timer(_notifyThrottle - elapsed, () {
      _notifyTimer = null;
      _lastNotify = DateTime.now();
      notifyListeners();
    });
  }

  LocalRepository get repository => _repository;

  Future<PhotoPermissionStatus> requestPhotoPermission() async {
    _permissionStatus = await _photoScanner.requestPermission();
    _notifyNow();
    return _permissionStatus;
  }

  @override
  void dispose() {
    _notifyTimer?.cancel();
    _notifyTimer = null;
    super.dispose();
    // 单例通常不会销毁，这里仅保持原有的关闭行为
    unawaited(Hive.close().catchError((Object _) {}));
  }
}
