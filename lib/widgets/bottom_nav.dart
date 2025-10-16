import 'package:flutter/material.dart';

class MyBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final Color activeColor;

  const MyBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.activeColor = const Color(0xFF2ECC71), // default สีเขียว
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      backgroundColor: Colors.white,
      selectedItemColor: activeColor,
      unselectedItemColor: Colors.grey.shade400,
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(
          icon: Image.asset('assets/images/img_10.png', width: 26, height: 26),
          activeIcon: Image.asset(
            'assets/images/img_10.png',
            width: 26,
            height: 26,
          ),
          label: 'รอรับของ',
        ),
        BottomNavigationBarItem(
          icon: Image.asset('assets/images/img_11.png', width: 26, height: 26),
          activeIcon: Image.asset(
            'assets/images/img_11.png',
            width: 26,
            height: 26,
          ),
          label: 'หน้าแรก',
        ),
        BottomNavigationBarItem(
          icon: Image.asset('assets/images/profile.png', width: 26, height: 26),
          activeIcon: Image.asset(
            'assets/images/profile.png',
            width: 26,
            height: 26,
          ),
          label: 'โปรไฟล์',
        ),
      ],
    );
  }
}
