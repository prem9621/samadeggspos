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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_screenTitles[context.watch<AppState>().selectedIndex]),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    context.watch<AppState>().shopName ?? 'Samad Eggs POS',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: context.watch<AppState>().selectedIndex == 0,
              onTap: () {
                context.read<AppState>().setSelectedIndex(0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.price_change),
              title: const Text('Daily Rate'),
              selected: context.watch<AppState>().selectedIndex == 1,
              onTap: () {
                context.read<AppState>().setSelectedIndex(1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Parties'),
              selected: context.watch<AppState>().selectedIndex == 2,
              onTap: () {
                context.read<AppState>().setSelectedIndex(2);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_shopping_cart),
              title: const Text('New Sale'),
              selected: context.watch<AppState>().selectedIndex == 3,
              onTap: () {
                context.read<AppState>().setSelectedIndex(3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_bag),
              title: const Text('New Purchase'),
              selected: context.watch<AppState>().selectedIndex == 4,
              onTap: () {
                context.read<AppState>().setSelectedIndex(4);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Sales History'),
              selected: context.watch<AppState>().selectedIndex == 5,
              onTap: () {
                context.read<AppState>().setSelectedIndex(5);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.money_off),
              title: const Text('Expenses'),
              selected: context.watch<AppState>().selectedIndex == 6,
              onTap: () {
                context.read<AppState>().setSelectedIndex(6);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              selected: context.watch<AppState>().selectedIndex == 7,
              onTap: () {
                context.read<AppState>().setSelectedIndex(7);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: context.watch<AppState>().selectedIndex,
        children: _screens,
      ),
    );
  }
}