import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/store.dart';
import 'services/notification_service.dart';
import 'screens/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  await Store.init();
  await NotificationService.init();
  runApp(const FolioApp());
}

class FolioApp extends StatelessWidget {
  const FolioApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Folio',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF5EFE6),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF2C1F14),
        secondary: Color(0xFFC48B56),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5EFE6),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Color(0xFF2C1F14),
      ),
    ),
    home: const HomeScreen(),
  );
}
