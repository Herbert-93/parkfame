import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'config.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(apiKey: fbApiKey, appId: fbAppId, messagingSenderId: fbSenderId, projectId: fbProjectId),
  );
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(ChangeNotifierProvider(create: (_) => AppState(), child: const ParkFameApp()));
}

class ParkFameApp extends StatelessWidget {
  const ParkFameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParkFame',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snap.data == null ? const LoginScreen() : const Shell();
        },
      ),
    );
  }
}
