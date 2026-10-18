import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_logs_provider.dart';
import '../providers/settings_provider.dart';
import '../services/foreground_task_service.dart';
import '../services/notification_service.dart';
import '../sleep_actions/sleep_action_dispatcher.dart';
import 'dashboard_tab.dart';
import 'history_tab.dart';
import 'pro_unlock_sheet.dart';
import 'settings_screen.dart';
import 'theme/oled_theme.dart';

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
    final s = ref.read(appStringsProvider);
    // Subscribes the "When I fall asleep" dispatcher to the sleep event bus.
    ref.read(sleepActionDispatcherProvider);
    ForegroundTaskService.instance.init(
      channelName: s.fgChannelName,
      channelDescription: s.fgChannelDesc,
    );
    // Runtime permissions are requested contextually, right before the first
    // sleep session (see DashboardTab), never at launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.init();
    });
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
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => ProUnlockSheet.show(context),
              icon: Icon(
                settings.isProUnlocked
                    ? Icons.verified_rounded
                    : Icons.workspace_premium_rounded,
                color: settings.isProUnlocked
                    ? OledColors.gold
                    : OledColors.warmAmber,
                size: 21,
              ),
              tooltip: s.unlockProTitle,
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => SettingsScreen.open(context),
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
