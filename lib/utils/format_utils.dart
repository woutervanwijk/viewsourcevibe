import 'dart:ui' show PlatformDispatcher;

class FormatUtils {
  /// Formats a string to be more human-readable.
  /// 1. Adds human-readable durations for max-age and ma patterns.
  /// 2. Formats large numbers with dots as thousand separators.
  static String formatHumanData(String value) {
    if (value.isEmpty) return value;

    String result = value;

    // 1. Format durations if max-age= or ma= is present (case insensitive)
    final maxAgeRegex = RegExp(r'(max-age|ma)=(\d+)', caseSensitive: false);
    result = result.replaceAllMapped(maxAgeRegex, (match) {
      final prefix = match.group(1);
      final secondsStr = match.group(2)!;
      final seconds = int.tryParse(secondsStr);
      if (seconds != null) {
        return '$prefix=$secondsStr (${getHumanDuration(seconds)})';
      }
      return match.group(0)!;
    });

    // 2. Format large numbers with thousand separators (dots)
    // We target sequences of 4 or more digits that are not part of a larger word or dotted identifier
    final numberRegex = RegExp(r'(?<![\w\.])\d{4,}(?![\w\.])');
    result = result.replaceAllMapped(numberRegex, (match) {
      return formatNumberWithDots(match.group(0)!);
    });

    return result;
  }

  /// Converts seconds into a human-readable duration string
  static String getHumanDuration(int seconds) {
    if (seconds <= 0) return '0 s';
    if (seconds < 60) return '$seconds s';

    if (seconds < 3600) {
      final mins = seconds / 60;
      return '${_formatDecimal(mins)} min';
    }

    if (seconds < 86400) {
      final hours = seconds / 3600;
      return '${_formatDecimal(hours)} hour${hours == 1 ? '' : 's'}';
    }

    if (seconds < 2592000) {
      final days = seconds / 86400;
      return '${_formatDecimal(days)} day${days == 1 ? '' : 's'}';
    }

    if (seconds < 31536000) {
      final months = seconds / 2592000;
      return '${_formatDecimal(months)} month${months == 1 ? '' : 's'}';
    }

    final years = seconds / 31536000;
    return '${_formatDecimal(years)} year${years == 1 ? '' : 's'}';
  }

  /// Formats a decimal number, removing .0 if it's an integer
  static String _formatDecimal(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  /// Formats a number string with the locale-appropriate thousands separator
  static String formatNumberWithDots(String numberStr) {
    if (numberStr.isEmpty) return numberStr;

    final sep = _thousandsSeparator;
    final buffer = StringBuffer();
    final chars = numberStr.split('').reversed.toList();
    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write(sep);
      }
      buffer.write(chars[i]);
    }
    return buffer.toString().split('').reversed.join('');
  }

  /// Formats bytes as KB (always in KB, never auto-scales to MB/GB).
  /// e.g. 1234567 bytes → "1,205 KB"
  static String formatBytesAsKb(int bytes) {
    if (bytes <= 0) return '0 KB';
    final kb = (bytes / 1024).ceil();
    // Format with thousands separator
    return '${_formatWithCommas(kb)} KB';
  }

  /// Returns the locale-appropriate thousands separator.
  /// Dutch/German/Spanish/French use '.'; English uses ','.
  static String get _thousandsSeparator {
    final lang = PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    // Languages that conventionally use '.' (or a space interpreted as '.') as thousands separator
    const dotLanguages = {
      'nl',
      'de',
      'es',
      'fr',
      'pt',
      'it',
      'pl',
      'ro',
      'tr',
      'hu',
      'bg',
      'hr',
      'sr',
      'sl',
      'sk',
      'cs',
      'da',
      'nb',
      'sv',
      'fi',
      'el',
      'uk',
      'ru',
      'id',
      'ms',
      'vi',
      'th',
    };
    return dotLanguages.contains(lang) ? '.' : ',';
  }

  static String _formatWithCommas(int n) {
    final sep = _thousandsSeparator;
    final s = n.toString();
    final buffer = StringBuffer();
    final chars = s.split('').reversed.toList();
    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write(sep);
      buffer.write(chars[i]);
    }
    return buffer.toString().split('').reversed.join('');
  }

  /// Formats a size map: decoded size in KB first, then transfer size in brackets.
  /// Shows: "1.205 KB (↓ 400 KB)" when transfer size differs from decoded size.
  /// Shows: "1.205 KB" when only decoded size is available or sizes are equal.
  static String formatBytesWithTransfer(Map<String, dynamic>? sizeMap) {
    if (sizeMap == null) return '';
    final decoded = sizeMap['decoded'] as int? ?? 0;
    final transfer = sizeMap['transfer'] as int? ?? 0;

    final decodedStr = formatBytesAsKb(decoded);
    if (transfer > 0 && transfer != decoded) {
      return '$decodedStr (↓ ${formatBytesAsKb(transfer)})';
    }
    return decodedStr;
  }

  /// Formats bytes into human readable string (KB, MB, etc)
  static String formatBytes(int bytes) {
    if (bytes <= 0) return "0 b";
    if (bytes < 1024) return "$bytes b";

    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    double value = bytes.toDouble();
    int suffixIndex = 0;

    while (value >= 1024 && suffixIndex < suffixes.length - 1) {
      value /= 1024;
      suffixIndex++;
    }

    // Kilobytes and above show 1 decimal place
    return "${value.toStringAsFixed(1)} ${suffixes[suffixIndex]}";
  }
}
