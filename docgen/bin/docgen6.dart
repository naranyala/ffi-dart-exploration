import 'dart:io';
import 'package:markdown/markdown.dart' as md;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;

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
  var totalFiles = 0;
  var skippedFiles = 0;
  var processedFiles = 0;

  for (var file in files) {
    totalFiles++;
    final filename = file.uri.pathSegments.last;

    try {
      final markdown = await file.readAsString();

      // Validate required metadata
      final validationResult = validateMetadata(markdown, filename);
      if (!validationResult['isValid']) {
        skippedFiles++;
        print('⚠️  Skipped $filename: ${validationResult['reason']}');
        continue;
      }

      final htmlBody = processMarkdown(markdown);
      final title = extractTitle(markdown) ?? filename.replaceAll('.md', '');
      final outputFilename = filename.replaceAll('.md', '.html');
      final wrappedHtml = wrapHtml(title, htmlBody, pages.keys.toList());

      await File('${outputDir.path}/$outputFilename').writeAsString(wrappedHtml);
      pages[outputFilename] = title;
      processedFiles++;
      print('✅ Generated: $outputFilename');
    } catch (e) {
      skippedFiles++;
      print('❌ Error processing $filename: $e');
    }
  }

  // Print summary
  print('\n📊 Processing Summary:');
  print('   - Total markdown files found: $totalFiles');
  print('   - Successfully processed: $processedFiles');
  print('   - Skipped/Failed: $skippedFiles');

final sortedPages = pages.entries.toList()
  ..sort((a, b) {
    // Load metadata for each file to get date_updated
    final aMeta = loadMetadataForFile('${inputDir.path}/${a.key.replaceAll('.html', '.md')}');
    final bMeta = loadMetadataForFile('${inputDir.path}/${b.key.replaceAll('.html', '.md')}');

    final aDate = aMeta['date_updated'] ?? aMeta['date_created'] ?? '1970-01-01';
    final bDate = bMeta['date_updated'] ?? bMeta['date_created'] ?? '1970-01-01';

    return bDate.compareTo(aDate); // Newest first
  });

final indexBody = '''
  <h1>Welcome</h1>
  <p>Recently updated articles:</p>
  <ul class="article-list">
    ${sortedPages.map((entry) {
      final meta = loadMetadataForFile('${inputDir.path}/${entry.key.replaceAll('.html', '.md')}');
      final date = meta['date_updated'] ?? meta['date_created'] ?? 'Unknown';
      return '<li><a href="${entry.key}">[$date] ${entry.value}</a></li>';
    }).join('\n')}
  </ul>
''';

  final indexHtml = wrapHtml('Home', indexBody, pages.keys.toList(), isIndex: true);
  await File('${outputDir.path}/index.html').writeAsString(indexHtml);
}

Map<String, String> loadMetadataForFile(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) return {};

  try {
    final content = file.readAsStringSync();
    final lines = content.split('\n');
    final metadata = <String, String>{};
    int i = 0;

    if (lines.isNotEmpty && lines[0].trim() == '---') {
      for (i = 1; i < lines.length; i++) {
        if (lines[i].trim() == '---') break;
        final line = lines[i].trim();
        if (line.contains(':')) {
          final parts = line.split(':').map((s) => s.trim()).toList();
          final key = parts[0];
          final value = parts.length > 1 ? parts.sublist(1).join(':').replaceAll('"', '').replaceAll("'", '') : '';
          metadata[key] = value;
        }
      }
    }
    return metadata;
  } catch (e) {
    print('⚠️  Failed to load metadata from $filePath: $e');
    return {};
  }
}

Map<String, dynamic> validateMetadata(String markdown, String filename) {
  final parsed = extractMetadata(markdown);
  final metadata = parsed['metadata'] as Map<String, String>;

  // === CHECK: Required fields exist ===
  final requiredFields = ['is_public', 'date_created', 'date_updated'];
  for (final field in requiredFields) {
    if (!metadata.containsKey(field) || metadata[field]!.trim().isEmpty) {
      return {
        'isValid': false,
        'reason': 'Missing required metadata field: "$field"'
      };
    }
  }

  // === VALIDATE: is_public → must be "true" or "false" ===
  final isPublic = metadata['is_public']!.trim().toLowerCase();
  if (!['true', 'false'].contains(isPublic)) {
    return {
      'isValid': false,
      'reason': 'Invalid value for "is_public": "$isPublic" (must be "true" or "false")'
    };
  }

  // If not public, skip
  if (isPublic == 'false') {
    return {
      'isValid': false,
      'reason': 'File is not public (is_public: false)'
    };
  }

  // === VALIDATE: date_created and date_updated → YYYY-MM-DD ===
  final created = metadata['date_created']!.trim();
  final updated = metadata['date_updated']!.trim();

  if (!isValidDateFormat(created)) {
    return {
      'isValid': false,
      'reason': 'Invalid format for "date_created": "$created" (expected YYYY-MM-DD)'
    };
  }

  if (!isValidDateFormat(updated)) {
    return {
      'isValid': false,
      'reason': 'Invalid format for "date_updated": "$updated" (expected YYYY-MM-DD)'
    };
  }

  // Optional: Enforce that updated >= created
  if (updated.compareTo(created) < 0) {
    return {
      'isValid': false,
      'reason': '"date_updated" ($updated) cannot be earlier than "date_created" ($created)'
    };
  }

  return {
    'isValid': true,
    'reason': 'All metadata checks passed'
  };
}

bool isValidDateFormat(String date) {
  if (date.length != 10) return false;
  if (date[4] != '-' || date[7] != '-') return false;

  final parts = date.split('-');
  if (parts.length != 3) return false;

  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);

  if (year == null || month == null || day == null) return false;
  if (parts[0].length != 4 || parts[1].length != 2 || parts[2].length != 2) return false;
  if (month < 1 || month > 12) return false;
  if (day < 1 || day > 31) return false;

  return true;
}

String formatDateForDisplay(String yyyymmdd) {
  final parts = yyyymmdd.split('-');
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  final day = int.parse(parts[2]);

  final months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  final monthName = months[month - 1];
  return '$monthName $day, $year';
}

String processMarkdown(String markdown) {
  try {
    final parsed = extractMetadata(markdown);
    final withMermaid = processMermaidBlocks(parsed['content'] as String);
    var html = md.markdownToHtml(withMermaid['markdown'] as String);
    html = replaceMermaidPlaceholders(html, withMermaid['blocks'] as List<String>);

    // Parse HTML
    final document = html_parser.parse(html);
    final body = document.body;

    if (body == null) {
      return '<p>Error: No body in document.</p>';
    }

    // Extract and assign IDs to headings
    final headings = <html_dom.Element>[];
    final headingTags = ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'];

    for (final tag in headingTags) {
      final elements = body.querySelectorAll(tag);
      for (final el in elements) {
        final text = el.text.trim();
        if (text.isEmpty) continue;

        // Create ID from text
        var id = text
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
            .replaceAll(RegExp(r'\s+'), '-')
            .replaceAll(RegExp(r'-+'), '-');

        // Avoid duplicates
        int counter = 0;
        final baseId = id;
        while (document.getElementById(id) != null) {
          id = '${baseId}_${++counter}';
        }
        el.attributes['id'] = id;
        headings.add(el);
      }
    }

  int insertionIndex = 0;

    // Add metadata if present
    final metadata = parsed['metadata'] as Map<String, String>;
// Add metadata if present
if (metadata.isNotEmpty) {
  final metadataHtml = buildMetadataHtml(metadata);
  final metadataFragment = html_parser.parseFragment(metadataHtml);
  body.nodes.insert(insertionIndex++, metadataFragment.nodes.first);
}

// Add TOC if enough headings
if (headings.length > 1) {
  final tocHtml = generateTocHtml(headings);
  final tocFragment = html_parser.parseFragment(tocHtml);
  body.nodes.insert(insertionIndex++, tocFragment.nodes.first);
}

// After adding the created date, add updated date
final h1 = body.querySelector('h1');
if (h1 != null) {
  final dateCreated = metadata['date_created']!.trim();
  final dateUpdated = metadata['date_updated']!.trim();

  if (isValidDateFormat(dateCreated) && isValidDateFormat(dateUpdated)) {
    final formattedCreated = formatDateForDisplay(dateCreated);
    final formattedUpdated = formatDateForDisplay(dateUpdated);

    final dateHtml = '<p class="article-date"> created at <time class="datetime">$formattedCreated</time> updated at <time class="datetime">$formattedUpdated</time> </p>';

    final frag = html_parser.parseFragment(dateHtml);
    final h1Index = body.nodes.indexOf(h1);
    body.nodes.insert(h1Index + 1, frag.nodes.first);
  }

}



    return document.outerHtml;
  } catch (e) {
    print('Error processing markdown: $e');
    return '<p>Error processing markdown content</p>';
  }
}

String generateTocHtml(List<html_dom.Element> headings) {
  final buffer = StringBuffer();

  buffer.writeln('<details class="toc" open>');
  buffer.writeln('  <summary>📋 Table of Contents</summary>');
  buffer.writeln('  <ul class="toc-list">');

  for (final heading in headings) {
    final level = int.tryParse(heading.localName?.substring(1) ?? '6') ?? 6;
    final indentLevel = (level - 1).clamp(0, 3); // Max 3 levels indented
    final text = heading.text.trim();
    final id = heading.id;

    buffer.writeln(
      '    <li style="margin-left: ${indentLevel * 1.2}rem;">'
      '<a href="#$id">${text.isNotEmpty ? text : '(no title)'}</a>'
      '</li>',
    );
  }

  buffer.writeln('  </ul>');
  buffer.writeln('</details>');

  return buffer.toString();
}

Map<String, dynamic> extractMetadata(String markdown) {
  final lines = markdown.split('\n');
  final metadata = <String, String>{};
  var contentStart = 0;

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
  return key
      .replaceAll('_', ' ')
      .split(' ')
      .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
      .join(' ');
}

String formatValue(String value) {
  if (value.length == 10 && value[4] == '-' && value[7] == '-') {
    return '<time datetime="$value">$value</time>';
  }

  if (value.startsWith('http')) {
    return '<a href="$value" target="_blank" rel="noopener">$value</a>';
  }

  if (value.contains('@') && value.contains('.')) {
    return '<a href="mailto:$value">$value</a>';
  }

  return value;
}

String? extractTitle(String markdown) {
  final parsed = extractMetadata(markdown);
  final metadata = parsed['metadata'] as Map<String, String>;

  if (metadata.containsKey('title')) {
    return metadata['title'];
  }

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
  <!-- Smooth scrolling -->
  <style>
    html { scroll-behavior: smooth; }
  </style>
  <!-- Prism.js for syntax highlighting -->
  <link href="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/themes/prism-tomorrow.min.css" rel="stylesheet" />
  <script src="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/prism.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/components/prism-dart.min.js"></script>
  <!-- Mermaid.js for diagrams -->
  <script src="https://cdn.jsdelivr.net/npm/mermaid@10.9.0/dist/mermaid.min.js"></script>
  <script>
    document.addEventListener('DOMContentLoaded', function() {
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

    /* Mermaid */
    .mermaid {
      background: #2d2d2d;
      border-radius: 6px;
      padding: 1rem;
      margin: 1rem 0;
      text-align: center;
      overflow-x: auto;
    }
    .mermaid svg {
      max-width: 100%;
      height: auto;
    }

    /* Metadata */
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
    .metadata[open] summary {
      border-bottom: 1px solid #444;
      margin-bottom: 0;
      border-radius: 6px 6px 0 0;
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

    /* Table of Contents */
    .toc {
      background: #2a2a2a;
      border: 1px solid #444;
      border-radius: 6px;
      margin: 1.5rem 0;
      overflow: hidden;
    }
    .toc summary {
      padding: 0.75rem 1rem;
      cursor: pointer;
      font-weight: 600;
      color: #00bfff;
      user-select: none;
      border-radius: 6px;
      background: #333;
      transition: background-color 0.2s ease;
    }
    .toc summary:hover {
      background: #3a3a3a;
    }
    .toc[open] summary {
      border-bottom: 1px solid #444;
      margin-bottom: 0;
      border-radius: 6px 6px 0 0;
    }
    .toc-list {
      list-style: none;
      padding: 0.5rem 1rem 1rem 1rem;
      margin: 0;
      background: #2d2d2d;
      font-size: 0.95em;
      max-height: 400px;
      overflow-y: auto;
    }
    .toc-list li {
      margin: 0.4rem 0;
      word-break: break-word;
    }
    .toc-list a {
      color: #ddd;
      transition: color 0.2s;
      display: block;
      padding: 0.1rem 0;
    }
    .toc-list a:hover {
      color: #00bfff;
      text-decoration: underline;
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
      .metadata-item, .toc-list li {
        flex-direction: column;
        gap: 0.25rem;
      }
      .metadata-key {
        min-width: auto;
      }
    }

.article-date {
  color: #888;
  font-size: 0.95em;
  margin: -0.2rem 0 1rem 0;
  font-style: italic;
  border: 1px solid gray;
  border-radius: 5px;
  padding: 5px;
}

.article-date time {
  color: #90EE90;
}

blockquote {
  background: #2a2a2a;
  border-left: 4px solid #00bfff;
  padding: 0.75rem 1rem;
  margin: 1.5rem 0;
  font-style: italic;
  color: #ccc;
  border-radius: 0 4px 4px 0;
  font-size: 0.95em;
  line-height: 1.5;
}

.article-list {
  list-style: none;
  padding: 0;
}

.article-list li {
  margin: 0.7rem 0;
  padding: 0.5rem 0;
}

.article-list li:last-child {
  border-bottom: none;
}

.article-list a {
  font-size: 1.1em;
  color: #ddd;
  display: block;
  transition: color 0.2s;
}

.article-list a:hover {
  color: #00bfff;
  text-decoration: underline;
}

  </style>
</head>
<body>
  ${isIndex ? '' : '<a class="back-link" href="index.html">← Back to Home</a>'}
  $body
</body>
</html>
''';
