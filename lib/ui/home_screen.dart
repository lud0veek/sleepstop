import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_strings.dart';
import '../providers/session_logs_provider.dart';
import '../providers/settings_provider.dart';
import '../services/foreground_task_service.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import 'dashboard_tab.dart';
import 'history_tab.dart';
import 'pro_unlock_sheet.dart';
import 'settings_bottom_sheet.dart';
import 'theme/oled_theme.dart';
import 'watch_guide_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    ForegroundTaskService.instance.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePermissionsAndNotifications();
    });
  }

  Future<void> _initializePermissionsAndNotifications() async {
    await NotificationService.instance.init();
    await PermissionService.instance.requestAllRequiredPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(sessionLogsProvider);
    final settings = ref.watch(settingsProvider);
    final s = ref.watch(appStringsProvider);

    return WithForegroundTask(
      child: Scaffold(
        backgroundColor: OledColors.trueBlack,
        appBar: AppBar(
          titleSpacing: 12,
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: OledColors.warmAmber.withValues(alpha: 0.35),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.nights_stay_rounded,
                      color: OledColors.warmAmber,
                      size: 17,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SleepStop',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: OledColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      s.appSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: OledColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'FR / NL / DE / ES',
              color: OledColors.elevatedSurface,
              onSelected: (code) {
                ref.read(settingsProvider.notifier).setLanguageCode(code);
              },
              itemBuilder: (context) => AppStrings.supportedLanguages.map((code) {
                final isSelected = settings.languageCode == code;
                return PopupMenuItem<String>(
                  value: code,
                  child: Row(
                    children: [
                      Text(
                        AppStrings.flagFor(code),
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? OledColors.warmAmber
                              : OledColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.languageName(code),
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? OledColors.warmAmber
                              : OledColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: OledColors.cardSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: OledColors.subtleBorder),
                ),
                child: Text(
                  settings.languageCode.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: OledColors.warmAmber,
                  ),
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => WatchGuideSheet.show(context),
              icon: const Icon(
                Icons.help_outline_rounded,
                color: OledColors.calmTeal,
                size: 21,
              ),
              tooltip: s.watchGuideTooltip,
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => ProUnlockSheet.show(context),
              icon: Icon(
                settings.isProUnlocked
                    ? Icons.verified_rounded
                    : Icons.workspace_premium_rounded,
                color: settings.isProUnlocked
                    ? OledColors.calmTeal
                    : OledColors.warmAmber,
                size: 21,
              ),
              tooltip: s.unlockProTitle,
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => SettingsBottomSheet.show(context),
              icon: const Icon(
                Icons.tune_rounded,
                color: OledColors.warmAmber,
                size: 21,
              ),
              tooltip: s.settingsTooltip,
            ),
            const SizedBox(width: 2),
          ],
        ),
        body: IndexedStack(
          index: _selectedTabIndex,
          children: const [DashboardTab(), HistoryTab()],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: OledColors.subtleBorder, width: 1),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _selectedTabIndex,
            onDestinationSelected: (idx) {
              setState(() {
                _selectedTabIndex = idx;
              });
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(
                  Icons.bedtime_outlined,
                  color: OledColors.textSecondary,
                ),
                selectedIcon: const Icon(
                  Icons.bedtime_rounded,
                  color: OledColors.warmAmber,
                ),
                label: s.tabTonight,
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: logs.isNotEmpty,
                  backgroundColor: OledColors.deepOrange,
                  label: Text('${logs.length}'),
                  child: const Icon(
                    Icons.history_rounded,
                    color: OledColors.textSecondary,
                  ),
                ),
                selectedIcon: Badge(
                  isLabelVisible: logs.isNotEmpty,
                  backgroundColor: OledColors.deepOrange,
                  label: Text('${logs.length}'),
                  child: const Icon(
                    Icons.history_rounded,
                    color: OledColors.warmAmber,
                  ),
                ),
                label: s.tabHistory,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
