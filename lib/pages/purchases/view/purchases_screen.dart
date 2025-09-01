import 'package:flutter/material.dart';
import '../../../locale/MyLocalizations.dart';
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
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)
                .translate('loading_purchase_management')),
          ],
        ),
      ),
    );
  }
}
