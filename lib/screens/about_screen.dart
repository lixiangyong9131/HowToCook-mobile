import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/recipe_repository.dart';
import '../services/update_service.dart';
import '../services/ringtone_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/ringtone_picker_sheet.dart';
import 'categories_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '…';
  bool _checking = false;
  double? _downloadProgress;
  CachedApk? _cachedApk;
  String _ringtoneLabel = '…';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _version = '${i.version}+${i.buildNumber}');
    });
    _refreshCachedApk();
    RingtoneSettings.instance.load().then((_) {
      if (mounted) {
        setState(() => _ringtoneLabel = RingtoneSettings.instance.selected.label);
      }
    });
  }

  Future<void> _refreshCachedApk() async {
    final c = await UpdateService.cachedApk();
    if (mounted) setState(() => _cachedApk = c);
  }

  Future<void> _checkUpdate() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _downloadProgress = null;
    });
    try {
      if (!kIsWeb && !Platform.isAndroid) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('检查更新'),
            content: const Text(
              'iOS / 非 Android 请到 GitHub Release 下载最新包：\n'
              'https://github.com/lixiangyong9131/HowToCook-mobile/releases',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
        return;
      }

      final latest = await UpdateService.checkLatest();
      if (!mounted) return;
      if (latest == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已是最新版本')),
        );
        return;
      }
      final cached = _cachedApk != null &&
          (_cachedApk!.tag == latest.tag ||
              _cachedApk!.url == (latest.apkUrl ?? ''));
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('发现新版本'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '版本 ${latest.tag}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '大小 ${latest.apkSizeLabel}',
                style: const TextStyle(color: AppTheme.muted),
              ),
              const SizedBox(height: 4),
              Text(
                '当前 $_version',
                style: const TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('稍后'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.navy,
                foregroundColor: AppTheme.neon,
              ),
              onPressed: latest.apkUrl == null
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: Text(cached ? '继续安装' : '下载并安装'),
            ),
          ],
        ),
      );
      if (go == true && latest.apkUrl != null) {
        setState(() => _downloadProgress = 0);
        // Reuses on-disk APK for this tag/url when present — no re-download.
        final msg = await UpdateService.downloadAndInstall(
          latest.apkUrl!,
          tag: latest.tag,
          onProgress: (p) {
            if (mounted) setState(() => _downloadProgress = p);
          },
        );
        if (!mounted) return;
        await _refreshCachedApk();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
        );
      } else if (latest.apkUrl == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('未找到 APK，请打开 ${latest.htmlUrl}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('检查更新失败'),
          content: Text('$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
          _downloadProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = RecipeRepository.instance.db;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 40),
          children: [
            const Text(
              '我的',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppTheme.coral,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                boxShadow: AppTheme.softShadow(opacity: 0.2),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/branding/app_icon_512.png',
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '程序员做饭指南',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '版本 $_version · 离线可用',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _ActionTile(
              icon: Icons.grid_view_rounded,
              title: '分类浏览',
              subtitle: '叠卡展开动效入口',
              color: AppTheme.coral,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                );
              },
            ),
            const SizedBox(height: 10),
            _ActionTile(
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
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.system_update_rounded,
              title: _checking ? '正在检查…' : '检查更新',
              subtitle: _downloadProgress != null
                  ? '下载中 ${(_downloadProgress! * 100).toStringAsFixed(0)}%'
                  : (_cachedApk != null
                      ? '已缓存 ${_cachedApk!.tag.isEmpty ? "安装包" : _cachedApk!.tag}'
                      : '检查 GitHub 新版本'),
              color: AppTheme.neon,
              onTap: _checking ? null : _checkUpdate,
              trailing: _downloadProgress != null
                  ? SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        value: _downloadProgress,
                        strokeWidth: 3,
                        color: AppTheme.navy,
                      ),
                    )
                  : _checking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
            ),

            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.balance_rounded,
              title: '开源许可',
              subtitle: 'HowToCook 原文 Unlicense',
              color: AppTheme.purple,
              onTap: () async {
                final text = await rootBundle.loadString('assets/HOWTOCOOK_LICENSE');
                if (!context.mounted) return;
                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) {
                    return Container(
                      margin: const EdgeInsets.all(12),
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(ctx).height * 0.75,
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'HowToCook LICENSE',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(ctx),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                text,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: AppTheme.ink,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 14),
            _InfoCard(
              title: '离线菜谱',
              accent: AppTheme.neon,
              children: [
                Text('共 ${db?.recipes.length ?? 0} 道菜已打包进 App，可完全离线浏览。'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
    this.trailing,
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
              trailing ??
                  const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Color accent;
  final List<Widget> children;
  const _InfoCard({
    required this.title,
    required this.children,
    this.accent = AppTheme.neon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: AppTheme.softShadow(opacity: 0.08),
        border: Border.all(color: AppTheme.purple.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
