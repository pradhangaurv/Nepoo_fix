import 'package:flutter/material.dart';
class ProviderHome extends StatefulWidget {
  const ProviderHome({super.key});

  @override
  State<ProviderHome> createState() => _ProviderHomeState();
}

class _ProviderHomeState extends State<ProviderHome> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child:
        Text("Provider home screen"),
      ),
    );
  }
}
