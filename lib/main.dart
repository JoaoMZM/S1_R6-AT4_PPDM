import 'package:flutter/material.dart';
import 'package:s1_r6_at4_ppdm/player_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MeuPlayerApp());
}

class MeuPlayerApp extends StatelessWidget {
  const MeuPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meu Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const PlayerScreen(),
    );
  }
}
