import 'package:flutter/material.dart';
import '../purchase_management_screen.dart';

/// Main Purchases Screen - Entry point for purchase management
class PurchasesScreen extends StatelessWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Navigate to the management screen immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacementNamed(
        PurchaseManagementScreen.routeName,
      );
    });

    // Show loading while navigating
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading Purchase Management...'),
          ],
        ),
      ),
    );
  }
}
