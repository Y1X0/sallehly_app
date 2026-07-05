import 'package:flutter/material.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل العمليات'),
      ),
      body: const Center(
        child: Text(
          'سجل العمليات سيظهر هنا',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}