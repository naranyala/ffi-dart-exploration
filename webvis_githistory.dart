import 'dart:io';

/// Represents a single Git commit.
class Commit {
  final String hash;
  final String author;
  final DateTime date;
  final String message;

  Commit(this.hash, this.author, this.date, this.message);

  static Commit fromLine(String line) {
    final parts = line.split('|');
    return Commit(
      parts[0],
      parts[1],
      DateTime.parse(parts[2]),
      parts.sublist(3).join('|'), // In case the message contains '|'
    );
  }
}

/// Runs `git log` and returns raw output.
Future<String> getGitLog() async {
  final result = await Process.run('git', [
    'log',
    '--pretty=format:%H|%an|%ad|%s',
    '--date=iso'
  ]);
  if (result.exitCode != 0) {
    throw Exception('Failed to run git log: ${result.stderr}');
  }
  return result.stdout as String;
}

/// Parses raw git log into a list of Commit objects.
List<Commit> parseCommits(String log) =>
    log.trim().split('\n').map(Commit.fromLine).toList();

/// Generates a simple HTML report from commit data.
String generateHtml(List<Commit> commits) {
  final buffer = StringBuffer();
  buffer.writeln('''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Git Commit History</title>
  <style>
    :root {
      --bg: #f9f9f9;
      --card: #ffffff;
      --text: #333;
      --accent: #007acc;
      --border: #e0e0e0;
    }

    body {
      margin: 0;
      font-family: system-ui, sans-serif;
      background-color: var(--bg);
      color: var(--text);
      padding: 1rem;
    }

    h1 {
      font-size: 1.5rem;
      margin-bottom: 1rem;
      text-align: center;
      color: var(--accent);
    }

    .commit-list {
      display: flex;
      flex-direction: column;
      gap: 1rem;
      max-width: 800px;
      margin: 0 auto;
    }

    .commit {
      background-color: var(--card);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 1rem;
      box-shadow: 0 1px 3px rgba(0,0,0,0.05);
    }

    .commit-date {
      font-size: 0.85rem;
      color: #666;
    }

    .commit-author {
      font-weight: bold;
      margin-top: 0.25rem;
    }

    .commit-message {
      margin-top: 0.5rem;
      font-family: monospace;
      white-space: pre-wrap;
      word-break: break-word;
    }

    @media (max-width: 600px) {
      body {
        padding: 0.5rem;
      }

      .commit {
        padding: 0.75rem;
      }

      h1 {
        font-size: 1.25rem;
      }
    }
  </style>
</head>
<body>
  <h1>Git Commit History</h1>
  <div class="commit-list">
''');

  for (var commit in commits) {
    buffer.writeln('''
    <div class="commit">
      <div class="commit-date">${commit.date.toIso8601String()}</div>
      <div class="commit-author">${commit.author}</div>
      <div class="commit-message">${commit.message}</div>
    </div>
''');
  }

  buffer.writeln('''
  </div>
</body>
</html>
''');

  return buffer.toString();
}

/// Saves HTML content to a file.
Future<void> saveHtml(String html, String path) async {
  final file = File(path);
  await file.writeAsString(html);
  print('✅ Report saved to $path');
}

/// Entry point
Future<void> main() async {
  try {
    print('📦 Scanning Git history...');
    final log = await getGitLog();
    final commits = parseCommits(log);
    final html = generateHtml(commits);
    await saveHtml(html, 'git_history.html');
  } catch (e) {
    print('❌ Error: $e');
  }
}

