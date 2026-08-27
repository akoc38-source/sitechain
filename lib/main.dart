import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/project_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase yerel modda çalışıyor: $e");
  }
  runApp(const SiteChainApp());
}

class SiteChainApp extends StatelessWidget {
  const SiteChainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SiteChain',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121824),
        primaryColor: const Color(0xFFFF9F1C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF9F1C),
          secondary: Color(0xFF2EC4B6),
          surface: Color(0xFF1E2638),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const ProjectSelectionScreen(),
    );
  }
}
