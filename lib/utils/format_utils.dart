/// Utility class for formatting data to be more human-readable
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

  /// Formats a number string with dots as thousand separators
  static String formatNumberWithDots(String numberStr) {
    if (numberStr.isEmpty) return numberStr;

    final buffer = StringBuffer();
    final chars = numberStr.split('').reversed.toList();
    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(chars[i]);
    }
    return buffer.toString().split('').reversed.join('');
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
