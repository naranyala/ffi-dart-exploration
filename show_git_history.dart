import 'dart:io';

Future<bool> isValidGitPath(String gitDir) async {
  // Case 1: Direct .git directory (e.g., /path/to/repo/.git)
  if (await Directory(gitDir).exists()) {
    final headFile = File('$gitDir/HEAD');
    final refsDir = Directory('$gitDir/refs');
    if (await headFile.exists() && await refsDir.exists()) {
      return true;
    }
  }
  
  // Case 2: Repository root directory (e.g., /path/to/repo)
  final dotGitDir = Directory('$gitDir/.git');
  final dotGitFile = File('$gitDir/.git');
  
  if (await dotGitDir.exists()) {
    // Standard .git directory
    final headFile = File('$gitDir/.git/HEAD');
    final refsDir = Directory('$gitDir/.git/refs');
    return await headFile.exists() && await refsDir.exists();
  } else if (await dotGitFile.exists()) {
    // Git worktree or submodule (contains path to actual .git directory)
    try {
      final content = await dotGitFile.readAsString();
      if (content.startsWith('gitdir: ')) {
        return true; // Let git handle the validation
      }
    } catch (e) {
      return false;
    }
  }
  
  return false;
}

void main(List<String> arguments) async {
  try {
    final args = parseArguments(arguments);
    
    if (args['help'] == true || args['gitdir'] == null) {
      printUsage();
      exit(0);
    }
    
    final gitDir = args['gitdir'] as String;
    final limit = args['limit'] as int;
    
    // Validate git directory exists and is valid
    if (!await isValidGitPath(gitDir)) {
      print('Error: "$gitDir" is not a valid git repository or .git directory');
      exit(1);
    }
    
    final scanner = GitCommitScanner(gitDir);
    final commits = await scanner.scanCommits(limit: limit);
    
    print('Commit history for: $gitDir');
    print('=' * 120);
    
    for (final commit in commits) {
      print(commit);
    }
    
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

Map<String, dynamic> parseArguments(List<String> arguments) {
  final result = <String, dynamic>{
    'help': false,
    'gitdir': null,
    'limit': 20,
  };
  
  for (int i = 0; i < arguments.length; i++) {
    final arg = arguments[i];
    
    // Handle help flags
    if (arg == '--help' || arg == '-h') {
      result['help'] = true;
    }
    // Handle gitdir option
    else if (arg == '--gitdir' || arg == '-g') {
      if (i + 1 >= arguments.length) {
        throw ArgumentError('Option $arg requires a value');
      }
      result['gitdir'] = arguments[++i];
    }
    // Handle limit option
    else if (arg == '--limit' || arg == '-l') {
      if (i + 1 >= arguments.length) {
        throw ArgumentError('Option $arg requires a value');
      }
      final limitStr = arguments[++i];
      final limitValue = int.tryParse(limitStr);
      if (limitValue == null || limitValue <= 0) {
        throw ArgumentError('Invalid limit value: $limitStr. Must be a positive integer.');
      }
      result['limit'] = limitValue;
    }
    // Handle combined short flags (like -gl)
    else if (arg.startsWith('-') && arg.length > 2 && !arg.startsWith('--')) {
      final flags = arg.substring(1).split('');
      for (int j = 0; j < flags.length; j++) {
        final flag = flags[j];
        if (flag == 'h') {
          result['help'] = true;
        } else if (flag == 'g') {
          if (j == flags.length - 1) {
            // -g is the last flag, next argument should be the value
            if (i + 1 >= arguments.length) {
              throw ArgumentError('Option -g requires a value');
            }
            result['gitdir'] = arguments[++i];
          } else {
            throw ArgumentError('Option -g must be the last flag in a combined option');
          }
        } else if (flag == 'l') {
          if (j == flags.length - 1) {
            // -l is the last flag, next argument should be the value
            if (i + 1 >= arguments.length) {
              throw ArgumentError('Option -l requires a value');
            }
            final limitStr = arguments[++i];
            final limitValue = int.tryParse(limitStr);
            if (limitValue == null || limitValue <= 0) {
              throw ArgumentError('Invalid limit value: $limitStr. Must be a positive integer.');
            }
            result['limit'] = limitValue;
          } else {
            throw ArgumentError('Option -l must be the last flag in a combined option');
          }
        } else {
          throw ArgumentError('Unknown flag: -$flag');
        }
      }
    }
    // Handle unknown options
    else if (arg.startsWith('-')) {
      throw ArgumentError('Unknown option: $arg');
    }
    // Handle positional arguments (none expected in this case)
    else {
      throw ArgumentError('Unexpected argument: $arg');
    }
  }
  
  return result;
}

void printUsage() {
  print('Usage: git_scanner --gitdir <path> [--limit <number>]');
  print('');
  print('Options:');
  print('  -g, --gitdir <path>     Path to .git directory or repository');
  print('  -l, --limit <number>    Number of commits to show (default: 20)');
  print('  -h, --help              Show this usage information');
  print('');
  print('Examples:');
  print('  git_scanner --gitdir /path/to/repo/.git');
  print('  git_scanner -g /path/to/repo/.git -l 10');
  print('  git_scanner --gitdir . --limit 5');
}

class GitCommitScanner {
  final String gitDir;
  
  GitCommitScanner(this.gitDir);
  
  Future<List<GitCommit>> scanCommits({int limit = 20}) async {
    // Determine the correct git arguments based on path type
    List<String> gitArgs;
    
    // Check if this is a direct .git directory or repository root
    final dotGitDir = Directory('$gitDir/.git');
    final isDirectGitDir = gitDir.endsWith('.git') && await Directory(gitDir).exists();
    
    if (isDirectGitDir) {
      // Direct .git directory path
      gitArgs = [
        '--git-dir=$gitDir',
        'log',
        '--pretty=format:%H|%an|%ae|%ad|%ar|%s|%D',
        '--date=iso',
        '--max-count=$limit'
      ];
    } else {
      // Repository root directory
      gitArgs = [
        '-C', gitDir,  // Change to repository directory
        'log',
        '--pretty=format:%H|%an|%ae|%ad|%ar|%s|%D',
        '--date=iso',
        '--max-count=$limit'
      ];
    }
    
    final result = await Process.run('git', gitArgs);
    
    if (result.exitCode != 0) {
      throw Exception('Git command failed: ${result.stderr}');
    }
    
    final output = result.stdout.toString().trim();
    if (output.isEmpty) return [];
    
    return output.split('\n').map((line) {
      final parts = line.split('|');
      
      // Handle malformed lines more robustly
      if (parts.length < 6) {
        throw Exception('Malformed git log output: $line');
      }
      
      try {
        return GitCommit(
          hash: parts[0],
          author: parts[1],
          email: parts[2],
          date: DateTime.parse(parts[3]),
          relativeDate: parts[4],
          message: parts[5],
          refs: parts.length > 6 ? parts[6] : '',
        );
      } catch (e) {
        throw Exception('Failed to parse commit data: $line. Error: $e');
      }
    }).toList();
  }
}

class GitCommit {
  final String hash;
  final String author;
  final String email;
  final DateTime date;
  final String relativeDate;
  final String message;
  final String refs;
  
  GitCommit({
    required this.hash,
    required this.author,
    required this.email,
    required this.date,
    required this.relativeDate,
    required this.message,
    required this.refs,
  });
  
  String get shortHash => hash.length > 7 ? hash.substring(0, 7) : hash;
  
  String get formattedDate {
    final isoDate = date.toIso8601String();
    final datePart = isoDate.substring(0, 10);
    final timePart = isoDate.substring(11, 16);
    return '$datePart $timePart';
  }
  
  String get branchInfo {
    if (refs.isEmpty) return '';
    
    // Clean up refs display
    final cleanRefs = refs
        .replaceAll('origin/', '')
        .replaceAll('HEAD -> ', '→ ')
        .replaceAll(', ', ' • ');
    
    return cleanRefs.isEmpty ? '' : ' ($cleanRefs)';
  }
  
  @override
  String toString() {
    final truncatedMessage = message.length > 80 ? '${message.substring(0, 77)}...' : message;
    return '[$shortHash] $author <$email> • $formattedDate ($relativeDate)$branchInfo • $truncatedMessage';
  }
}
