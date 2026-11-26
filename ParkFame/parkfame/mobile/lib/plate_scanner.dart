import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class ScanResult {
  final XFile image;
  final String? plate;
  final bool sure; // true when the text matches a known plate layout exactly
  ScanResult(this.image, this.plate, {this.sure = false});
}

class PlateRead {
  final String plate;
  final bool sure;
  PlateRead(this.plate, this.sure);
}

class _Cand {
  final String text; // letters + digits only
  final double height; // text height in the photo (plates are the biggest text)
  _Cand(this.text, this.height);
}

class _Fit {
  final String text;
  final int fixes;
  _Fit(this.text, this.fixes);
}

/// Takes a photo and reads the plate text on-device (Google ML Kit, works offline).
class PlateScanner {
  final _picker = ImagePicker();
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<ScanResult?> scan({ImageSource source = ImageSource.camera}) async {
    // Higher resolution than before = noticeably better character recognition.
    final img = await _picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
    if (img == null) return null;
    final text = await _recognizer.processImage(InputImage.fromFilePath(img.path));
    final read = extractPlate(text);
    return ScanResult(img, read?.plate, sure: read?.sure ?? false);
  }

  void dispose() => _recognizer.close();

  // L = letter, D = digit
  static const _templates = <String, int>{
    'LLLDDDL': 100, // UBF 123K  (current Uganda format)
    'LLLDDD': 90, // UAB 123   (older format)
  };
  // characters OCR commonly mixes up
  static const _toLetter = <String, String>{'0': 'O', '1': 'I', '5': 'S', '8': 'B', '2': 'Z', '6': 'G'};
  static const _toDigit = <String, String>{'O': '0', 'Q': '0', 'D': '0', 'I': '1', 'L': '1', 'S': '5', 'B': '8', 'Z': '2', 'G': '6'};
  static const _noiseWords = <String>['UGANDA', 'KENYA', 'TANZANIA', 'RWANDA'];

  static bool _isLetter(String c) {
    final u = c.codeUnitAt(0);
    return u >= 65 && u <= 90;
  }

  static bool _isDigit(String c) {
    final u = c.codeUnitAt(0);
    return u >= 48 && u <= 57;
  }

  static String _clean(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static String _stripNoise(String s) {
    var out = s;
    for (final w in _noiseWords) {
      if (out.startsWith(w) && out.length >= w.length + 4) out = out.substring(w.length);
    }
    return out;
  }

  /// Fits a window of text to a layout, repairing look-alike characters (O/0, I/1, S/5, B/8 ...).
  static _Fit? _fit(String w, String tpl) {
    if (w.length != tpl.length) return null;
    final b = StringBuffer();
    var fixes = 0;
    for (var i = 0; i < w.length; i++) {
      final c = w[i];
      if (tpl[i] == 'L') {
        if (_isLetter(c)) {
          b.write(c);
        } else if (_toLetter.containsKey(c)) {
          b.write(_toLetter[c]);
          fixes++;
        } else {
          return null;
        }
      } else {
        if (_isDigit(c)) {
          b.write(c);
        } else if (_toDigit.containsKey(c)) {
          b.write(_toDigit[c]);
          fixes++;
        } else {
          return null;
        }
      }
    }
    return _Fit(b.toString(), fixes);
  }

  static PlateRead? extractPlate(RecognizedText t) {
    final lines = <TextLine>[
      for (final b in t.blocks) ...b.lines,
    ];
    var maxH = 1.0;
    for (final l in lines) {
      if (l.boundingBox.height > maxH) maxH = l.boundingBox.height;
    }

    final cands = <_Cand>[];
    for (var i = 0; i < lines.length; i++) {
      final h = lines[i].boundingBox.height.toDouble();
      cands.add(_Cand(_stripNoise(_clean(lines[i].text)), h));
      if (i + 1 < lines.length) {
        // plates printed on two rows (motorcycles, some trucks)
        final h2 = lines[i + 1].boundingBox.height.toDouble();
        cands.add(_Cand(_stripNoise(_clean(lines[i].text + lines[i + 1].text)), h > h2 ? h : h2));
      }
    }
    cands.add(_Cand(_stripNoise(_clean(t.text)), 0));

    String? best;
    var bestScore = 0.0;
    var bestFixes = 0;
    for (final c in cands) {
      if (c.text.length < 4) continue;
      final hb = (c.height / maxH) * 20;

      // 1) known layouts, searched inside the text so stray words/characters do not matter
      _templates.forEach((tpl, base) {
        // more than one spare character means this is probably a longer plate: leave it to the generic rule below
        if (c.text.length - tpl.length > 1) return;
        for (var i = 0; i + tpl.length <= c.text.length; i++) {
          final f = _fit(c.text.substring(i, i + tpl.length), tpl);
          if (f == null) continue;
          final score = base - f.fixes * 20 - (c.text.length - tpl.length) * 10 + hb;
          if (score > bestScore) {
            bestScore = score;
            best = f.text;
            bestFixes = f.fixes;
          }
        }
      });

      // 2) any other letters+digits plate, including long ones (up to 20 characters)
      if (c.text.length <= 20) {
        var hasL = false, hasD = false;
        for (var i = 0; i < c.text.length; i++) {
          if (_isLetter(c.text[i])) hasL = true;
          if (_isDigit(c.text[i])) hasD = true;
        }
        if (hasL && hasD) {
          final score = 40 + (c.text.length > 10 ? 10 : c.text.length) + hb;
          if (score > bestScore) {
            bestScore = score;
            best = c.text;
            bestFixes = 1; // not a known layout: always ask the attendant to compare with the photo
          }
        }
      }
    }
    if (best == null || bestScore < 45) return null;
    return PlateRead(best!, bestScore >= 85 && bestFixes == 0);
  }
}
