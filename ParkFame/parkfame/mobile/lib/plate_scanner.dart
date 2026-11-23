import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class ScanResult {
  final XFile image;
  final String? plate;
  ScanResult(this.image, this.plate);
}

/// Takes a photo and reads the plate text on-device (Google ML Kit, works offline).
class PlateScanner {
  final _picker = ImagePicker();
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<ScanResult?> scan({ImageSource source = ImageSource.camera}) async {
    final img = await _picker.pickImage(source: source, maxWidth: 1024, imageQuality: 60);
    if (img == null) return null;
    final text = await _recognizer.processImage(InputImage.fromFilePath(img.path));
    return ScanResult(img, extractPlate(text));
  }

  void dispose() => _recognizer.close();

  static final _patterns = [
    RegExp(r'[A-Z]{2,3}\s?-?\s?\d{3,4}\s?-?\s?[A-Z]?'), // UBA 123X, KCA 123A, UAB 123
    RegExp(r'\d{3,4}\s?-?\s?[A-Z]{2,3}'), // 123 ABC
  ];

  static int _score(String c) => c.length + (c.startsWith('U') ? 2 : 0) + (RegExp(r'^[A-Z]{3}\d{3}[A-Z]$').hasMatch(c) ? 4 : 0);

  static String? extractPlate(RecognizedText t) {
    final haystacks = <String>[
      for (final b in t.blocks) for (final l in b.lines) l.text.toUpperCase(),
      t.text.toUpperCase().replaceAll('\n', ' '), // plates split across two lines
    ];
    final found = <String>{};
    for (final h in haystacks) {
      for (final p in _patterns) {
        for (final m in p.allMatches(h)) {
          found.add(m.group(0)!.replaceAll(RegExp(r'[^A-Z0-9]'), ''));
        }
      }
    }
    if (found.isEmpty) {
      for (final h in haystacks) {
        final s = h.replaceAll(RegExp(r'[^A-Z0-9]'), '');
        if (s.length >= 5 && s.length <= 9 && RegExp(r'[A-Z]').hasMatch(s) && RegExp(r'\d').hasMatch(s)) found.add(s);
      }
    }
    if (found.isEmpty) return null;
    final list = found.toList()..sort((a, b) => _score(b).compareTo(_score(a)));
    return list.first;
  }
}
