import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RiderLocationRealtime extends StatefulWidget {
  const RiderLocationRealtime({super.key});

  @override
  State<RiderLocationRealtime> createState() => _RiderLocationRealtimeState();
}

class _RiderLocationRealtimeState extends State<RiderLocationRealtime> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? listener;

  void startRealtimeGet() {
    // 👉 กำหนด doc ที่จะฟัง (rider_location/8)
    final docRef = db.collection("rider_location").doc("8");

    // ถ้ามี listener ตัวเก่าอยู่ ให้ cancel ก่อน
    listener?.cancel();

    listener = docRef.snapshots().listen((event) {
      final data = event.data();
      if (data != null) {
        final lat = data['lat'];
        final lng = data['lng'];
        log("📡 current data: lat=$lat, lng=$lng");

        // ✅ แสดง Snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lat: $lat | Lng: $lng"),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        log("⚠️ Document is empty");
      }
    }, onError: (error) => log("❌ Listen failed: $error"));
  }

  void stopRealTime() async {
    try {
      await listener?.cancel();
      listener = null;
      log('🛑 Real-time listener stopped.');
    } catch (e) {
      log('⚠️ Listener is not running...');
    }
  }

  @override
  void dispose() {
    listener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Real-time Rider Location')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton(
              onPressed: startRealtimeGet,
              child: const Text('Start Real-time Get'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: stopRealTime,
              child: const Text('Stop Real-time Get'),
            ),
          ],
        ),
      ),
    );
  }
}
