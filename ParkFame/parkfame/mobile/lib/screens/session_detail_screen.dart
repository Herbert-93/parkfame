import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/plate_badge.dart';

class SessionDetailScreen extends StatefulWidget {
  final ParkSession session;
  const SessionDetailScreen({super.key, required this.session});
  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  Quote? _quote;
  String? _photo;
  String _pay = 'cash';
  bool _busy = false;
  String? _err;
  Timer? _timer;
  bool _estimated = false; // price worked out on the phone (no connection)

  ParkSession get s => widget.session;
  bool get parked => s.status == 'parked';

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    if (s.pending) {
      state.localPhoto(s).then((p) => mounted ? setState(() => _photo = p) : null).catchError((_) {});
    } else {
      state.api.photo(s.id).then((p) => mounted ? setState(() => _photo = p) : null).catchError((_) {});
    }
    if (parked) {
      _quote = state.localQuote(s); // show a price at once; replaced by the server's figure when it arrives
      _estimated = true;
      _loadQuote();
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => _loadQuote());
    }
  }

  Future<void> _loadQuote() async {
    final state = context.read<AppState>();
    if (s.pending) {
      if (mounted) setState(() { _quote = state.localQuote(s); _estimated = true; });
      return;
    }
    try {
      final q = await state.api.quote(s.id);
      if (mounted) setState(() { _quote = q; _estimated = false; _err = null; });
    } on OfflineException {
      // no signal: quote from the phone so the attendant is never stuck
      if (mounted) setState(() { _quote = state.localQuote(s); _estimated = true; });
    } catch (e) {
      if (mounted) setState(() => _err = e.toString());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkOut() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    final state = context.read<AppState>();
    try {
      final out = await state.checkOut(s);
      final q = out.quote;
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        backgroundColor: Brand.surface,
        isDismissible: false,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle_rounded, color: Brand.accent, size: 64),
            const SizedBox(height: 12),
            const Text('Car checked out', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            PlateBadge(s.plate),
            const SizedBox(height: 18),
            Text(ugx(q.amount), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Brand.accent)),
            Text('${durationText(q.minutes)} · ${q.blocks} × ${ugx(q.ratePerBlock)} · Cash', style: const TextStyle(color: Brand.muted)),
            if (!out.sent) ...[
              const SizedBox(height: 10),
              const Text('Saved on this phone - it will be sent when the signal is back.', textAlign: TextAlign.center, style: TextStyle(color: Brand.amber, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 24),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ]),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _quote;
    final nextIn = q == null ? null : q.nextIncreaseAt.difference(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: Text(parked ? 'Check out' : 'Receipt')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
        Center(child: PlateBadge(s.plate, size: 30)),
        const SizedBox(height: 18),
        if (_photo != null)
          ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.memory(base64Decode(_photo!), height: 190, width: double.infinity, fit: BoxFit.cover)),
        const SizedBox(height: 16),
        _row('Vehicle', s.sizeLabel),
        _row('Checked in', timeText(s.entryAt)),
        if (s.exitAt != null) _row('Checked out', timeText(s.exitAt!)),
        if (s.ownerName != null) _row('Owner', s.ownerName!),
        if (s.ownerPhone != null) _row('Phone', s.ownerPhone!),
        const SizedBox(height: 14),
        if (parked) ...[
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(colors: [Color(0xFF1C3A6B), Color(0xFF0F2447)]),
            ),
            child: q == null
                ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                : Column(children: [
                    Text(_estimated ? 'Amount due (worked out on this phone)' : 'Amount due', style: const TextStyle(color: Color(0xFF9FB0CF))),
                    const SizedBox(height: 4),
                    Text(ugx(q.amount), style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Brand.accent, letterSpacing: -1)),
                    const SizedBox(height: 6),
                    Text('${durationText(q.minutes)} parked · ${q.blocks} × ${ugx(q.ratePerBlock)}', style: const TextStyle(color: Colors.white70)),
                    if (nextIn != null && !nextIn.isNegative) ...[
                      const SizedBox(height: 10),
                      Text('Next charge in ${durationText(nextIn.inMinutes + 1)}', style: const TextStyle(color: Brand.amber, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ]),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Brand.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(16), border: Border.all(color: Brand.accent)),
            child: const Row(children: [
              Icon(Icons.payments_rounded, color: Brand.accent),
              SizedBox(width: 12),
              Expanded(child: Text('Collect the exact cash amount shown above. It is recorded automatically.', style: TextStyle(fontWeight: FontWeight.w600))),
            ]),
          ),
          if (_err != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_err!, style: const TextStyle(color: Brand.danger), textAlign: TextAlign.center)),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: (_busy || q == null) ? null : _checkOut,
            icon: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Icon(Icons.logout_rounded),
            label: Text(q == null ? 'Calculating…' : 'Collect ${ugx(q.amount)} & check out'),
          ),
        ] else ...[
          _row('Duration', durationText(s.minutes ?? 0)),
          _row('Paid', '${ugx(s.amount ?? 0)} · Cash'),
        ],
      ]),
    );
  }

  Widget _payChip(String key, String label, IconData icon) {
    final sel = _pay == key;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _pay = key),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sel ? Brand.accent.withValues(alpha: .12) : Brand.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? Brand.accent : Colors.transparent, width: 1.5),
        ),
        child: Column(children: [Icon(icon, color: sel ? Brand.accent : Brand.muted), const SizedBox(height: 4), Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))]),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(color: Brand.muted)),
          Flexible(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
}
