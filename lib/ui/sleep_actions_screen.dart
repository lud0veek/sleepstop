import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_info.dart';
import 'package:intl/intl.dart';
import '../l10n/app_strings.dart';
import '../models/sleep_settings.dart';
import '../providers/settings_provider.dart';
import '../sleep_actions/actions/webhook_action.dart';
import '../sleep_actions/sleep_action_dispatcher.dart';
import '../sleep_actions/sleep_action_status.dart';
import '../sleep_actions/sleep_event_bus.dart';
import 'theme/oled_theme.dart';
import 'widgets/settings_blocks.dart';

/// "When I fall asleep": master switch + one section per action.
/// Step 1 ships the frame; the action sections are filled in by the
/// intent, webhook and lights steps.
class SleepActionsScreen extends ConsumerWidget {
  const SleepActionsScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SleepActionsScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final s = ref.watch(appStringsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final statuses = ref.watch(sleepActionStatusesProvider);
    final actions = settings.sleepActions;
    final registered = ref.read(sleepActionsProvider).map((a) => a.id).toSet();

    return Scaffold(
      backgroundColor: OledColors.trueBlack,
      appBar: AppBar(
        backgroundColor: OledColors.trueBlack,
        surfaceTintColor: Colors.transparent,
        title: Text(
          s.sleepActionsTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: OledColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Text(
              s.sleepActionsIntro,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: OledColors.textSecondary,
              ),
            ),
          ),
          SettingsSection(
            icon: Icons.auto_awesome_rounded,
            accent: OledColors.gold,
            title: s.sleepActionsTitle,
            children: [
              SettingsToggle(
                title: s.sleepActionsMaster,
                subtitle: s.sleepActionsMasterSub,
                value: actions.enabled,
                onChanged: (v) =>
                    notifier.updateSleepActions((c) => c.copyWith(enabled: v)),
              ),
            ],
          ),
          _ActionSection(
            id: 'lights',
            icon: Icons.lightbulb_outline_rounded,
            accent: OledColors.warmAmber,
            title: s.actionLightsTitle,
            subtitle: s.actionLightsSub,
            enabled: actions.lights.enabled,
            available: registered.contains('lights'),
            masterOn: actions.enabled,
            status: statuses['lights'],
            s: s,
            onToggle: (v) => notifier.updateSleepActions(
              (c) => c.copyWith(lights: c.lights.copyWith(enabled: v)),
            ),
            onTest: () => _test(ref, 'lights', settings),
          ),
          _ActionSection(
            id: 'intent',
            icon: Icons.cell_tower_rounded,
            accent: OledColors.softIndigo,
            title: s.actionIntentTitle,
            subtitle: s.actionIntentSub,
            enabled: actions.intent.enabled,
            available: registered.contains('intent'),
            masterOn: actions.enabled,
            status: statuses['intent'],
            s: s,
            onToggle: (v) => notifier.updateSleepActions(
              (c) => c.copyWith(intent: c.intent.copyWith(enabled: v)),
            ),
            onTest: () => _test(ref, 'intent', settings),
            details: _IntentDetails(s: s),
          ),
          _ActionSection(
            id: 'webhook',
            icon: Icons.webhook_rounded,
            accent: OledColors.calmTeal,
            title: s.actionWebhookTitle,
            subtitle: s.actionWebhookSub,
            enabled: actions.webhook.enabled,
            available: registered.contains('webhook'),
            masterOn: actions.enabled,
            status: statuses['webhook'],
            s: s,
            onToggle: (v) => notifier.updateSleepActions(
              (c) => c.copyWith(webhook: c.webhook.copyWith(enabled: v)),
            ),
            onTest: () => _test(ref, 'webhook', settings),
            details: _WebhookDetails(s: s, settings: settings.sleepActions.webhook),
          ),
        ],
      ),
    );
  }

  Future<void> _test(WidgetRef ref, String id, SleepSettings settings) {
    return ref.read(sleepActionDispatcherProvider).runSingle(
      id,
      SleepDetectedEvent(
        timestamp: DateTime.now(),
        mode: settings.preferredMode,
        source: 'test',
      ),
    );
  }
}

class _ActionSection extends StatelessWidget {
  final String id;
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool available;
  final bool masterOn;
  final SleepActionStatus? status;
  final AppStrings s;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTest;
  final Widget? details;

  const _ActionSection({
    required this.id,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.available,
    required this.masterOn,
    required this.status,
    required this.s,
    required this.onToggle,
    required this.onTest,
    this.details,
  });

  @override
  Widget build(BuildContext context) {
    final st = status ?? SleepActionStatus.idle;
    final (label, color) = switch (st.outcome) {
      SleepActionOutcome.idle => (s.actionStatusIdle, OledColors.textMuted),
      SleepActionOutcome.skipped => (s.actionStatusSkipped, OledColors.textMuted),
      SleepActionOutcome.running => (s.actionStatusRunning, OledColors.warmAmber),
      SleepActionOutcome.success => (s.actionStatusSuccess, OledColors.calmTeal),
      SleepActionOutcome.failed => (s.actionStatusFailed, OledColors.mutedRose),
      SleepActionOutcome.timedOut => (s.actionStatusTimeout, OledColors.mutedRose),
    };
    final when = st.at != null ? ' • ${DateFormat('HH:mm').format(st.at!)}' : '';
    final detail = st.message != null && st.message!.isNotEmpty
        ? ' • ${st.message}'
        : '';

    return SettingsSection(
      icon: icon,
      accent: accent,
      title: title,
      children: [
        SettingsToggle(
          title: title,
          subtitle: available ? subtitle : '$subtitle\n${s.actionComingSoon}',
          value: enabled && available,
          onChanged: available ? onToggle : null,
        ),
        if (available && details != null) ...[
          const SizedBox(height: 4),
          details!,
        ],
        if (available) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$label$when$detail',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: color),
                ),
              ),
              TextButton.icon(
                onPressed:
                    st.outcome == SleepActionOutcome.running ? null : onTest,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(s.actionTestNow),
                style: TextButton.styleFrom(foregroundColor: accent),
              ),
            ],
          ),
          if (!masterOn && enabled)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                s.sleepActionsSummary(0),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: OledColors.textSecondary,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Exact broadcast action + extras, with a copy button, for Tasker/Automate.
class _IntentDetails extends StatelessWidget {
  final AppStrings s;
  const _IntentDetails({required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: OledColors.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OledColors.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.intentActionLabel,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: OledColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Expanded(
                child: SelectableText(
                  kSleepDetectedAction,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontFamily: 'monospace',
                    color: OledColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: s.copyLabel,
                icon: const Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: OledColors.softIndigo,
                ),
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: kSleepDetectedAction),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(s.copiedToast),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: OledColors.elevatedSurface,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            s.intentExtrasHelp,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: OledColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Webhook URL (HTTPS only) and optional HMAC secret.
class _WebhookDetails extends ConsumerStatefulWidget {
  final AppStrings s;
  final WebhookActionSettings settings;
  const _WebhookDetails({required this.s, required this.settings});

  @override
  ConsumerState<_WebhookDetails> createState() => _WebhookDetailsState();
}

class _WebhookDetailsState extends ConsumerState<_WebhookDetails> {
  late final TextEditingController _url = TextEditingController(
    text: widget.settings.url,
  );
  final TextEditingController _secret = TextEditingController();
  String? _urlError;
  bool _savingSecret = false;

  @override
  void dispose() {
    _url.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _saveUrl() async {
    final s = widget.s;
    final raw = _url.text.trim();
    final problem = raw.isEmpty ? null : WebhookUrlValidator.validate(raw);
    setState(() {
      _urlError = switch (problem) {
        null => null,
        'not_https' => s.webhookHttpsOnly,
        _ => s.webhookInvalidUrl,
      };
    });
    if (problem != null) return;
    await ref.read(settingsProvider.notifier).updateSleepActions(
      (c) => c.copyWith(webhook: c.webhook.copyWith(url: raw)),
    );
  }

  Future<void> _saveSecret() async {
    final value = _secret.text.trim();
    if (value.isEmpty) return;
    setState(() => _savingSecret = true);
    await ref.read(webhookSecretStoreProvider).write(value);
    await ref.read(settingsProvider.notifier).updateSleepActions(
      (c) => c.copyWith(webhook: c.webhook.copyWith(hasSecret: true)),
    );
    _secret.clear();
    if (mounted) setState(() => _savingSecret = false);
  }

  Future<void> _clearSecret() async {
    await ref.read(webhookSecretStoreProvider).clear();
    await ref.read(settingsProvider.notifier).updateSleepActions(
      (c) => c.copyWith(webhook: c.webhook.copyWith(hasSecret: false)),
    );
  }

  InputDecoration _decoration(String hint, {String? error, Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: OledColors.textMuted, fontSize: 13),
        errorText: error,
        isDense: true,
        filled: true,
        fillColor: OledColors.elevatedSurface,
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: OledColors.subtleBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: OledColors.calmTeal),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: OledColors.mutedRose),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: OledColors.mutedRose),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final hasSecret = widget.settings.hasSecret;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsLabel(s.webhookUrlLabel),
        const SizedBox(height: 6),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          style: const TextStyle(fontSize: 13.5, color: OledColors.textPrimary),
          decoration: _decoration('https://…', error: _urlError),
          onEditingComplete: _saveUrl,
          onTapOutside: (_) {
            FocusScope.of(context).unfocus();
            _saveUrl();
          },
        ),
        const SizedBox(height: 12),
        SettingsLabel(s.webhookSecretLabel),
        const SizedBox(height: 6),
        if (hasSecret)
          Row(
            children: [
              const Icon(
                Icons.lock_rounded,
                size: 16,
                color: OledColors.calmTeal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.webhookSecretStored,
                  style: const TextStyle(
                    fontSize: 13,
                    color: OledColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: _clearSecret,
                child: Text(
                  s.webhookSecretRemove,
                  style: const TextStyle(color: OledColors.mutedRose),
                ),
              ),
            ],
          )
        else
          TextField(
            controller: _secret,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontSize: 13.5, color: OledColors.textPrimary),
            decoration: _decoration(
              s.webhookSecretHint,
              suffix: IconButton(
                tooltip: s.webhookSecretSave,
                icon: _savingSecret
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.check_rounded,
                        color: OledColors.calmTeal,
                      ),
                onPressed: _savingSecret ? null : _saveSecret,
              ),
            ),
            onSubmitted: (_) => _saveSecret(),
          ),
        const SizedBox(height: 6),
        Text(
          s.webhookHelp,
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.35,
            color: OledColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
