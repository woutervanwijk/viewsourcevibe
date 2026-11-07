/// Last segment of a file path with `/` or `\` separators.
String fileNameOfPath(String path) =>
    path.replaceAll('\\', '/').split('/').last;
