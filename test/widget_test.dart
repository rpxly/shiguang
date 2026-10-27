import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang/app_state.dart';

void main() {
  test('AppState initializes correctly', () {
    final appState = AppState();
    expect(appState.selectedPhoto, isNull);
    expect(appState.showPhotoDetail, isFalse);
    expect(appState.showSettings, isFalse);
    expect(appState.showCleanup, isFalse);
    expect(appState.showCurated, isFalse);
    expect(appState.dataVersion, 0);
  });

  // 数据变更通知应递增 dataVersion，用于驱动界面刷新
  test('notifyDataChanged increments dataVersion', () {
    final appState = AppState();
    appState.notifyDataChanged();
    expect(appState.dataVersion, 1);
    appState.notifyDataChanged();
    expect(appState.dataVersion, 2);
  });
}
