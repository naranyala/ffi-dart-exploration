import 'dart:io';
import 'dart:async';
import 'dart:convert';

/// Data model for a network connection
class NetConn {
  final String proto;
  final String state;
  final String local;
  final String remote;
  final int? pid;
  final String? process;
  final String? cmd;
  final String? cpu;
  final String? mem;

  NetConn({
    required this.proto,
    required this.state,
    required this.local,
    required this.remote,
    this.pid,
    this.process,
    this.cmd,
    this.cpu,
    this.mem,
  });

  Map<String, dynamic> toJson() => {
        'proto': proto,
        'state': state,
        'local': local,
        'remote': remote,
        'pid': pid,
        'process': process,
        'cmd': cmd,
        'cpu': cpu,
        'mem': mem,
      };
}

Future<void> main(List<String> args) async {
  final jsonMode = args.contains('--json');
  final watch = args.contains('--watch');
  int intervalSeconds = 3;
  
  // Parse custom interval if provided
  final intervalIndex = args.indexOf('--interval');
  if (intervalIndex != -1 && intervalIndex + 1 < args.length) {
    intervalSeconds = int.tryParse(args[intervalIndex + 1]) ?? 3;
  }

  final interval = Duration(seconds: intervalSeconds);

  // Setup graceful shutdown
  Timer? activeTimer;
  
  ProcessSignal.sigint.watch().listen((_) {
    print('\n\nShutting down gracefully...');
    activeTimer?.cancel();
    exit(0);
  });

  if (watch) {
    // Clear screen and show header info
    _clearScreen();
    if (!jsonMode) {
      print('Network Monitor - Press Ctrl+C to exit');
      print('Update interval: ${intervalSeconds}s\n');
    }

    // Initial load
    final initialConns = await collectConnections();
    if (jsonMode) {
      printJson(initialConns);
    } else {
      _printTableWithHeader(initialConns, DateTime.now());
    }

    // Setup periodic updates
    activeTimer = Timer.periodic(interval, (_) async {
      try {
        final conns = await collectConnections();
        
        if (jsonMode) {
          _clearScreen();
          printJson(conns);
        } else {
          _clearScreen();
          print('Network Monitor - Press Ctrl+C to exit');
          print('Update interval: ${intervalSeconds}s\n');
          _printTableWithHeader(conns, DateTime.now());
        }
      } catch (e) {
        if (!jsonMode) {
          print('Error updating connections: $e');
        }
      }
    });
    
    // Keep the program running
    await Completer().future;
  } else {
    final conns = await collectConnections();
    if (jsonMode) {
      printJson(conns);
    } else {
      _printTableWithHeader(conns, DateTime.now());
    }
  }
}

/// Clear screen using ANSI escape codes
void _clearScreen() {
  // Move cursor to top-left and clear screen
  stdout.write('\x1B[2J\x1B[0;0H');
}

/// Collect connections from `ss -tupa` and enrich with process info
Future<List<NetConn>> collectConnections() async {
  try {
    final process = await Process.start('ss', ['-tupa']);
    final lines = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .skip(1);

    final connections = <NetConn>[];

    await for (var line in lines) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 6) continue;

      final proto = parts[0];
      final state = parts[1];
      final local = parts[4];
      final remote = parts[5];

      int? pid;
      String? proc;
      String? cmd;
      String? cpu;
      String? mem;

      final users = parts.length > 6 ? parts.sublist(6).join(" ") : "";
      final pidMatch = RegExp(r'pid=(\d+)').firstMatch(users);
      if (pidMatch != null) {
        pid = int.tryParse(pidMatch.group(1)!);
        if (pid != null) {
          final details = await _getProcessDetails(pid);
          proc = details['name'];
          cmd = details['cmd'];
          cpu = details['cpu'];
          mem = details['mem'];
        }
      }

      connections.add(NetConn(
        proto: proto,
        state: state,
        local: local,
        remote: remote,
        pid: pid,
        process: proc,
        cmd: cmd,
        cpu: cpu,
        mem: mem,
      ));
    }

    return connections;
  } catch (e) {
    throw Exception('Failed to collect connections: $e');
  }
}

/// Enrich process details via `ps`
Future<Map<String, String?>> _getProcessDetails(int pid) async {
  try {
    final result = await Process.run(
      'ps',
      ['-p', '$pid', '-o', 'comm=,cmd=,%cpu=,%mem='],
      runInShell: false,
    );
    
    if (result.exitCode == 0) {
      final output = (result.stdout as String).trim();
      if (output.isNotEmpty) {
        // Split more carefully to handle process names and commands with spaces
        final parts = output.split(RegExp(r'\s+'));
        if (parts.isNotEmpty) {
          final name = parts[0];
          final cpu = parts.length > 1 ? parts[parts.length - 2] : null;
          final mem = parts.length > 2 ? parts.last : null;
          
          // Reconstruct command by excluding the last two elements (cpu, mem)
          final cmdParts = parts.length > 2 
            ? parts.sublist(1, parts.length - 2) 
            : parts.sublist(1);
          final cmd = cmdParts.isNotEmpty ? cmdParts.join(' ') : null;
          
          return {
            'name': name,
            'cmd': cmd,
            'cpu': cpu,
            'mem': mem,
          };
        }
      }
    }
  } catch (_) {
    // Silently handle process lookup failures
  }
  return {
    'name': null,
    'cmd': null,
    'cpu': null,
    'mem': null,
  };
}

/// Print JSON
void printJson(List<NetConn> conns) {
  final jsonOutput = conns.map((c) => c.toJson()).toList();
  print(const JsonEncoder.withIndent('  ').convert(jsonOutput));
}

/// Print table with timestamp header
void _printTableWithHeader(List<NetConn> conns, DateTime timestamp) {
  // Print summary info
  final activeConns = conns.where((c) => c.state == 'ESTAB').length;
  final listeningConns = conns.where((c) => c.state == 'LISTEN').length;
  
  print('Last updated: ${timestamp.toString().substring(0, 19)}');
  print('Total connections: ${conns.length} (${activeConns} active, ${listeningConns} listening)');
  print('${'=' * 80}');
  
  _printTable(conns);
}

/// Print Table with improved formatting
void _printTable(List<NetConn> conns) {
  if (conns.isEmpty) {
    print('No connections found.');
    return;
  }

  final headers = ['Proto', 'PID', 'Process', 'State', 'Local', 'Remote', 'CPU%', 'MEM%'];
  
  // Prepare rows with truncated data for better display
  final rows = [
    headers,
    ...conns.map((c) => [
          c.proto,
          c.pid?.toString() ?? '-',
          _truncate(c.process ?? '-', 15),
          c.state,
          _truncate(c.local, 25),
          _truncate(c.remote, 25),
          c.cpu ?? '-',
          c.mem ?? '-',
        ])
  ];

  // Calculate column widths
  final colWidths = List<int>.generate(
    headers.length,
    (i) => rows.map((r) => r[i].length).reduce((a, b) => a > b ? a : b),
  );

  // Print header with separator
  final headerRow = rows[0];
  final headerLine = headerRow.asMap().entries.map((e) {
    final i = e.key;
    final cell = e.value.padRight(colWidths[i]);
    return cell;
  }).join(' | ');
  
  print(headerLine);
  print('-' * headerLine.length);

  // Print data rows
  for (int i = 1; i < rows.length; i++) {
    final row = rows[i];
    final line = row.asMap().entries.map((e) {
      final col = e.key;
      final cell = e.value.padRight(colWidths[col]);
      return cell;
    }).join(' | ');
    print(line);
  }
}

/// Truncate string to specified length with ellipsis
String _truncate(String str, int maxLength) {
  if (str.length <= maxLength) return str;
  return '${str.substring(0, maxLength - 3)}...';
}
