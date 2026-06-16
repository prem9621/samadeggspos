import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// ─── Design Tokens ────────────────────────────────────────────────────────────
const kAmber = Color(0xFFD97706);       // Primary – egg-gold
const kAmberLight = Color(0xFFFEF3C7);  // Amber tint
const kAmberDark = Color(0xFFB45309);   // Pressed state
const kSurface = Color(0xFFFAFAF9);     // App background
const kCard = Color(0xFFFFFFFF);        // Card background
const kBorder = Color(0xFFE7E5E4);      // Subtle borders
const kText = Color(0xFF1C1917);        // Primary text
const kTextSub = Color(0xFF78716C);     // Secondary text
const kTextMuted = Color(0xFFA8A29E);   // Muted / placeholder
const kGreen = Color(0xFF16A34A);       // Credit / received
const kRed = Color(0xFFDC2626);         // Debit / paid / error
const kBlue = Color(0xFF2563EB);        // Info accent

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
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
          seedColor: kAmber,
          brightness: Brightness.light,
          primary: kAmber,
          onPrimary: Colors.white,
          surface: kSurface,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: kSurface,
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: kText),
          headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kText),
          headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kText),
          titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kText),
          titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kText),
          bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: kText),
          bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: kTextSub),
          bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: kTextMuted),
          labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText),
          labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: kTextMuted),
        ),
        cardTheme: CardThemeData(
          color: kCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: kBorder),
          ),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kAmber,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kCard,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kAmber, width: 1.5),
          ),
          labelStyle: const TextStyle(fontSize: 13, color: kTextSub),
          hintStyle: const TextStyle(fontSize: 13, color: kTextMuted),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: kAmber, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: context.watch<AppState>().darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const MainScreen(),
    );
  }
}

// ─── Nav Item Model ───────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  const _NavItem(this.icon, this.activeIcon, this.label, this.index);
}

const _navItems = [
  _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home', 0),
  _NavItem(Icons.egg_outlined, Icons.egg_rounded, 'Rate', 1),
  _NavItem(Icons.people_outline, Icons.people_rounded, 'Parties', 2),
  _NavItem(Icons.point_of_sale_outlined, Icons.point_of_sale_rounded, 'Sale', 3),
  _NavItem(Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, 'Purchase', 4),
  _NavItem(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'History', 5),
  _NavItem(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'Expenses', 6),
  _NavItem(Icons.settings_outlined, Icons.settings_rounded, 'Settings', 7),
];

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

  final _screenTitles = [
    'Today\'s Overview',
    'Egg Rate',
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
    final idx = context.watch<AppState>().selectedIndex;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kSurface,
      appBar: _buildAppBar(idx),
      drawer: _buildDrawer(idx),
      body: IndexedStack(
        index: idx,
        children: _screens,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(int idx) {
    return AppBar(
      backgroundColor: kCard,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: kBorder),
      ),
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: kText, size: 22),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: kAmberLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.egg_rounded, color: kAmber, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.watch<AppState>().shopName ?? 'Samad Eggs',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kText),
              ),
              Text(
                _screenTitles[idx],
                style: const TextStyle(fontSize: 11, color: kTextSub, fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(int idx) {
    return Drawer(
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: kAmber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.egg_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.watch<AppState>().shopName ?? 'Samad Eggs',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kText),
                        ),
                        const Text('POS System v1.0',
                          style: TextStyle(fontSize: 11, color: kTextSub)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: kBorder),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _navItems.map((item) => _buildNavTile(item, idx)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTile(_NavItem item, int currentIdx) {
    final isSelected = currentIdx == item.index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected ? kAmberLight : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            context.read<AppState>().setSelectedIndex(item.index);
            Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  isSelected ? item.activeIcon : item.icon,
                  color: isSelected ? kAmber : kTextSub,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? kAmber : kText,
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  Container(
                    width: 5, height: 5,
                    decoration: const BoxDecoration(
                      color: kAmber,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}