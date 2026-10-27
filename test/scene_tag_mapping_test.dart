import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang/models/scene_tag.dart';
import 'package:shiguang/services/scene_classifier_service.dart';

void main() {
  final classifier = SceneClassifier.instance;

  group('场景词映射', () {
    test('单一强标签直接得出场景', () {
      final tag = classifier.tagFromLabels({'Restaurant': 0.85});
      expect(tag?.label, '餐厅');
    });

    test('场景证据压过泛化的人像标签', () {
      final tag = classifier.tagFromLabels({'Beach': 0.8, 'People': 0.92});
      expect(tag?.label, '海边');
    });

    test('没有任何场景线索时回落到人像', () {
      final tag = classifier.tagFromLabels({'People': 0.9, 'Smile': 0.8});
      expect(tag?.label, '人像');
    });

    test('低置信度不产生场景词', () {
      expect(classifier.tagFromLabels({'Beach': 0.45}), isNull);
    });

    test('空标签集合不产生场景词', () {
      expect(classifier.tagFromLabels({}), isNull);
    });

    test('按词边界匹配，Season/Parking 不会误判成海边/公园', () {
      expect(classifier.tagFromLabels({'Season': 0.95, 'Parking': 0.9}), isNull);
    });

    test('复数标签同样命中', () {
      expect(classifier.tagFromLabels({'Buildings': 0.7})?.label, '街头');
    });

    test('咖啡场景优先于泛化美食标签', () {
      final tag = classifier.tagFromLabels({'Cafe': 0.78, 'Food': 0.6});
      expect(tag?.label, '咖啡厅');
    });

    test('展馆标签不会被街头标签抢走', () {
      final tag = classifier.tagFromLabels({'Museum': 0.7, 'Building': 0.72});
      expect(tag?.label, '展馆');
    });
  });

  group('地点可读性', () {
    test('原始 GPS 坐标不算地点', () {
      expect(SceneClassifier.readablePlace('31.2304, 121.4737'), isNull);
      expect(SceneClassifier.readablePlace(' -33.8688 , 151.2093 '), isNull);
    });

    test('真正的地名照常显示', () {
      expect(SceneClassifier.readablePlace('  朝阳公园 '), '朝阳公园');
    });

    test('空值不显示', () {
      expect(SceneClassifier.readablePlace(null), isNull);
      expect(SceneClassifier.readablePlace('   '), isNull);
    });
  });

  group('场景记录落盘', () {
    test('编解码保持标签与置信度', () {
      const record = SceneRecord(
        tag: SceneTag(label: '餐厅', confidence: 0.82, rawLabels: ['Restaurant']),
      );
      final decoded = SceneRecord.tryDecode(record.encode());
      expect(decoded?.validTag?.label, '餐厅');
      expect(decoded?.validTag?.confidence, closeTo(0.82, 1e-9));
      expect(decoded?.validTag?.rawLabels, ['Restaurant']);
    });

    test('「识别过但没结论」也能落盘，避免重复推理', () {
      final decoded = SceneRecord.tryDecode(const SceneRecord().encode());
      expect(decoded, isNotNull);
      expect(decoded?.validTag, isNull);
    });

    test('旧版本记录视为过期，等待重算', () {
      final decoded = SceneRecord.tryDecode('{"v":0,"label":"餐厅","conf":0.9}');
      expect(decoded?.isUpToDate, isFalse);
      expect(decoded?.validTag, isNull);
    });

    test('损坏的记录不会崩', () {
      expect(SceneRecord.tryDecode('not-json'), isNull);
      expect(SceneRecord.tryDecode(null), isNull);
    });
  });
}
