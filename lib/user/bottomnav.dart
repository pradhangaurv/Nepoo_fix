import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:nepoo_fix/user/screens/activity.dart';
import 'package:nepoo_fix/user/screens/find_services.dart';
import 'package:nepoo_fix/user/screens/home_screen.dart';
import 'package:nepoo_fix/user/screens/setting.dart';


class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  late final List<Widget> screen;

  int currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    screen = const [
      HomeScreen(),
      Activity(),
      FindServices(),
      Setting(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: CurvedNavigationBar(
        height: 70,
        color: Colors.black,
        backgroundColor: Colors.white,
        animationDuration: const Duration(milliseconds: 300),
        onTap: (int index) => setState(() => currentTabIndex = index),
        items: const [
          Icon(Icons.home_outlined, color: Colors.white, size: 30),
          Icon(Icons.list_alt_outlined, color: Colors.white, size: 30),
          Icon(Icons.search, color: Colors.white, size: 30),
          Icon(Icons.settings_outlined, color: Colors.white, size: 30),
        ],
      ),
      body: screen[currentTabIndex],
    );
  }
}
