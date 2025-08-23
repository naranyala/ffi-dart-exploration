import 'dart:io';
import 'package:markdown/markdown.dart' as md;

final inputDir = Directory('content');
final outputDir = Directory('public');

Future<void> main() async {
  if (!await inputDir.exists()) {
    print('❌ Missing input directory: content/');
    exit(1);
  }

  await outputDir.create(recursive: true);

  final files = inputDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.md'))
      .toList();

  final pages = <String, String>{}; // filename → title

  for (var file in files) {
    final markdown = await file.readAsString();
    final htmlBody = md.markdownToHtml(markdown);
    final title = extractTitle(markdown) ?? file.uri.pathSegments.last.replaceAll('.md', '');
    final filename = file.uri.pathSegments.last.replaceAll('.md', '.html');
    final wrappedHtml = wrapHtml(title, htmlBody, pages.keys.toList());

    await File('${outputDir.path}/$filename').writeAsString(wrappedHtml);
    pages[filename] = title;
    print('✅ Generated: $filename');
  }

  // Generate index.html
  final indexBody = '''
    <h1>Welcome</h1>
    <p>This site contains the following articles:</p>
    <ul>
    ${pages.entries.map((e) => '<li><a href="${e.key}">${e.value}</a></li>').join('\n')}
    </ul>
    ''';
  final indexHtml = wrapHtml('Home', indexBody, pages.keys.toList(), isIndex: true);
  await File('${outputDir.path}/index.html').writeAsString(indexHtml);
}

String? extractTitle(String markdown) {
  final lines = markdown.split('\n');
  final h1 = lines.firstWhere((line) => line.startsWith('# '), orElse: () => '');
  return h1.isNotEmpty ? h1.replaceFirst('# ', '').trim() : null;
}

String wrapHtml(String title, String body, List<String> navLinks, {bool isIndex = false}) => '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title</title>

  <!-- Prism.js for syntax highlighting -->
  <link href="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/themes/prism-tomorrow.min.css" rel="stylesheet" />
  <script src="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/prism.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/components/prism-dart.min.js"></script>

  <!-- Mermaid.js for diagrams -->
  <script src="https://cdn.jsdelivr.net/npm/mermaid@10.9.0/dist/mermaid.min.js"></script>
  <script>
    mermaid.initialize({ startOnLoad: true, theme: 'dark' });
  </script>

  <style>
    body {
      font-family: system-ui, sans-serif;
      background: #1e1e1e;
      color: #ddd;
      padding: 1rem;
      max-width: 800px;
      margin: auto;
    }

    h1, h2, h3 {
      color: #00bfff;
    }

    a {
      color: #00bfff;
      text-decoration: none;
    }

    a:hover {
      text-decoration: underline;
    }

    .back-link {
      margin-bottom: 1rem;
      display: block;
    }

    pre {
      background: #2d2d2d;
      padding: 1rem;
      overflow-x: auto;
      border-radius: 6px;
    }

    code {
      font-family: monospace;
    }

    ul {
      padding-left: 1.2rem;
    }

    .mermaid {
      background: #2d2d2d;
      border-radius: 6px;
      padding: 1rem;
      margin: 1rem 0;
    }

    @media (max-width: 600px) {
      body {
        padding: 0.75rem;
      }

      pre {
        font-size: 0.9rem;
      }
    }
  </style>
</head>
<body>
  ${isIndex ? '' : '<a class="back-link" href="index.html">← Back to Home</a>'}
  $body
</body>
</html>
''';

