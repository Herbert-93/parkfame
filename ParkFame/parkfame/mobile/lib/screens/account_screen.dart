import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  static Future<void> signOut(BuildContext context) async {
    context.read<AppState>().reset();
    await FirebaseAuth.instance.signOut();
  }

  /// Warns first if records are still waiting to be sent.
  static Future<void> confirmSignOut(BuildContext context) async {
    final s = context.read<AppState>();
    if (s.pendingCount > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Records not sent yet'),
          content: Text('${s.pendingCount} record(s) are saved on this phone and have not been sent. They stay safe and will send when you sign in again with a connection. Sign out anyway?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign out')),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    await signOut(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Account', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 24),
        Center(
          child: CircleAvatar(radius: 42, backgroundColor: Brand.accent, child: Text(s.name.isEmpty ? '?' : s.name[0].toUpperCase(), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Brand.navy))),
        ),
        const SizedBox(height: 14),
        Center(child: Text(s.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
        Center(child: Text(s.email, style: const TextStyle(color: Brand.muted))),
        const SizedBox(height: 26),
        _tile(Icons.place_rounded, 'Parking lot', s.lot?.name ?? '-'),
        _tile(Icons.badge_rounded, 'Role', s.role),
        _tile(Icons.timer_rounded, 'Billing', 'Every ${s.lot?.rates.blockHours ?? 12} hours'),
        const SizedBox(height: 26),
        OutlinedButton.icon(
          onPressed: () => confirmSignOut(context),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), foregroundColor: Brand.danger, side: const BorderSide(color: Brand.danger), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        ),
        const SizedBox(height: 18),
        const Center(child: Text('ParkFame v1.0.0', style: TextStyle(color: Brand.muted, fontSize: 12))),
      ]),
    );
  }

  Widget _tile(IconData i, String k, String v) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Brand.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [Icon(i, color: Brand.accent), const SizedBox(width: 14), Text(k, style: const TextStyle(color: Brand.muted)), const Spacer(), Text(v, style: const TextStyle(fontWeight: FontWeight.w700))]),
      );
}
