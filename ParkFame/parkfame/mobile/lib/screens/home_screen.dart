import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../plate_scanner.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/plate_badge.dart';
import 'session_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  final _scanner = PlateScanner();
  bool _scanning = false;

  @override
  void dispose() {
    _scanner.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _scanToSearch() async {
    setState(() => _scanning = true);
    try {
      final r = await _scanner.scan();
      if (r?.plate != null) _search.text = r!.plate!;
      if (r != null && r.plate == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not read the plate. Try again or type it.')));
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final q = _search.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final list = s.parked.where((x) => x.plate.contains(q)).toList();
    final lot = s.lot!;
    final pct = (s.parked.length / lot.capacity).clamp(0.0, 1.0);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: s.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Hello, ${s.name.split(' ').first} 👋', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.place_rounded, size: 15, color: Brand.accent),
                    const SizedBox(width: 4),
                    Text(lot.name, style: const TextStyle(color: Brand.muted)),
                  ]),
                ]),
              ),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: Brand.accent, borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.local_parking_rounded, color: Brand.navy, size: 28),
              ),
            ]),
            _StatusBanner(s),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(colors: [Color(0xFF1C3A6B), Color(0xFF0F2447)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Collected today', style: TextStyle(color: Color(0xFF9FB0CF))),
                const SizedBox(height: 4),
                Text(ugx(s.collectedToday), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Brand.accent, letterSpacing: -.5)),
                const SizedBox(height: 18),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${s.parked.length} of ${lot.capacity} spaces taken', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${s.checkOutsToday} left today', style: const TextStyle(color: Color(0xFF9FB0CF), fontSize: 12)),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: pct, minHeight: 9, backgroundColor: Colors.white12, color: pct > .85 ? Brand.danger : Brand.accent),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Find a car by plate…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _scanning
                    ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton(icon: const Icon(Icons.photo_camera_rounded, color: Brand.accent), onPressed: _scanToSearch),
              ),
            ),
            const SizedBox(height: 18),
            Text('Parked now · ${list.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (s.error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(s.error!, style: const TextStyle(color: Brand.danger))),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 50),
                child: Column(children: [
                  Icon(Icons.directions_car_outlined, size: 60, color: Brand.muted.withValues(alpha: .6)),
                  const SizedBox(height: 10),
                  Text(q.isEmpty ? 'No cars parked yet.\nTap “Log car in” to start.' : 'No parked car matches “$q”.', textAlign: TextAlign.center, style: const TextStyle(color: Brand.muted)),
                ]),
              ),
            for (final x in list) _SessionTile(x),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final ParkSession s;
  const _SessionTile(this.s);

  @override
  Widget build(BuildContext context) {
    final mins = DateTime.now().difference(s.entryAt).inMinutes;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Brand.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailScreen(session: s))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: Brand.surface2, borderRadius: BorderRadius.circular(14)),
                child: Icon(sizeIcon(s.size), color: Brand.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Align(alignment: Alignment.centerLeft, child: PlateBadge(s.plate, size: 15)),
                  const SizedBox(height: 7),
                  Text('${s.sizeLabel} · in ${timeText(s.entryAt)}', style: const TextStyle(color: Brand.muted, fontSize: 12)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(durationText(mins), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                s.pending ? const Icon(Icons.cloud_upload_outlined, color: Brand.amber, size: 20) : const Icon(Icons.chevron_right_rounded, color: Brand.muted),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Tells the attendant when the phone is offline, what is waiting to be sent, and anything the server refused.
class _StatusBanner extends StatelessWidget {
  final AppState s;
  const _StatusBanner(this.s);

  @override
  Widget build(BuildContext context) {
    final rejected = s.rejected;
    if (!s.offline && s.pendingCount == 0 && rejected.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(children: [
        if (s.offline || s.pendingCount > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Brand.amber.withValues(alpha: .14), borderRadius: BorderRadius.circular(14), border: Border.all(color: Brand.amber)),
            child: Row(children: [
              Icon(s.offline ? Icons.cloud_off_rounded : Icons.cloud_upload_outlined, color: Brand.amber, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  [
                    if (s.offline) 'No usable connection - working from saved data.',
                    if (s.pendingCount > 0) '${s.pendingCount} waiting to send. Nothing is lost.',
                  ].join(' '),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              if (s.pendingCount > 0)
                s.syncing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton(onPressed: s.refresh, child: const Text('Send now')),
            ]),
          ),
        for (final m in rejected)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Brand.danger.withValues(alpha: .12), borderRadius: BorderRadius.circular(14), border: Border.all(color: Brand.danger)),
            child: Text(m, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        if (rejected.isNotEmpty) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: s.dismissRejected, child: const Text('Dismiss'))),
      ]),
    );
  }
}
