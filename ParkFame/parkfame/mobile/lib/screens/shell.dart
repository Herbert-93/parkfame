import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';
import 'account_screen.dart';
import 'check_in_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().bootstrap());
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (s.loading && s.lot == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (s.lot == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_rounded, size: 56, color: Brand.muted),
              const SizedBox(height: 16),
              Text(s.error ?? 'Could not load your account.', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(onPressed: s.bootstrap, child: const Text('Try again')),
              TextButton(onPressed: () => AccountScreen.signOut(context), child: const Text('Sign out')),
            ]),
          ),
        ),
      );
    }
    return Scaffold(
      body: IndexedStack(index: _i, children: const [HomeScreen(), HistoryScreen(), AccountScreen()]),
      floatingActionButton: _i == 0
          ? FloatingActionButton.extended(
              backgroundColor: Brand.accent,
              foregroundColor: Brand.navy,
              icon: const Icon(Icons.add_a_photo_rounded),
              label: const Text('Log car in', style: TextStyle(fontWeight: FontWeight.w800)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckInScreen())),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.local_parking_rounded), label: 'Parked'),
          NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'History'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Account'),
        ],
      ),
    );
  }
}
