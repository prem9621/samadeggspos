import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'main.dart';
import 'monthly_data_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _shopNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _shopNameController.text = appState.shopName ?? '';
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    super.dispose();
  }

  Future<void> _backupDatabase() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup/restore not implemented yet')));
    }
  }

  Future<void> _restoreDatabase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore Database', style: TextStyle(fontSize: 15)),
        content: const Text('This will replace current data. Are you sure?',
          style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: kRed),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restore requires file picker (not implemented yet)')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Shop name card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Shop Name',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText)),
                const SizedBox(height: 8),
                TextField(
                  controller: _shopNameController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(hintText: 'Enter shop name'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await context.read<AppState>().setShopName(_shopNameController.text.trim());
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Shop name saved')));
                      }
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Dark mode
          Container(
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: kAmberLight, borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.dark_mode_rounded, size: 18, color: kAmber),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Dark Mode',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText)),
                  ),
                  Switch(
                    value: context.watch<AppState>().darkMode,
                    activeThumbColor: kAmber,
                    onChanged: (_) async {
                      await context.read<AppState>().toggleDarkMode();
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Monthly Data
          Container(
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
            ),
            child: _SettingsTile(
              icon: Icons.calendar_month_rounded,
              label: 'Monthly Data',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MonthlyDataScreen(),
                  ),
                );
              },
            ),
          ),

          if (!kIsWeb) ...[
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.backup_rounded,
                    label: 'Backup Database',
                    onTap: _backupDatabase,
                  ),
                  const Divider(height: 1, color: kBorder, indent: 14, endIndent: 14),
                  _SettingsTile(
                    icon: Icons.restore_rounded,
                    label: 'Restore Database',
                    onTap: _restoreDatabase,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          Center(
            child: Text('Samad Eggs POS · v1.0',
              style: const TextStyle(fontSize: 11, color: kTextMuted)),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SettingsTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kTextSub),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500, color: kText)),
          ),
          const Icon(Icons.chevron_right_rounded, size: 18, color: kTextMuted),
        ],
      ),
    ),
  );
}