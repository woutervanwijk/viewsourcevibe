import 'package:http/http.dart' as http;

Future<void> main() async {
  final url = Uri.parse('https://www.google.com');
  print('Probing $url...\n');

  try {
    final client = http.Client();
    final request = http.Request('HEAD', url);
    request.followRedirects =
        false; // We want to see the first response, even if redirect

    // Add curl-like user agent if desired, though not strictly built-in
    request.headers['User-Agent'] = 'curl/7.64.1';

    final streamedResponse = await client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    print('--- Status ---');
    print('Code: ${response.statusCode}');
    print('Reason: ${response.reasonPhrase}');

    print('\n--- Headers ---');
    response.headers.forEach((key, value) {
      print('$key: $value');
    });

    print('\n--- Probe Analysis ---');
    if (response.headers.containsKey('server')) {
      print('Server Software: ${response.headers['server']}');
    }
    if (response.headers.containsKey('content-type')) {
      print('Content Type: ${response.headers['content-type']}');
    }
    if (response.isRedirect) {
      print('Redirect Location: ${response.headers['location']}');
    }

    client.close();
  } catch (e) {
    print('Error: $e');
  }
}
