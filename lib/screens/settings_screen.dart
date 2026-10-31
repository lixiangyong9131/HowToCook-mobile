import 'package:flutter/material.dart';

import '../services/ringtone_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/ringtone_picker_sheet.dart';

/// Preferences opened from 「我的」. Currently only the timer ringtone.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _ringtoneLabel = '…';

  @override
  void initState() {
    super.initState();
    RingtoneSettings.instance.load().then((_) {
      if (mounted) {
        setState(() => _ringtoneLabel = RingtoneSettings.instance.selected.label);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
        children: [
          _SettingsTile(
            icon: Icons.notifications_active_rounded,
            title: '计时结束铃声',
            subtitle: '当前：$_ringtoneLabel · 点此选择与试听',
            color: const Color(0xFFFFB4A2),
            onTap: () async {
              await showRingtonePickerSheet(context);
              if (!mounted) return;
              setState(() =>
                  _ringtoneLabel = RingtoneSettings.instance.selected.label);
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            boxShadow: AppTheme.softShadow(opacity: 0.08),
            border: Border.all(color: AppTheme.purple.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppTheme.navy),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}
