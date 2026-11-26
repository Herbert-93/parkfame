import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../plate_scanner.dart';
import '../theme.dart';
import '../utils.dart';

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

  // Step 1: what is parking?  'bike' | 'car' | 'lorry'
  String? _type;

  bool _scanning = false, _busy = false;
  String? _hint, _err;
  bool _hintOk = false;
  String? _detected; // what the scanner read
  bool _manual = false; // only unlocked after a failed scan

  // Back-dating: the car was already parked before it was logged in the app
  bool _backdate = false;
  DateTime? _entryAt;

  // Only three vehicle types. 'small' is the stored rate key for Car.
  String get _size => _type == 'bike' ? 'motorcycle' : (_type == 'lorry' ? 'truck' : 'small');

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
          if (r.sure) {
            _hint = 'Plate read by the scanner and locked. Wrong? Retake the photo.';
            _hintOk = true;
          } else {
            _hint = 'Read as ${r.plate}. Compare it with the photo - if it is not exactly right, retake the photo.';
            _hintOk = false;
          }
        } else {
          _plate.clear();
          _hint = 'Could not read the plate. Retake the photo (get closer, avoid glare), or enter it manually (this is flagged to your admin).';
          _hintOk = false;
        }
      });
    } catch (e) {
      setState(() => _err = 'Camera error: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _pickEntry() async {
    final now = DateTime.now();
    final start = _entryAt ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: start.isAfter(now) ? now : start,
      firstDate: now.subtract(const Duration(days: 400)),
      lastDate: now,
      helpText: 'Date the car arrived',
    );
    if (d == null || !mounted) {
      if (_entryAt == null && mounted) setState(() => _backdate = false);
      return;
    }
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start), helpText: 'Time the car arrived');
    if (t == null || !mounted) {
      if (_entryAt == null && mounted) setState(() => _backdate = false);
      return;
    }
    var dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    if (dt.isAfter(now)) dt = now;
    setState(() => _entryAt = dt);
  }

  Future<void> _submit() async {
    final plate = _plate.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (_type == null) return setState(() => _err = 'Choose what is parking: Bike, Car or Lorry.');
    if (_bytes == null) return setState(() => _err = 'Take a photo of the number plate first.');
    if (!_manual && _detected == null) return setState(() => _err = 'Scan the number plate first.');
    if (plate.length < 3 || plate.length > 20) return setState(() => _err = 'Enter a valid number plate (3 to 20 letters/digits).');
    if (_backdate && _entryAt == null) return setState(() => _err = 'Choose the time the car arrived.');
    if (base64Encode(_bytes!).length > 880000) return setState(() => _err = 'The photo is too large. Retake it a little further from the plate.');
    setState(() {
      _busy = true;
      _err = null;
    });
    final state = context.read<AppState>();
    try {
      // saved on the phone first, then sent; on a weak connection it keeps sending in the background
      final sent = await state.submitCheckIn(
        plate: plate,
        size: _size,
        ownerName: _name.text.trim(),
        ownerPhone: _phone.text.trim(),
        photo: _bytes!,
        plateSource: _manual ? 'manual' : 'scan',
        detectedPlate: _detected,
        entryAt: _backdate ? _entryAt : null,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: sent ? Brand.accent : Brand.amber,
        duration: Duration(seconds: sent ? 3 : 6),
        content: Text(sent ? '$plate logged in ✔' : '$plate saved on this phone - it will send when the signal is back',
            style: const TextStyle(color: Brand.navy, fontWeight: FontWeight.w700)),
      ));
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(color: Brand.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
      );

  @override
  Widget build(BuildContext context) {
    final lot = context.read<AppState>().lot!;
    final rates = lot.rates;
    return Scaffold(
      appBar: AppBar(title: const Text('Log vehicle in')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ---- Step 1: what is parking? ------------------------------------
          _label('1 · WHAT IS PARKING?'),
          Row(children: [
            Expanded(child: _typeTile('bike', 'Bike', Icons.two_wheeler_rounded, ugx(rates.sizes['motorcycle']!.ratePerBlock))),
            const SizedBox(width: 10),
            Expanded(child: _typeTile('car', 'Car', Icons.directions_car_rounded, ugx(rates.sizes['small']!.ratePerBlock))),
            const SizedBox(width: 10),
            Expanded(child: _typeTile('lorry', 'Lorry', Icons.local_shipping_rounded, ugx(rates.sizes['truck']!.ratePerBlock))),
          ]),
          const SizedBox(height: 22),

          // ---- Step 2: scan the plate ---------------------------------------
          if (_type != null) ...[
            _label('2 · SCAN THE NUMBER PLATE'),
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
                      Text('Tap to open the camera · fill the frame with the plate', style: TextStyle(color: Brand.muted, fontSize: 12)),
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
          ],

          // ---- Step 3: the rest ---------------------------------------------
          if (_type != null && _bytes != null) ...[
            _label('3 · NUMBER PLATE'),
            TextField(
              controller: _plate,
              readOnly: !_manual,
              maxLength: 20,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 3),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
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
            if (_detected == null && !_manual) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _manual = true;
                  _hint = 'Manual entry: type the plate exactly as on the vehicle. Your admin will see this flagged.';
                  _hintOk = false;
                }),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Scan failed - enter plate manually'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), foregroundColor: Brand.amber, side: const BorderSide(color: Brand.amber), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Billed per ${rates.blockHours} hours · ${rates.overstayHours % 1 == 0 ? rates.overstayHours.toInt() : rates.overstayHours}h late-pickup window before the next block · first ${rates.graceMinutes} min free',
              style: const TextStyle(color: Brand.muted, fontSize: 12),
            ),
            const SizedBox(height: 22),
            _label('ARRIVAL TIME'),
            Container(
              decoration: BoxDecoration(color: Brand.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                SwitchListTile(
                  value: _backdate,
                  title: const Text('Already parked before today', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Back-date vehicles that were in the lot before the app started', style: TextStyle(color: Brand.muted, fontSize: 12)),
                  onChanged: (v) {
                    setState(() {
                      _backdate = v;
                      if (!v) _entryAt = null;
                    });
                    if (v) _pickEntry();
                  },
                ),
                if (_backdate && _entryAt != null)
                  ListTile(
                    leading: const Icon(Icons.schedule_rounded, color: Brand.amber),
                    title: Text('Arrived ${timeText(_entryAt!)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Tap to change · flagged to your admin', style: TextStyle(color: Brand.muted, fontSize: 12)),
                    onTap: _pickEntry,
                  ),
              ]),
            ),
            const SizedBox(height: 22),
            _label('OWNER (OPTIONAL)'),
            TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Owner name', prefixIcon: Icon(Icons.person_outline_rounded))),
            const SizedBox(height: 10),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'Phone number', prefixIcon: Icon(Icons.phone_outlined))),
          ],
          if (_err != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_err!, style: const TextStyle(color: Brand.danger), textAlign: TextAlign.center)),
          if (_type != null && _bytes != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Icon(Icons.login_rounded),
              label: const Text('Log vehicle in'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _typeTile(String key, String label, IconData icon, String sub) {
    final sel = _type == key;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _type = key),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
        decoration: BoxDecoration(
          color: sel ? Brand.accent.withValues(alpha: .12) : Brand.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: sel ? Brand.accent : Colors.transparent, width: 1.5),
        ),
        child: Column(children: [
          Icon(icon, size: 34, color: sel ? Brand.accent : Brand.muted),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 2),
          Text('$sub / ${context.read<AppState>().lot!.rates.blockHours}h', style: const TextStyle(color: Brand.muted, fontSize: 11), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
