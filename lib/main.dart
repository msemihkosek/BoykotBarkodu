import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/scanner_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sistem durum çubuğu ve navigasyon stil ayarları
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const BoykotBarkodApp());
}

class BoykotBarkodApp extends StatelessWidget {
  const BoykotBarkodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boykot Barkodu',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // Markette karanlık ortamda kamera için ideal dark mode
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const ScannerScreen(),
    );
  }
}
