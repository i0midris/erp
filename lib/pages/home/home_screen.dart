import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pos_final/config.dart';
import 'package:pos_final/helpers/AppTheme.dart';
import 'package:pos_final/helpers/icons.dart';
import 'package:pos_final/locale/MyLocalizations.dart';
import 'package:pos_final/models/sellDatabase.dart';
import 'package:pos_final/pages/home/widgets/greeting_widget.dart';
import 'package:pos_final/pages/notifications/view_model_manger/notifications_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/statistics_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static ThemeData themeData = AppTheme.getThemeFromThemeMode(1);
  static GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  // Helper method to safely get translations
  String _translate(String key) {
    try {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return localizations.translate(key);
      }
    } catch (e) {
      debugPrint('Translation error for key "$key": $e');
    }

    // Fallback translations
    final fallbacks = {
      'home': 'Home',
      'check_connectivity': 'Check Connectivity',
      'sync_all_sales_before_logout': 'Sync all sales before logout',
      'point_of_sale': 'Point of Sale',
      'sync': 'Sync',
      'logout': 'Logout',
      'notifications': 'Notifications',
    };
    return fallbacks[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          _translate('home'),
          style: AppTheme.getTextStyle(
            themeData.textTheme.titleLarge,
            fontWeight: 600,
          ),
        ),
        actions: <Widget>[
          // Sync Button
          IconButton(
            tooltip: _translate('sync'),
            onPressed: () async {
              // TODO: Implement sync functionality
              /*     (await Helper().checkConnectivity())
                  ? await sync()
                  : Fluttertoast.showToast(
                      msg: _translate('check_connectivity'));*/
            },
            icon: Icon(
              MdiIcons.syncIcon,
              color: Colors.orange,
            ),
          ),

          // POS Button with Cart Badge
          FutureBuilder<String>(
            future: SellDatabase().countSellLines(isCompleted: 0),
            builder: (context, snapshot) {
              final cartCount = int.tryParse(snapshot.data ?? '0') ?? 0;

              return Badge.count(
                count: cartCount,
                isLabelVisible: cartCount > 0,
                smallSize: 10,
                largeSize: 15,
                alignment: AlignmentDirectional.topEnd,
                backgroundColor: Colors.red,
                textColor: Colors.white,
                child: IconButton(
                  tooltip: 'فتح شاشة نقاط البيع', // Arabic: Open POS Screen
                  onPressed: () {
                    Navigator.pushNamed(context, '/pos-single');
                  },
                  icon: const Icon(
                    Icons.point_of_sale,
                    color: Colors.green,
                    size: 28,
                  ),
                ),
              );
            },
          ),

          // Logout Button
          IconButton(
            tooltip: _translate('logout'),
            onPressed: () async {
              try {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                final notSyncedSells = await SellDatabase().getNotSyncedSells();

                if (notSyncedSells.isEmpty) {
                  // Save userId in disk for future reference
                  if (Config.userId != null) {
                    prefs.setInt('prevUserId', Config.userId!);
                  }
                  prefs.remove('userId');

                  // Navigate to login screen
                  Navigator.pushReplacementNamed(context, '/login');
                } else {
                  Fluttertoast.showToast(
                    msg: _translate('sync_all_sales_before_logout'),
                    toastLength: Toast.LENGTH_LONG,
                    gravity: ToastGravity.CENTER,
                    timeInSecForIosWeb: 3,
                    backgroundColor: Colors.orange,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                }
              } catch (e) {
                debugPrint('Logout error: $e');
                Fluttertoast.showToast(
                  msg: 'Error during logout. Please try again.',
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                );
              }
            },
            icon: Icon(
              IconBroken.Logout,
              color: Colors.red,
            ),
          ),
        ],
        leading: Container(
          width: 75,
          child: Row(
            children: [
              // Menu Button
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  child: Icon(Icons.list),
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              ),

              SizedBox(width: 10),

              // Notifications Button with Badge
              BlocBuilder<NotificationsCubit, NotificationsState>(
                builder: (context, state) {
                  final notificationCount =
                      NotificationsCubit.get(context).notificationsCount;

                  return Badge.count(
                    count: notificationCount,
                    isLabelVisible: notificationCount > 0,
                    smallSize: 10,
                    largeSize: 15,
                    alignment: AlignmentDirectional.topEnd,
                    backgroundColor: const Color(0xff4c53a5),
                    textColor: Colors.white,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/notify');
                      },
                      child: Icon(
                        IconBroken.Notification,
                        color: Color(0xff4c53a5),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        leadingWidth: 75,
        bottom: GreetingWidget(
          themeData: themeData,
          userName:
              'Shehab', // TODO: Get actual user name from preferences or user data
        ),
      ),

      body: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Statistics Widget
            FutureBuilder<Map<String, dynamic>>(
              future: _getStatisticsData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final data = snapshot.data ?? {};

                return Statistics(
                  themeData: themeData,
                  totalSales: data['totalSales'] ?? 0,
                  totalReceivedAmount: data['totalReceivedAmount'] ?? 0,
                  totalDueAmount: data['totalDueAmount'] ?? 0,
                  totalSalesAmount: data['totalSalesAmount'] ?? 0,
                );
              },
            ),

            // Quick Actions Section
            _buildQuickActions(),
          ],
        ),
      ),

      // Floating Action Button for Quick POS Access
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/pos-single');
        },
        icon: Icon(Icons.add_shopping_cart),
        label: Text(_translate('point_of_sale')),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
    );
  }

  // Build quick actions section
  Widget _buildQuickActions() {
    return Container(
      margin: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: themeData.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildQuickActionCard(
                icon: Icons.point_of_sale,
                title: 'New Sale',
                subtitle: 'Start POS',
                color: Colors.green,
                onTap: () => Navigator.pushNamed(context, '/pos-single'),
              ),
              _buildQuickActionCard(
                icon: Icons.inventory,
                title: 'Products',
                subtitle: 'Manage inventory',
                color: Colors.blue,
                onTap: () => Navigator.pushNamed(context, '/products'),
              ),
              _buildQuickActionCard(
                icon: Icons.people,
                title: 'Customers',
                subtitle: 'View customers',
                color: Colors.orange,
                onTap: () => Navigator.pushNamed(context, '/customer'),
              ),
              _buildQuickActionCard(
                icon: Icons.shopping_cart,
                title: 'Sales',
                subtitle: 'View sales',
                color: Colors.purple,
                onTap: () => Navigator.pushNamed(context, '/sale'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              SizedBox(height: 8),
              Text(
                title,
                style: themeData.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                subtitle,
                style: themeData.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Get statistics data from database
  Future<Map<String, dynamic>> _getStatisticsData() async {
    try {
      final sellDatabase = SellDatabase();
      final sells = await sellDatabase.getSells();

      double totalSales = 0;
      double totalReceivedAmount = 0;
      double totalDueAmount = 0;
      double totalSalesAmount = 0;

      for (var sell in sells) {
        final invoiceAmount =
            double.tryParse(sell['invoice_amount'].toString()) ?? 0;
        final pendingAmount =
            double.tryParse(sell['pending_amount'].toString()) ?? 0;

        totalSales++;
        totalSalesAmount += invoiceAmount;
        totalReceivedAmount += (invoiceAmount - pendingAmount);
        totalDueAmount += pendingAmount;
      }

      return {
        'totalSales': totalSales.toInt(),
        'totalReceivedAmount': totalReceivedAmount,
        'totalDueAmount': totalDueAmount,
        'totalSalesAmount': totalSalesAmount,
      };
    } catch (e) {
      debugPrint('Error getting statistics: $e');
      return {
        'totalSales': 0,
        'totalReceivedAmount': 0.0,
        'totalDueAmount': 0.0,
        'totalSalesAmount': 0.0,
      };
    }
  }
}
