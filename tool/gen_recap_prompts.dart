// 生成端侧 AI 提示词离线验证用的 ChatML 文件。
//
// 运行：dart run tool/gen_recap_prompts.dart
// 产出：.poc/prompts/01_rich.txt … 05_night.txt（与线上 RecapPromptBuilder 完全同源）
//
// 场景设计对应真机验证的发现：
// 01 丰富（多场景/地点/人脸/收藏/步数）—— 理想情况
// 02 稀疏（无场景/地点/人脸，只有数量与天数）—— iPlay80Mini 实测形态
// 03 单张照片 —— 最小输入
// 04 旅行月（山野+海边+地名）—— 叙事最该出彩的场景
// 05 夜间居多 —— 兜底链最后一级
import 'dart:io';

import 'package:shiguang/models/photo.dart';
import 'package:shiguang/services/monthly_recap_service.dart';
import 'package:shiguang/services/on_device_ai_service.dart';

Photo _p(int day, int hour, {String? scene, bool face = false, bool fav = false}) {
  return Photo(
    id: 'p${day}_$hour',
    path: '/tmp/x.jpg',
    thumbnailPath: '/tmp/t.jpg',
    date: DateTime(2026, 10, day, hour),
    fileSize: 1024,
    hasFace: face,
    isFavorite: fav,
  );
}

void _write(String name, PromptBundle prompt) {
  final dir = Directory('.poc/prompts');
  dir.createSync(recursive: true);
  File('${dir.path}/$name.txt').writeAsStringSync(prompt.toChatMl());
  stdout.writeln('写入 $name.txt');
}

void main() {
  const recap = MonthlyRecapService();
  const builder = RecapPromptBuilder();

  MonthlyFacts facts(
    List<Photo> photos, {
    required int year,
    required int month,
  }) {
    return recap.collectFacts(
      photos,
      year: year,
      month: month,
      sceneOf: (id) => id.contains('S') ? null : null,
      placeOf: (loc) => loc,
    );
  }

  // 01 丰富月：8 张海边、4 张咖啡厅、6 张有人脸、5 张精选、步数 18 万
  final rich = <Photo>[
    for (var i = 1; i <= 8; i++) _p(i * 3 % 28 + 1, 14, face: i <= 3, fav: i <= 2),
    for (var i = 1; i <= 4; i++) _p(i * 2, 10),
  ];
  final richFacts = recap.collectFacts(
    rich,
    year: 2026,
    month: 10,
    sceneOf: (id) => id.endsWith('_14') && int.parse(id.split('_')[1].substring(1)) <= 24 ? '海边' : '咖啡厅',
    placeOf: (loc) => loc,
  );

  // 02 稀疏月：真机实测形态，16 张全无任何场景线索
  final sparse = <Photo>[for (var i = 1; i <= 16; i++) _p(i % 3 == 0 ? 26 : 6, 15)];
  final sparseFacts = facts(sparse, year: 2026, month: 10);

  // 03 单张照片
  final singleFacts = facts([_p(26, 17)], year: 2026, month: 10);

  // 04 旅行月：山野/海边 + 地名 + 人脸
  final trip = <Photo>[for (var i = 1; i <= 30; i++) _p(i % 30 + 1, 16, face: i % 5 == 0)];
  final tripFacts = recap.collectFacts(
    trip,
    year: 2026,
    month: 10,
    sceneOf: (id) => int.parse(id.split('_')[0].substring(1)) <= 15 ? '山野' : '海边',
    placeOf: (loc) => loc,
  );

  // 05 夜间居多
  final night = <Photo>[
    for (var i = 1; i <= 10; i++) _p(i * 2, 21),
    for (var i = 1; i <= 4; i++) _p(i, 10),
  ];
  final nightFacts = facts(night, year: 2026, month: 10);

  for (final e in {
    '01_rich': richFacts,
    '02_sparse': sparseFacts,
    '03_single': singleFacts,
    '04_trip': tripFacts,
    '05_night': nightFacts,
  }.entries) {
    _write(e.key, builder.build(NarrationRequest(
      facts: e.value,
      mood: '平静',
      weather: '晴',
      steps: e.key == '01_rich' ? 186000 : 0,
    )));
    // Qwen3 的 soft switch：no_think 变体，验证思考模式对产出/速度的影响
    final noThink = builder.build(NarrationRequest(
      facts: e.value,
      mood: '平静',
      weather: '晴',
      steps: e.key == '01_rich' ? 186000 : 0,
    ));
    _write('${e.key}_nothink', _withNoThink(noThink));
  }
}

/// 在 user 消息末尾追加 Qwen3 的 /no_think 软开关。
PromptBundle _withNoThink(PromptBundle p) {
  final user = '${p.user}\n/no_think';
  return PromptBundle(system: p.system, user: user);
}
