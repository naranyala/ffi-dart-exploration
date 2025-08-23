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
    try {
      final markdown = await file.readAsString();
      final htmlBody = processMarkdown(markdown);
      final title = extractTitle(markdown) ?? file.uri.pathSegments.last.replaceAll('.md', '');
      final filename = file.uri.pathSegments.last.replaceAll('.md', '.html');
      final wrappedHtml = wrapHtml(title, htmlBody, pages.keys.toList());
      
      await File('${outputDir.path}/$filename').writeAsString(wrappedHtml);
      pages[filename] = title;
      print('✅ Generated: $filename');
    } catch (e) {
      print('❌ Error processing ${file.path}: $e');
    }
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

String processMarkdown(String markdown) {
  try {
    // Step 1: Extract metadata
    final parsed = extractMetadata(markdown);
    
    // Step 2: Process mermaid blocks
    final withMermaid = processMermaidBlocks(parsed['content'] as String);
    
    // Step 3: Convert to HTML
    var html = md.markdownToHtml(withMermaid['markdown'] as String);
    
    // Step 4: Replace mermaid placeholders
    html = replaceMermaidPlaceholders(html, withMermaid['blocks'] as List<String>);
    
    // Step 5: Add metadata if present
    final metadata = parsed['metadata'] as Map<String, String>;
    if (metadata.isNotEmpty) {
      html = buildMetadataHtml(metadata) + '\n' + html;
    }
    
    return html;
  } catch (e) {
    print('Error processing markdown: $e');
    return '<p>Error processing markdown content</p>';
  }
}

Map<String, dynamic> extractMetadata(String markdown) {
  final lines = markdown.split('\n');
  final metadata = <String, String>{};
  var contentStart = 0;
  
  // Simple frontmatter parsing
  if (lines.isNotEmpty && lines[0].trim() == '---') {
    for (int i = 1; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        contentStart = i + 1;
        break;
      }
      
      final line = lines[i].trim();
      if (line.contains(':')) {
        final colonIndex = line.indexOf(':');
        final key = line.substring(0, colonIndex).trim();
        final value = line.substring(colonIndex + 1).trim();
        // Remove quotes
        final cleanValue = value.replaceAll('"', '').replaceAll("'", '');
        metadata[key] = cleanValue;
      }
    }
  }
  
  final content = lines.skip(contentStart).join('\n');
  return {'metadata': metadata, 'content': content};
}

Map<String, dynamic> processMermaidBlocks(String content) {
  final lines = content.split('\n');
  final processedLines = <String>[];
  final mermaidBlocks = <String>[];
  
  var inMermaid = false;
  var currentBlock = <String>[];
  
  for (final line in lines) {
    if (line.trim() == '```mermaid' || line.trim() == '```mmd') {
      inMermaid = true;
      currentBlock.clear();
      continue;
    }
    
    if (inMermaid && line.trim() == '```') {
      inMermaid = false;
      mermaidBlocks.add(currentBlock.join('\n'));
      processedLines.add('MERMAID_PLACEHOLDER_${mermaidBlocks.length - 1}');
      continue;
    }
    
    if (inMermaid) {
      currentBlock.add(line);
    } else {
      processedLines.add(line);
    }
  }
  
  return {
    'markdown': processedLines.join('\n'),
    'blocks': mermaidBlocks
  };
}

String replaceMermaidPlaceholders(String html, List<String> blocks) {
  for (int i = 0; i < blocks.length; i++) {
    final placeholder = 'MERMAID_PLACEHOLDER_$i';
    final mermaidHtml = '<div class="mermaid">\n${blocks[i]}\n</div>';
    html = html.replaceAll('<p>$placeholder</p>', mermaidHtml);
    html = html.replaceAll(placeholder, mermaidHtml);
  }
  return html;
}

String buildMetadataHtml(Map<String, String> metadata) {
  final buffer = StringBuffer();
  buffer.writeln('<details class="metadata">');
  buffer.writeln('<summary>📄 Document Metadata</summary>');
  buffer.writeln('<div class="metadata-content">');
  
  metadata.forEach((key, value) {
    final formattedKey = formatKey(key);
    final formattedValue = formatValue(value);
    buffer.writeln('<div class="metadata-item">');
    buffer.writeln('<strong class="metadata-key">$formattedKey:</strong>');
    buffer.writeln('<span class="metadata-value">$formattedValue</span>');
    buffer.writeln('</div>');
  });
  
  buffer.writeln('</div>');
  buffer.writeln('</details>');
  return buffer.toString();
}

String formatKey(String key) {
  // Simple key formatting
  return key
      .replaceAll('_', ' ')
      .split(' ')
      .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
      .join(' ');
}

String formatValue(String value) {
  // Simple date check (YYYY-MM-DD)
  if (value.length == 10 && value[4] == '-' && value[7] == '-') {
    return '<time datetime="$value">$value</time>';
  }
  
  // URL check
  if (value.startsWith('http')) {
    return '<a href="$value" target="_blank" rel="noopener">$value</a>';
  }
  
  // Email check
  if (value.contains('@') && value.contains('.')) {
    return '<a href="mailto:$value">$value</a>';
  }
  
  return value;
}

String? extractTitle(String markdown) {
  // Check metadata first
  final parsed = extractMetadata(markdown);
  final metadata = parsed['metadata'] as Map<String, String>;
  
  if (metadata.containsKey('title')) {
    return metadata['title'];
  }
  
  // Check for H1
  final content = parsed['content'] as String;
  final lines = content.split('\n');
  
  for (final line in lines) {
    if (line.startsWith('# ')) {
      return line.substring(2).trim();
    }
  }
  
  return null;
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
    /* Metadata styling */
    .metadata {
      background: #2a2a2a;
      border: 1px solid #444;
      border-radius: 6px;
      margin: 1rem 0 2rem 0;
    }
    
    .metadata summary {
      padding: 0.75rem 1rem;
      cursor: pointer;
      font-weight: 600;
      color: #00bfff;
      user-select: none;
      border-radius: 6px;
      transition: background-color 0.2s ease;
    }
    
    .metadata summary:hover {
      background: #333;
    }
    
    .metadata-content {
      padding: 0 1rem 1rem 1rem;
      border-top: 1px solid #444;
    }
    
    .metadata-item {
      display: flex;
      margin: 0.5rem 0;
      align-items: flex-start;
      gap: 0.5rem;
    }
    
    .metadata-key {
      color: #888;
      min-width: 120px;
      font-size: 0.9em;
      flex-shrink: 0;
    }
    
    .metadata-value {
      color: #ddd;
      font-size: 0.9em;
      word-break: break-word;
    }
    
    .metadata-value time {
      color: #90EE90;
      font-family: monospace;
    }
    
    .metadata-value a {
      color: #00bfff;
      word-break: break-all;
    }
    
    .metadata[open] summary {
      border-bottom: 1px solid #444;
      margin-bottom: 0;
      border-radius: 6px 6px 0 0;
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
      .metadata-item {
        flex-direction: column;
        gap: 0.25rem;
      }
      .metadata-key {
        min-width: auto;
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
