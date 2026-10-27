import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shiguang/models/album.dart';
import 'package:shiguang/models/diary.dart';
import 'package:shiguang/models/photo.dart';
import 'package:shiguang/models/quote.dart';
import 'package:shiguang/models/scene_tag.dart';
import 'package:shiguang/repository/local_repository.dart';

void main() {
  late Directory tempDir;
  late Box<Photo> photoBox;
  late Box<DiaryEntry> diaryEntryBox;
  late Box<MonthlyDiary> monthlyDiaryBox;
  late Box generalBox;
  late Box<Quote> quoteBox;
  late Box<String> sceneBox;
  late LocalRepository repository;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('shiguang_album_test');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter<Photo>(PhotoAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter<DiaryEntry>(DiaryEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter<WeeklySummary>(WeeklySummaryAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter<MonthlyDiary>(MonthlyDiaryAdapter());
    }
    if (!Hive.isAdapterRegistered(19)) {
      Hive.registerAdapter<Quote>(QuoteAdapter());
    }

    photoBox = await Hive.openBox<Photo>('photos');
    diaryEntryBox = await Hive.openBox<DiaryEntry>('diary_entries');
    monthlyDiaryBox = await Hive.openBox<MonthlyDiary>('monthly_diaries');
    generalBox = await Hive.openBox('general_settings');
    quoteBox = await Hive.openBox<Quote>('quotes');
    sceneBox = await Hive.openBox<String>('scene_tags');
  });

  setUp(() async {
    await photoBox.clear();
    await diaryEntryBox.clear();
    await monthlyDiaryBox.clear();
    await generalBox.clear();
    await quoteBox.clear();
    await sceneBox.clear();

    repository = LocalRepository(
      photoBox: photoBox,
      diaryEntryBox: diaryEntryBox,
      monthlyDiaryBox: monthlyDiaryBox,
      generalBox: generalBox,
      sceneBox: sceneBox,
    );
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('待应用队列：入队去重、按相簿计数、单项移除', () {
    repository.addPendingMove('a1', 'p1');
    repository.addPendingMove('a1', 'p1');
    repository.addPendingMove('a1', 'p2');
    repository.addPendingMove('a2', 'p3');

    expect(repository.getPendingMoves()['a1'], ['p1', 'p2']);
    expect(repository.getPendingCounts(), {'a1': 2, 'a2': 1});
    expect(repository.totalPendingCount, 3);

    repository.removePendingMoves('a1', ['p1']);
    expect(repository.getPendingMoves()['a1'], ['p2']);

    repository.clearPendingFor('a2');
    expect(repository.getPendingMoves().containsKey('a2'), isFalse);
    expect(repository.totalPendingCount, 1);
  });

  test('场景记录：写入可读回，清空后不再命中', () {
    repository.saveSceneRecord(
      'p1',
      const SceneRecord(tag: SceneTag(label: '餐厅', confidence: 0.8)),
    );
    expect(repository.getSceneRecord('p1')?.validTag?.label, '餐厅');
    expect(repository.sceneRecordCount, 1);

    repository.saveSceneRecord('p2', const SceneRecord());
    expect(repository.getSceneRecord('p2')?.validTag, isNull);
    expect(repository.sceneRecordCount, 2);

    repository.clearSceneRecords();
    expect(repository.getSceneRecord('p1'), isNull);
    expect(repository.sceneRecordCount, 0);
  });

  test('删除照片时从所有相簿队列里摘除，避免残留死 id', () {
    repository.addPendingMove('a1', 'p1');
    repository.addPendingMove('a1', 'p2');
    repository.addPendingMove('a2', 'p2');

    repository.removeFromPendingEverywhere(['p2']);

    expect(repository.getPendingMoves()['a1'], ['p1']);
    expect(repository.getPendingMoves().containsKey('a2'), isFalse);

    repository.deletePhotoRecordOnly('p1');
    expect(repository.getPendingMoves().containsKey('a1'), isFalse);
  });

  test('移动清单：记录原始目录并可回读、清理', () {
    repository.saveMoveManifest(
      batchId: 'b1',
      albumId: 'a1',
      originalPaths: {
        'p1': 'DCIM/Camera',
        'p2': 'Pictures/Screenshots',
      },
    );

    final manifest = repository.getLatestMoveManifest();
    expect(manifest, isNotNull);
    expect(manifest!['batchId'], 'b1');
    final items = (manifest['items'] as Map).cast<String, String>();
    expect(items['p1'], 'DCIM/Camera');
    expect(items['p2'], 'Pictures/Screenshots');

    repository.clearMoveManifest();
    expect(repository.getLatestMoveManifest(), isNull);
  });

  test('迁移：旧相簿 id 列表转待应用队列，空壳相簿被清理且只跑一次', () {
    repository.saveAlbum(Album(id: 'a1', name: '有照片'));
    repository.saveAlbum(Album(id: 'a2', name: 'QQ'));
    generalBox.put('album_photos_a1', ['p1', 'p2']);
    generalBox.put('album_photos_a2', <String>[]);

    repository.migrateLegacyAlbumPhotos();

    expect(repository.getPendingMoves()['a1'], ['p1', 'p2']);
    expect(repository.getPendingMoves().containsKey('a2'), isFalse);
    expect(repository.getAllAlbums().map((a) => a.id).toList(), ['a1']);
    expect(generalBox.get('album_photos_a1'), isNull);
    expect(generalBox.get('album_photos_migrated'), isTrue);

    // 幂等：再次调用不会重复迁移
    generalBox.put('album_photos_a1', ['p3']);
    repository.migrateLegacyAlbumPhotos();
    expect(repository.getPendingMoves()['a1'], ['p1', 'p2']);
  });

  test('Album 序列化保留 relativePath，isPhysical 判定正确', () {
    final physical = Album(
      id: 'x',
      name: '旅行',
      relativePath: 'Pictures/拾光/旅行',
      isLocalSync: true,
    );
    final restored = Album.fromJson(
      jsonDecode(jsonEncode(physical.toJson())) as Map<String, dynamic>,
    );
    expect(restored.relativePath, 'Pictures/拾光/旅行');
    expect(restored.isPhysical, isTrue);

    final draft = Album(id: 'y', name: '草稿');
    expect(draft.isPhysical, isFalse);
    expect(draft.relativePath, isNull);
  });
}
