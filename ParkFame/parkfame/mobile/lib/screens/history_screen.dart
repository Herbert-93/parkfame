import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/plate_badge.dart';
import 'session_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: s.refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 40), children: [
          const Text('History', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${s.history.length} cars checked out', style: const TextStyle(color: Brand.muted)),
          const SizedBox(height: 16),
          if (s.history.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: Text('Nothing here yet.', style: TextStyle(color: Brand.muted)))),
          for (final x in s.history)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Brand.surface,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailScreen(session: x))),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Align(alignment: Alignment.centerLeft, child: PlateBadge(x.plate, size: 14)),
                          const SizedBox(height: 7),
                          Text('${x.sizeLabel} · out ${timeText(x.exitAt!)}', style: const TextStyle(color: Brand.muted, fontSize: 12)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(ugx(x.amount ?? 0), style: const TextStyle(fontWeight: FontWeight.w900, color: Brand.accent)),
                        const SizedBox(height: 4),
                        Text(durationText(x.minutes ?? 0), style: const TextStyle(color: Brand.muted, fontSize: 12)),
                      ]),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
