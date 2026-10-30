import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/recipe.dart';

class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;
  const RecipeDetailScreen({super.key, required this.recipe});

  /// Drop local image markdown so offline text stays clean.
  String get _body {
    return recipe.markdown
        .replaceAll(RegExp(r'!\[.*?\]\(\./[^)]+\)'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
      ),
      body: Markdown(
        data: _body,
        selectable: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          h1: Theme.of(context).textTheme.headlineSmall,
          h2: Theme.of(context).textTheme.titleLarge,
          p: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
      ),
    );
  }
}
