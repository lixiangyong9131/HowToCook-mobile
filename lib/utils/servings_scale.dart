/// Scale numeric amounts in fused ingredient lines by [servings].
///
/// Base lines are treated as 1 份 (or the recipe's default batch).
/// Ranges like `1-2` scale both ends. Non-numeric text is preserved.
List<String> scaleIngredientLines(List<String> lines, int servings) {
  if (servings <= 1) return List<String>.from(lines);
  return [for (final line in lines) scaleAmountInText(line, servings)];
}

String scaleAmountInText(String text, int servings) {
  if (servings <= 1) return text;
  return text.replaceAllMapped(RegExp(r'\d+(?:\.\d+)?'), (m) {
    final raw = m.group(0)!;
    final n = double.tryParse(raw);
    if (n == null) return raw;
    final scaled = n * servings;
    return _formatScaled(scaled, raw);
  });
}

String _formatScaled(double scaled, String original) {
  final hadDecimal = original.contains('.');
  if (!hadDecimal && scaled == scaled.roundToDouble()) {
    return scaled.round().toString();
  }
  // Keep one decimal for small values, strip trailing zeros.
  final s = scaled.toStringAsFixed(scaled.abs() < 10 ? 1 : 0);
  if (s.endsWith('.0')) return s.substring(0, s.length - 2);
  return s;
}
