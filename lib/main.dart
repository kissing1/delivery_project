import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/page/splash/animated_splash.dart';
import 'package:flutter_application_1/providers/delivery_provider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart'; // ✅ เพิ่มอันนี้
import 'firebase_options.dart'; // ✅ เพิ่มถ้าใช้ flutterfire CLI ตั้งค่าไว้แล้ว

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ เริ่มต้น Firebase ก่อนใช้งาน Firestore
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions
        .currentPlatform, // ใช้ config จาก firebase_options.dart
  );
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => DeliveryProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZapGo Delivery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF32BD6C)),
        useMaterial3: true,
      ),
      home: const AnimatedSplash(userIdSender: 0), // ← เดิมเป็น LoginPage
    );
  }
}
