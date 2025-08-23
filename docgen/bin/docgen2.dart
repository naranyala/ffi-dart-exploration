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
    final htmlBody = convertMarkdownWithMermaid(markdown);
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

String convertMarkdownWithMermaid(String markdown) {
  // More robust approach: process line by line
  final lines = markdown.split('\n');
  final processedLines = <String>[];
  final mermaidBlocks = <String>[];
  
  bool inMermaidBlock = false;
  String currentMermaidCode = '';
  
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    
    if (line.trim() == '```mermaid' || line.trim() == '```mmd') {
      inMermaidBlock = true;
      currentMermaidCode = '';
      continue;
    }
    
    if (inMermaidBlock && line.trim() == '```') {
      // End of mermaid block
      inMermaidBlock = false;
      final placeholder = '<!-- MERMAID_PLACEHOLDER_${mermaidBlocks.length} -->';
      mermaidBlocks.add(currentMermaidCode.trim());
      processedLines.add(placeholder);
      continue;
    }
    
    if (inMermaidBlock) {
      currentMermaidCode += line + '\n';
    } else {
      processedLines.add(line);
    }
  }
  
  // Convert processed markdown to HTML
  final processedMarkdown = processedLines.join('\n');
  var html = md.markdownToHtml(processedMarkdown);
  
  // Replace HTML comment placeholders with mermaid divs
  for (int i = 0; i < mermaidBlocks.length; i++) {
    final placeholder = '<!-- MERMAID_PLACEHOLDER_$i -->';
    final mermaidHtml = '<div class="mermaid">\n${mermaidBlocks[i]}\n</div>';
    html = html.replaceAll('<p>$placeholder</p>', mermaidHtml);
    html = html.replaceAll(placeholder, mermaidHtml);
  }
  
  return html;
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
    document.addEventListener('DOMContentLoaded', function() {
      console.log('Initializing Mermaid...');
      mermaid.initialize({ 
        startOnLoad: true, 
        theme: 'dark',
        themeVariables: {
          darkMode: true,
          background: '#2d2d2d',
          primaryColor: '#00bfff',
          primaryTextColor: '#ddd',
          primaryBorderColor: '#00bfff',
          lineColor: '#ddd',
          secondaryColor: '#3d3d3d',
          tertiaryColor: '#4d4d4d'
        }
      });
      
      // Debug: log mermaid elements
      const mermaidElements = document.querySelectorAll('.mermaid');
      console.log('Found ' + mermaidElements.length + ' mermaid elements');
      mermaidElements.forEach((el, i) => {
        console.log('Mermaid ' + i + ':', el.textContent.trim());
      });
    });
  </script>
  <style>
    body {
      font-family: system-ui, sans-serif;
      background: #1e1e1e;
      color: #ddd;
      padding: 1rem;
      max-width: 800px;
      margin: auto;
      line-height: 1.6;
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
      font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
      background: #2d2d2d;
      padding: 0.2rem 0.4rem;
      border-radius: 3px;
      font-size: 0.9em;
    }
    pre code {
      background: none;
      padding: 0;
    }
    ul {
      padding-left: 1.2rem;
    }
    .mermaid {
      background: #2d2d2d;
      border-radius: 6px;
      padding: 1rem;
      margin: 1rem 0;
      text-align: center;
      overflow-x: auto;
    }
    /* Ensure mermaid diagrams are visible */
    .mermaid svg {
      max-width: 100%;
      height: auto;
    }
    @media (max-width: 600px) {
      body {
        padding: 0.75rem;
      }
      pre {
        font-size: 0.9rem;
      }
      .mermaid {
        font-size: 0.8rem;
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
