import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang/components/glass_card.dart';

/// 回归守卫：GlassCard 的描边必须能在 paint 阶段画出来。
///
/// 历史问题（2026-10-27）：`foregroundDecoration` 同时给了 `borderRadius` 和
/// 上下颜色不同的 `Border`，Flutter 会抛
/// `A borderRadius can only be given on borders with uniform colors`。
/// 因为 GlassCard 是全站卡片的基座，这一条断言会把整片界面打成异常。
void main() {
  testWidgets('GlassCard 能正常绘制，不抛 paint 断言', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GlassCard(
              child: const Text('内容', style: TextStyle(fontSize: 14)),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('内容'), findsOneWidget);
  });

  testWidgets('渐变卡片同样可绘制', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GlassCard(
              gradient: const LinearGradient(colors: [Colors.blue, Colors.purple]),
              child: const Text('渐变', style: TextStyle(fontSize: 14)),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('渐变'), findsOneWidget);
  });
}
