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
  buffer.writeln('<!DOCTYPE html>');
  buffer.writeln('<html lang="en"><head><meta charset="UTF-8">');
  buffer.writeln('<title>Git Commit History</title>');
  buffer.writeln('<style>body{font-family:sans-serif;}li{margin-bottom:8px;}</style>');
  buffer.writeln('</head><body>');
  buffer.writeln('<h1>Git Commit History</h1>');
  buffer.writeln('<ul>');
  for (var commit in commits) {
    buffer.writeln('<li><strong>${commit.date.toIso8601String()}</strong> '
        'by <em>${commit.author}</em><br>'
        '<code>${commit.message}</code></li>');
  }
  buffer.writeln('</ul></body></html>');
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

