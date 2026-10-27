import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang/services/image_helper.dart';

void main() {
  group('resolveCacheSize', () {
    test('按逻辑尺寸 × DPR 计算物理像素', () {
      expect(resolveCacheSize(72, 3.0), 216);
    });

    test('DPR 为 1.0 时等于逻辑尺寸', () {
      expect(resolveCacheSize(72, 1.0), 72);
    });

    test('超过 maxPhysical 时夹取到上限', () {
      // 2000 × 3 = 6000，被夹取到 2048
      expect(resolveCacheSize(2000, 3.0, maxPhysical: 2048), 2048);
    });

    test('逻辑尺寸不可用时返回 null（按原图解码）', () {
      expect(resolveCacheSize(null, 3.0), isNull);
      expect(resolveCacheSize(0, 3.0), isNull);
      expect(resolveCacheSize(double.infinity, 3.0), isNull);
      expect(resolveCacheSize(double.nan, 3.0), isNull);
    });
  });
}
