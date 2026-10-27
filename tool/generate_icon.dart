import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final sourcePath = 'f:\\daima\\ai-album\\logo.png';
  final dir = Directory('android/app/src/main/res');

  final sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  final sourceImage = img.decodePng(File(sourcePath).readAsBytesSync());
  if (sourceImage == null) {
    print('Error: Failed to read source image');
    return;
  }

  for (final entry in sizes.entries) {
    final size = entry.value;
    final resized = img.copyResize(sourceImage, width: size, height: size);
    for (final name in ['ic_launcher.png', 'ic_launcher_foreground.png']) {
      final path = '${dir.path}/${entry.key}/$name';
      File(path).writeAsBytesSync(img.encodePng(resized));
      final file = File(path);
      print('Generated: ${entry.key}/$name (${size}x${size}, ${file.lengthSync()} bytes)');
    }
  }
  print('All icons regenerated!');
}