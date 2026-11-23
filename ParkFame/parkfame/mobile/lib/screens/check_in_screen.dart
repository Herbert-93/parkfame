import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../plate_scanner.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/plate_badge.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});
  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _scanner = PlateScanner();
  final _plate = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  Uint8List? _bytes;
  String _size = 'small';
  bool _scanning = false, _busy = false;
  String? _hint, _err;
  bool _hintOk = false;
  String? _detected; // what the scanner read
  bool _manual = false; // only unlocked after a failed scan

  @override
  void dispose() {
    _scanner.dispose();
    _plate.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _err = null;
    });
    try {
      final r = await _scanner.scan();
      if (r == null) return;
      final bytes = await r.image.readAsBytes();
      setState(() {
        _bytes = bytes;
        _manual = false;
        _detected = r.plate;
        if (r.plate != null) {
          _plate.text = r.plate!;
          _hint = 'Plate read by the scanner and locked. Wrong? Retake the photo.';
          _hintOk = true;
        } else {
          _plate.clear();
          _hint = 'Could not read the plate. Retake the photo, or enter it manually (this is flagged to your admin).';
          _hintOk = false;
        }
      });
    } catch (e) {
      setState(() => _err = 'Camera error: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _submit() async {
    final plate = _plate.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (_bytes == null) return setState(() => _err = 'Take a photo of the number plate first.');
    if (!_manual && _detected == null) return setState(() => _err = 'Scan the number plate first.');
    if (plate.length < 3) return setState(() => _err = 'Enter a valid number plate.');
    setState(() {
      _busy = true;
      _err = null;
    });
    final state = context.read<AppState>();
    try {
      await state.api.checkIn(
        plate: plate,
        size: _size,
        lotId: state.lot!.id,
        ownerName: _name.text.trim(),
        ownerPhone: _phone.text.trim(),
        photoBase64: base64Encode(_bytes!),
        plateSource: _manual ? 'manual' : 'scan',
        detectedPlate: _detected,
      );
      await state.refresh();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Brand.accent, content: Text('$plate logged in ✔', style: const TextStyle(color: Brand.navy, fontWeight: FontWeight.w700))));
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lot = context.read<AppState>().lot!;
    final rates = lot.rates;
    return Scaffold(
      appBar: AppBar(title: const Text('Log car in')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          GestureDetector(
            onTap: _scanning ? null : _scan,
            child: Container(
              height: 210,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Brand.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _bytes == null ? Brand.accent.withValues(alpha: .5) : Colors.transparent, width: 1.5),
              ),
              child: Stack(fit: StackFit.expand, children: [
                if (_bytes != null) Image.memory(_bytes!, fit: BoxFit.cover),
                if (_bytes == null)
                  const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.document_scanner_rounded, size: 54, color: Brand.accent),
                    SizedBox(height: 10),
                    Text('Scan number plate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text('Tap to open the camera', style: TextStyle(color: Brand.muted)),
                  ]),
                if (_bytes != null)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.refresh_rounded, size: 16), SizedBox(width: 6), Text('Retake', style: TextStyle(fontWeight: FontWeight.w700))]),
                    ),
                  ),
                if (_scanning) Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator())),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          const Text('NUMBER PLATE', style: TextStyle(color: Brand.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),
          TextField(
            controller: _plate,
            readOnly: !_manual,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 3),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: _manual ? 'Type the plate' : 'Filled by the scanner',
              suffixIcon: _manual ? null : const Icon(Icons.lock_rounded, color: Brand.muted, size: 20),
            ),
          ),
          if (_hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Icon(_hintOk ? Icons.check_circle_rounded : Icons.info_rounded, size: 16, color: _hintOk ? Brand.accent : Brand.amber),
                const SizedBox(width: 6),
                Expanded(child: Text(_hint!, style: TextStyle(fontSize: 12, color: _hintOk ? Brand.accent : Brand.amber))),
              ]),
            ),
          if (_bytes != null && _detected == null && !_manual) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _manual = true;
                _hint = 'Manual entry: type the plate exactly as on the car. Your admin will see this flagged.';
                _hintOk = false;
              }),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Scan failed - enter plate manually'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), foregroundColor: Brand.amber, side: const BorderSide(color: Brand.amber), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ],
          const SizedBox(height: 22),
          const Text('VEHICLE SIZE', style: TextStyle(color: Brand.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),
          for (final k in vehicleSizes) _sizeTile(k, rates),
          const SizedBox(height: 6),
          Text('Billed per ${rates.blockHours} hours · each extra ${rates.blockHours}h repeats the rate · first ${rates.graceMinutes} min free',
              style: const TextStyle(color: Brand.muted, fontSize: 12)),
          const SizedBox(height: 22),
          const Text('OWNER (OPTIONAL)', style: TextStyle(color: Brand.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Owner name', prefixIcon: Icon(Icons.person_outline_rounded))),
          const SizedBox(height: 10),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'Phone number', prefixIcon: Icon(Icons.phone_outlined))),
          if (_err != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_err!, style: const TextStyle(color: Brand.danger), textAlign: TextAlign.center)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Icon(Icons.login_rounded),
            label: const Text('Log car in'),
          ),
        ],
      ),
    );
  }

  Widget _sizeTile(String key, RateConfig rates) {
    final r = rates.sizes[key]!;
    final sel = _size == key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _size = key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: sel ? Brand.accent.withValues(alpha: .12) : Brand.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sel ? Brand.accent : Colors.transparent, width: 1.5),
          ),
          child: Row(children: [
            Icon(sizeIcon(key), color: sel ? Brand.accent : Brand.muted),
            const SizedBox(width: 12),
            Expanded(child: Text(r.label, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(ugx(r.ratePerBlock), style: TextStyle(fontWeight: FontWeight.w800, color: sel ? Brand.accent : Colors.white)),
            Text(' /${rates.blockHours}h', style: const TextStyle(color: Brand.muted, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}
