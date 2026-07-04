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

// ─── Design Tokens (Light) ────────────────────────────────────────────────────
const kBlue = Color(0xFF2563EB); // Primary – buttons, active
const kBlueDark = Color(0xFF1D4ED8); // Pressed
const kBlueLight = Color(0xFFEFF6FF); // Blue tint bg
const kAmber = Color(0xFFD97706); // Egg-gold accent
const kAmberLight = Color(0xFFFEF3C7);
const kAmberDark = Color(0xFFB45309);
const kSurface = Color(0xFFF8F9FA);
const kCard = Color(0xFFFFFFFF);
const kBorder = Color(0xFFE9ECEF);
const kText = Color(0xFF1A1A2E);
const kTextSub = Color(0xFF6C757D);
const kTextMuted = Color(0xFFADB5BD);
const kGreen = Color(0xFF16A34A);
const kRed = Color(0xFFDC2626);

// Path to the app logo — used in the AppBar, Drawer header, and as a
// faint background watermark across the app.
const kLogoPath = 'assets/logo.png';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  await DatabaseHelper.init();
  final appState = AppState();
  await appState.loadSettings();
  runApp(ChangeNotifierProvider.value(value: appState, child: const MyApp()));
}

class AppState extends ChangeNotifier {
  String? _shopName;
  bool _darkMode = false;
  int _selectedIndex = 0;
  int _rateRevision = 0;

  String? get shopName => _shopName;
  bool get darkMode => _darkMode;
  int get selectedIndex => _selectedIndex;
  int get rateRevision => _rateRevision;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _shopName = prefs.getString('shop_name');
    _darkMode = prefs.getBool('dark_mode') ?? false;
    _selectedIndex = 0;
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

  void notifyRatesChanged() {
    _rateRevision++;
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // ─── Light Theme ────────────────────────────────────────────────────────
  ThemeData _lightTheme() => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: kBlue,
      brightness: Brightness.light,
      primary: kBlue,
      onPrimary: Colors.white,
      surface: kSurface,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: kSurface,
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kText),
      headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kText),
      headlineSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kText),
      titleLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kText),
      titleMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kText),
      bodyLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: kText),
      bodyMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: kTextSub),
      bodySmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: kTextMuted),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
      labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: kTextMuted),
    ),
    cardTheme: CardThemeData(
      color: kCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kBorder),
      ),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: kBlue, width: 1.5),
      ),
      labelStyle: const TextStyle(fontSize: 12, color: kTextSub),
      hintStyle: const TextStyle(fontSize: 12, color: kTextMuted),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kBlue,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
  );

  // ─── Dark Theme ─────────────────────────────────────────────────────────
  // Same brand accents (blue/amber) so the app still feels like "Samad
  // Eggs" in dark mode — only surfaces/text flip to dark-friendly values.
  ThemeData _darkTheme() {
    const dSurface = Color(0xFF121212);
    const dCard = Color(0xFF1E1E1E);
    const dBorder = Color(0xFF2E2E2E);
    const dText = Color(0xFFF1F1F1);
    const dTextSub = Color(0xFFA0A0A0);
    const dTextMuted = Color(0xFF6E6E6E);

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: kBlue,
        brightness: Brightness.dark,
        primary: kBlue,
        onPrimary: Colors.white,
        surface: dSurface,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: dSurface,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: dText),
        headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: dText),
        headlineSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: dText),
        titleLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: dText),
        titleMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: dText),
        bodyLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: dText),
        bodyMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: dTextSub),
        bodySmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: dTextMuted),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
        labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: dTextMuted),
      ),
      cardTheme: CardThemeData(
        color: dCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: dBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: dBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: dBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: kBlue, width: 1.5),
        ),
        labelStyle: const TextStyle(fontSize: 12, color: dTextSub),
        hintStyle: const TextStyle(fontSize: 12, color: dTextMuted),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().darkMode;
    return MaterialApp(
      title: 'Samad Eggs POS',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const MainScreen(),
    );
  }
}

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

const _screenTitles = [
  'Today\'s Overview',
  'Egg Rate',
  'Parties',
  'New Sale',
  'New Purchase',
  'Sales History',
  'Expenses',
  'Settings',
];

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<Widget> _screens = const [
    DashboardScreen(),
    DailyRateScreen(),
    PartiesScreen(),
    SaleEntryScreen(),
    PurchaseEntryScreen(),
    SalesHistoryScreen(),
    ExpensesScreen(),
    SettingsScreen(),
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final idx = context.watch<AppState>().selectedIndex;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(idx, theme, isDark),
      drawer: _buildDrawer(idx, theme, isDark),
      // Stack lets a faint logo watermark sit behind every screen without
      // touching each screen's own file — added once, applies everywhere.
      body: Stack(
        children: [
          const AppWatermark(),
          IndexedStack(index: idx, children: _screens),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(int idx, ThemeData theme, bool isDark) {
    return AppBar(
      backgroundColor: theme.cardTheme.color,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: theme.cardTheme.shape is RoundedRectangleBorder
            ? (theme.cardTheme.shape as RoundedRectangleBorder).side.color
            : kBorder),
      ),
      titleSpacing: 0,
      leading: IconButton(
        icon: Icon(Icons.menu_rounded, color: theme.textTheme.bodyLarge?.color, size: 20),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: kAmberLight,
              borderRadius: BorderRadius.circular(7),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              kLogoPath,
              fit: BoxFit.cover,
              // Falls back to the egg icon if the asset is ever missing,
              // so a bad path doesn't crash the app bar.
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.egg_rounded, color: kAmber, size: 16),
            ),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.watch<AppState>().shopName ?? 'Samad Eggs',
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              Text(
                _screenTitles[idx],
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(int idx, ThemeData theme, bool isDark) {
    return Drawer(
      backgroundColor: theme.cardTheme.color,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: kBlue,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      kLogoPath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.egg_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.watch<AppState>().shopName ?? 'Samad Eggs',
                          style: theme.textTheme.titleLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'POS System v1.0',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  // Quick dark-mode toggle right in the drawer header.
                  IconButton(
                    icon: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: kTextSub,
                      size: 20,
                    ),
                    tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
                    onPressed: () => context.read<AppState>().toggleDarkMode(),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: kBorder),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
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
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: isSelected ? kBlueLight : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () {
            context.read<AppState>().setSelectedIndex(item.index);
            Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isSelected ? item.activeIcon : item.icon,
                  color: isSelected ? kBlue : kTextSub,
                  size: 19,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? kBlue : kText,
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(color: kBlue, shape: BoxShape.circle),
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

/// Faint, oversized logo centered behind screen content — a subtle
/// brand watermark. Public (not private to main.dart) so any screen
/// opened via Navigator.push — which gets its own Scaffold outside
/// MainScreen's Stack — can wrap its own body with this too and get
/// the same watermark. Uses IgnorePointer so it never blocks taps,
/// and very low opacity so it never competes with real UI text/cards.
class AppWatermark extends StatelessWidget {
  const AppWatermark({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.center,
        child: Opacity(
          opacity: 0.045,
          child: Image.asset(
            kLogoPath,
            width: 320,
            height: 320,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}