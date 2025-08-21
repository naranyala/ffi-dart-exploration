import 'dart:io';
import 'dart:convert';

Future<void> printTree(Directory dir, String prefix, int depth) async {
  if (depth == 0 || !await dir.exists()) return;

  final entries = await dir.list().toList();
  for (var i = 0; i < entries.length; i++) {
    final entity = entries[i];
    final name = entity.path.split(Platform.pathSeparator).last;

    final isLast = i == entries.length - 1;
    final connector = isLast ? '└── ' : '├── ';
    print('$prefix$connector$name');

    final newPrefix = prefix + (isLast ? '    ' : '│   ');
    if (entity is Directory) {
      await printTree(entity, newPrefix, depth - 1);
    }
  }
}

void printHelp(String program) {
  print('Usage: $program --dirpath <directory> [--depth <n>] [--help]\n');
  print('Options:');
  print('  --dirpath <directory>   Path to the root directory to scan (required)');
  print('  --depth <n>             Max depth to traverse (default: 3)');
  print('  --help                  Show this help message');
}

Future<void> main(List<String> args) async {
  String? dirpathStr;
  int depth = 2;

  var i = 0;
  while (i < args.length) {
    switch (args[i]) {
      case '--dirpath':
        if (i + 1 < args.length) {
          dirpathStr = args[i + 1];
          i++;
        }
        break;
      case '--depth':
        if (i + 1 < args.length) {
          depth = int.tryParse(args[i + 1]) ?? 3;
          i++;
        }
        break;
      case '--help':
        printHelp(Platform.script.pathSegments.last);
        return;
    }
    i++;
  }

  if (dirpathStr == null) {
    stderr.writeln('Error: --dirpath is required\n');
    printHelp(Platform.script.pathSegments.last);
    return;
  }

  final dir = Directory(dirpathStr);
  print(dir.path);

  try {
    await printTree(dir, '', depth);
  } catch (e) {
    stderr.writeln('Error: $e');
  }
}

