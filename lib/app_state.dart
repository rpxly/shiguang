import 'package:flutter/material.dart';
import 'models/photo.dart';

class AppState extends ChangeNotifier {
  Photo? _selectedPhoto;
  bool _showPhotoDetail = false;
  bool _showSettings = false;
  bool _showCleanup = false;
  bool _showCurated = false;
  int _dataVersion = 0;

  Photo? get selectedPhoto => _selectedPhoto;
  bool get showPhotoDetail => _showPhotoDetail;
  bool get showSettings => _showSettings;
  bool get showCleanup => _showCleanup;
  bool get showCurated => _showCurated;
  int get dataVersion => _dataVersion;

  void notifyDataChanged() {
    _dataVersion++;
    notifyListeners();
  }

  void selectPhoto(Photo photo) {
    _selectedPhoto = photo;
    _showPhotoDetail = true;
    notifyListeners();
  }

  void closePhotoDetail() {
    _showPhotoDetail = false;
    _selectedPhoto = null;
    notifyListeners();
  }

  void showSettingsPage() {
    _showSettings = true;
    notifyListeners();
  }

  void closeSettingsPage() {
    _showSettings = false;
    notifyListeners();
  }

  void showCleanupPage() {
    _showCleanup = true;
    notifyListeners();
  }

  void closeCleanupPage() {
    _showCleanup = false;
    notifyListeners();
  }

  void showCuratedPage() {
    _showCurated = true;
    notifyListeners();
  }

  void closeCuratedPage() {
    _showCurated = false;
    notifyListeners();
  }
}
