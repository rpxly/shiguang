import '../models/photo.dart';

/// 按拍摄月份分组的结果。
///
/// 可被页面与测试共用；不依赖任何 Flutter 或存储实现。
class MonthGroup {
  /// 分组键，格式为 `'$year-$month'`。
  final String key;

  /// 展示标签，格式为 `'$year年$month月'`。
  final String label;

  final List<Photo> photos;

  MonthGroup({required this.key, required this.label, required this.photos});
}

/// 单次遍历按月份分组，返回按 key 降序排列的分组列表。
///
/// 组内照片保持传入顺序，不修改入参集合。
List<MonthGroup> groupPhotosByMonth(Iterable<Photo> photos) {
  final groupMap = <String, MonthGroup>{};
  for (final photo in photos) {
    final key = '${photo.dateTime.year}-${photo.dateTime.month}';
    final group = groupMap[key];
    if (group != null) {
      group.photos.add(photo);
    } else {
      groupMap[key] = MonthGroup(
        key: key,
        label: '${photo.dateTime.year}年${photo.dateTime.month}月',
        photos: [photo],
      );
    }
  }
  return groupMap.values.toList()..sort((a, b) => b.key.compareTo(a.key));
}
