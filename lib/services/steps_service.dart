import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// 健康步数服务：读取手机系统健康数据（Android 走 Health Connect）。
///
/// 数据源说明：
/// - Android 14+ 系统内置 Health Connect；旧版本需安装 Health Connect 补丁应用，
///   且手机自带健康 App（小米/华为/OPPO 等）同步到 Health Connect 后才能读到。
/// - iOS 走 HealthKit（本项目当前无 iOS 目录，仅作预留）。
class StepsService {
  static final Health _health = Health();
  static bool _authorized = false;

  static const List<HealthDataType> _types = [HealthDataType.STEPS];

  static Future<bool> _ensureAuthorized() async {
    if (_authorized) return true;
    try {
      if (Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        debugPrint('[StepsService] HealthConnect SDK 状态: $status');
        if (status != HealthConnectSdkStatus.sdkAvailable) {
          debugPrint('[StepsService] HealthConnect 不可用，无法申请权限');
          return false;
        }
      }
      final granted = await _health.requestAuthorization(_types);
      _authorized = granted;
      if (!_authorized) {
        debugPrint('[StepsService] 用户未授予步数读取权限');
      }
      return _authorized;
    } catch (e) {
      debugPrint('[StepsService] 申请健康权限失败: $e');
      return false;
    }
  }

  /// 获取 [year] 年 [month] 月整月总步数。
  /// 成功返回步数；无权限 / 无数据 / 异常返回 null（调用方回退到手动填写）。
  static Future<int?> getMonthlySteps(int year, int month) async {
    try {
      final now = DateTime.now();
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 1).subtract(const Duration(milliseconds: 1));
      // 未来月份 / 本月未开始：无数据可读
      if (start.isAfter(now)) return null;
      final effectiveEnd = end.isAfter(now) ? now : end;

      // 优先直接读取（权限已授予时零打扰）；抛异常（无权限）再走一次授权流程
      try {
        final total = await _readTotal(start, effectiveEnd);
        if (total != null) {
          _authorized = true;
        }
        return total;
      } catch (e) {
        debugPrint('[StepsService] 直接读取失败，尝试申请授权: $e');
        if (!await _ensureAuthorized()) return null;
        return await _readTotal(start, effectiveEnd);
      }
    } catch (e) {
      debugPrint('[StepsService] 读取 $year-$month 步数失败: $e');
      return null;
    }
  }

  static Future<int?> _readTotal(DateTime start, DateTime end) async {
    final total = await _health.getTotalStepsInInterval(start, end);
    debugPrint('[StepsService] $start 至 $end 步数读取: $total');
    return total;
  }

  /// 诊断用：拉取区间内全部原始步数记录，逐条打印（日期 / 数值 / 数据来源）。
  /// 用于排查"手机健康 App 显示的总步数与 Health Connect 不一致"的问题。
  static Future<void> debugDumpRawRecords(DateTime start, DateTime end) async {
    try {
      final points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.STEPS],
        startTime: start,
        endTime: end,
      );
      debugPrint('[StepsService][诊断] 原始记录数: ${points.length}');
      // 按天汇总 + 打印来源分布
      final byDay = <String, int>{};
      final bySource = <String, int>{};
      for (final p in points) {
        final day = '${p.dateFrom.year}-${p.dateFrom.month.toString().padLeft(2, '0')}-${p.dateFrom.day.toString().padLeft(2, '0')}';
        byDay[day] = (byDay[day] ?? 0) + (p.value is NumericHealthValue ? (p.value as NumericHealthValue).numericValue.toInt() : 0);
        bySource[p.sourceName] = (bySource[p.sourceName] ?? 0) + 1;
      }
      final days = byDay.keys.toList()..sort();
      for (final d in days) {
        debugPrint('[StepsService][诊断] $d: ${byDay[d]} 步');
      }
      debugPrint('[StepsService][诊断] 来源分布: $bySource');
    } catch (e) {
      debugPrint('[StepsService][诊断] 拉取原始记录失败: $e');
    }
  }
}
