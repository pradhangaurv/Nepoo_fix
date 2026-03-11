import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:nepoo_fix/provider/screens/provider_activity.dart';
import 'package:nepoo_fix/provider/screens/provider_home.dart';
import 'package:nepoo_fix/provider/screens/provider_request.dart';
import 'package:nepoo_fix/provider/screens/provider_settings.dart';

class ProviderBottomNav extends StatefulWidget {
  const ProviderBottomNav({super.key});

  @override
  State<ProviderBottomNav> createState() => _ProviderBottomNavState();
}

class _ProviderBottomNavState extends State<ProviderBottomNav> {
  late final List<Widget> screens;
  int currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    screens = const [
      ProviderHome(),
      ProviderRequest() ,
      ProviderActivity(),
      ProviderSettings()
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
          Icon(Icons.notifications_active_outlined, color: Colors.white, size: 30),
          Icon(Icons.add_circle_outline, color: Colors.white, size: 30),
          Icon(Icons.settings_outlined, color: Colors.white, size: 30),
        ],
      ),
      body: screens[currentTabIndex],
    );
  }
}
