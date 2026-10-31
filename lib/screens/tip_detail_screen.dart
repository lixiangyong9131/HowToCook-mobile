import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/tip.dart';
import '../services/process_image_service.dart';
import '../theme/app_theme.dart';

class TipDetailScreen extends StatelessWidget {
  final KitchenTip tip;
  const TipDetailScreen({super.key, required this.tip});

  @override
  Widget build(BuildContext context) {
    final jpeg = ProcessImageService.instance.tipAssetPath(tip.path);
    final sheet = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      h1: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w900,
        color: AppTheme.ink,
        height: 1.25,
      ),
      h2: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: AppTheme.ink,
        height: 1.3,
      ),
      h3: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: AppTheme.ink,
      ),
      p: const TextStyle(
        fontSize: 15.5,
        height: 1.55,
        color: AppTheme.ink,
      ),
      listBullet: const TextStyle(color: AppTheme.coral, fontSize: 16),
      blockquoteDecoration: BoxDecoration(
        color: AppTheme.softCoral.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
              color: AppTheme.coral.withValues(alpha: 0.7), width: 4),
        ),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.navy.withValues(alpha: 0.12)),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          tip.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          if (jpeg != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 9 / 12,
                child: Image.asset(
                  jpeg,
                  fit: BoxFit.cover,
                  cacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round().clamp(400, 1600),
                ),
              ),
            )
          else
            Container(
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFD6E4F0),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Image.asset(
                ProcessImageService.tipPlaceholderAsset(tip.path),
                width: 56,
                height: 56,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.lightbulb_outline,
                  size: 40,
                  color: AppTheme.navy,
                ),
              ),
            ),
          const SizedBox(height: 16),
          MarkdownBody(data: tip.markdown, styleSheet: sheet),
        ],
      ),
    );
  }
}
