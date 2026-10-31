import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ringtone_settings.dart';
import '../services/timer_alarm_service.dart';
import '../theme/app_theme.dart';

Future<void> showRingtonePickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _RingtonePickerSheet(),
  );
}

class _RingtonePickerSheet extends StatefulWidget {
  const _RingtonePickerSheet();

  @override
  State<_RingtonePickerSheet> createState() => _RingtonePickerSheetState();
}

class _RingtonePickerSheetState extends State<_RingtonePickerSheet> {
  late String _selected;
  String? _previewing;

  @override
  void initState() {
    super.initState();
    _selected = RingtoneSettings.instance.selectedId;
  }

  @override
  void dispose() {
    TimerAlarmService.instance.stopPreview();
    super.dispose();
  }

  Future<void> _preview(BuiltInRingtone tone) async {
    HapticFeedback.selectionClick();
    setState(() => _previewing = tone.id);
    await TimerAlarmService.instance.preview(tone);
  }

  Future<void> _save(BuiltInRingtone tone) async {
    HapticFeedback.lightImpact();
    await RingtoneSettings.instance.setSelected(tone.id);
    setState(() => _selected = tone.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已选择「${tone.label}」作为计时结束铃声')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.72;
    return Container(
      height: h,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTheme.softShadow(opacity: 0.22),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '计时结束铃声',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              '点右侧喇叭试听，点整行保存。计时结束会循环播放所选铃声直到手动关闭。',
              style: TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.4),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: RingtoneSettings.all.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final tone = RingtoneSettings.all[i];
                final selected = tone.id == _selected;
                return Material(
                  color: selected
                      ? AppTheme.coral.withValues(alpha: 0.12)
                      : AppTheme.cream,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _save(tone),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: selected ? AppTheme.coral : AppTheme.muted,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tone.label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: selected
                                        ? AppTheme.coral
                                        : AppTheme.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tone.description,
                                  style: const TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '试听',
                            onPressed: () => _preview(tone),
                            icon: Icon(
                              _previewing == tone.id
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_up_outlined,
                              color: AppTheme.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
