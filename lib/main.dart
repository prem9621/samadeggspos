import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'dashboard_screen.dart';
import 'daily_rate_screen.dart';
import 'parties_screen.dart';
import 'sale_entry_screen.dart';
import 'sales_history_screen.dart';
import 'expenses_screen.dart';
import 'settings_screen.dart';
import 'purchase_entry_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.init();

  final appState = AppState();
  await appState.loadSettings();

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const MyApp(),
    ),
  );
}

class AppState extends ChangeNotifier {
  String? _shopName;
  bool _darkMode = false;
  int _selectedIndex = 0;

  String? get shopName => _shopName;
  bool get darkMode => _darkMode;
  int get selectedIndex => _selectedIndex;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _shopName = prefs.getString('shop_name');
    _darkMode = prefs.getBool('dark_mode') ?? false;
    _selectedIndex = prefs.getInt('selected_index') ?? 0;
    notifyListeners();
  }

  Future<void> setShopName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    _shopName = name;
    await prefs.setString('shop_name', name);
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    _darkMode = !_darkMode;
    await prefs.setBool('dark_mode', _darkMode);
    notifyListeners();
  }

  void setSelectedIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Samad Eggs POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2563EB), brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: context.watch<AppState>().darkMode
          ? ThemeMode.dark
          : ThemeMode.light,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<Widget> _screens = [
    const DashboardScreen(),
    const DailyRateScreen(),
    const PartiesScreen(),
    const SaleEntryScreen(),
    const PurchaseEntryScreen(),
    const SalesHistoryScreen(),
    const ExpensesScreen(),
    const SettingsScreen(),
  ];

  final List<String> _screenTitles = [
    'Dashboard',
    'Daily Rate',
    'Parties',
    'New Sale',
    'New Purchase',
    'Sales History',
    'Expenses',
    'Settings',
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final isSelected = context.watch<AppState>().selectedIndex == index;
    return InkWell(
      onTap: () {
        context.read<AppState>().setSelectedIndex(index);
        Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF64748B),
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF334155),
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF334155)),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFEFF6FF),
              child: Icon(
                Icons.storefront,
                color: const Color(0xFF2563EB),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.watch<AppState>().shopName ?? 'Samad Eggs',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none, color: Color(0xFF334155)),
              ],
            ),
            onPressed: () {},
          ),
        ],
      ),
      drawer: Drawer(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.watch<AppState>().shopName ?? 'Samad Eggs',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'POS System',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildDrawerItem(
                      icon: Icons.dashboard_outlined,
                      title: 'Dashboard',
                      index: 0,
                    ),
                    _buildDrawerItem(
                      icon: Icons.price_change_outlined,
                      title: 'Daily Rate',
                      index: 1,
                    ),
                    _buildDrawerItem(
                      icon: Icons.people_outline,
                      title: 'Parties',
                      index: 2,
                    ),
                    _buildDrawerItem(
                      icon: Icons.shopping_cart_outlined,
                      title: 'New Sale',
                      index: 3,
                    ),
                    _buildDrawerItem(
                      icon: Icons.shopping_bag_outlined,
                      title: 'New Purchase',
                      index: 4,
                    ),
                    _buildDrawerItem(
                      icon: Icons.history_outlined,
                      title: 'Sales History',
                      index: 5,
                    ),
                    _buildDrawerItem(
                      icon: Icons.money_off_outlined,
                      title: 'Expenses',
                      index: 6,
                    ),
                    _buildDrawerItem(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      index: 7,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(
                        Icons.storefront,
                        color: Color(0xFF2563EB),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'POS System',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'v1.0',
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF64748B).withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: context.watch<AppState>().selectedIndex,
        children: _screens,
      ),
    );
  }
}
