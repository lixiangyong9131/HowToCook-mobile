import 'package:shared_preferences/shared_preferences.dart';

class BuiltInRingtone {
  final String id;
  final String label;
  final String description;
  /// Path under assets/ (AssetSource uses without "assets/" prefix).
  final String assetRelative;
  /// Android res/raw name (no extension).
  final String rawName;

  const BuiltInRingtone({
    required this.id,
    required this.label,
    required this.description,
    required this.assetRelative,
    required this.rawName,
  });

  String get assetSourcePath => assetRelative; // e.g. sounds/alarm_classic.wav
}

/// Built-in timer end ringtones (original short tones, free to redistribute).
class RingtoneSettings {
  RingtoneSettings._();
  static final RingtoneSettings instance = RingtoneSettings._();

  static const prefKey = 'timer_ringtone_id';

  static const List<BuiltInRingtone> all = [
    BuiltInRingtone(
      id: 'classic',
      label: '经典双音',
      description: '闹钟感双频提示',
      assetRelative: 'sounds/alarm_classic.wav',
      rawName: 'alarm_classic',
    ),
    BuiltInRingtone(
      id: 'chime',
      label: '清脆铃声',
      description: '上行三音阶',
      assetRelative: 'sounds/alarm_chime.wav',
      rawName: 'alarm_chime',
    ),
    BuiltInRingtone(
      id: 'kitchen',
      label: '厨房哔哔',
      description: '短促电子提示音',
      assetRelative: 'sounds/alarm_kitchen.wav',
      rawName: 'alarm_kitchen',
    ),
    BuiltInRingtone(
      id: 'bell',
      label: '温润铃',
      description: '偏低柔和钟声',
      assetRelative: 'sounds/alarm_bell.wav',
      rawName: 'alarm_bell',
    ),
    BuiltInRingtone(
      id: 'ping',
      label: '明亮叮咚',
      description: '高音回声叮',
      assetRelative: 'sounds/alarm_ping.wav',
      rawName: 'alarm_ping',
    ),
  ];

  String _id = 'classic';
  bool _loaded = false;

  String get selectedId => _id;

  BuiltInRingtone get selected =>
      all.firstWhere((r) => r.id == _id, orElse: () => all.first);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(prefKey);
    if (id != null && all.any((r) => r.id == id)) {
      _id = id;
    }
    _loaded = true;
  }

  Future<void> setSelected(String id) async {
    if (!all.any((r) => r.id == id)) return;
    _id = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, id);
  }
}
