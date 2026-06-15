import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'dashboard_screen.dart';
import 'daily_rate_screen.dart';
import 'parties_screen.dart';
import 'sale_entry_screen.dart';
import 'sales_history_screen.dart';
import 'settings_screen.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.amber, brightness: Brightness.dark),
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
    const SalesHistoryScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: context.watch<AppState>().selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: context.watch<AppState>().selectedIndex,
        onDestinationSelected: (index) {
          context.read<AppState>().setSelectedIndex(index);
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.price_change), label: 'Rate'),
          NavigationDestination(icon: Icon(Icons.group), label: 'Parties'),
          NavigationDestination(
              icon: Icon(Icons.add_shopping_cart), label: 'Sale'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}