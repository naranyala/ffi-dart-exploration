import 'dart:io';
import 'dart:async';
import 'dart:convert';

// Simple in-memory cache for geolocation lookups
final Map<String, String> _geoCache = {};

// HTTP client for API requests
final HttpClient _httpClient = HttpClient();

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
  final String? country;

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
    this.country,
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
        'country': country,
      };
}

/// Extract IP address from address:port format
String? _extractIpFromAddress(String address) {
  try {
    // Handle IPv4 and IPv6 addresses
    if (address.contains('[') && address.contains(']:')) {
      // IPv6 format [::1]:8080
      final match = RegExp(r'\[([^\]]+)\]').firstMatch(address);
      return match?.group(1);
    } else if (address.contains(':')) {
      // IPv4 format 192.168.1.1:8080
      final parts = address.split(':');
      if (parts.length >= 2) {
        return parts[0];
      }
    }
    return address;
  } catch (_) {
    return null;
  }
}

/// Check if IP is private/local
bool _isPrivateOrLocalIp(String ip) {
  // Local/private IP ranges that shouldn't be geolocated
  final privateRanges = [
    '127.',        // localhost
    '192.168.',    // private class C
    '10.',         // private class A  
    '172.16.',     // private class B (simplified)
    '172.17.',     // private class B (simplified)
    '172.18.',     // private class B (simplified)
    '172.19.',     // private class B (simplified)
    '172.2',       // private class B (172.20-172.31)
    '172.30.',     // private class B (simplified)
    '172.31.',     // private class B (simplified)
    '169.254.',    // link-local
    '::1',         // IPv6 localhost
    'fe80:',       // IPv6 link-local
    'fc00:',       // IPv6 unique local
    'fd00:',       // IPv6 unique local
  ];
  
  return privateRanges.any((range) => ip.startsWith(range)) || 
         ip == '0.0.0.0' || 
         ip.isEmpty ||
         ip == '*';
}

/// Get country code for a network address
Future<String?> _getCountryForAddress(String address) async {
  final ip = _extractIpFromAddress(address);
  if (ip == null || _isPrivateOrLocalIp(ip)) {
    return 'LOCAL';
  }

  // Check cache first
  if (_geoCache.containsKey(ip)) {
    return _geoCache[ip];
  }

  try {
    // Using ip-api.com free service (no API key required, 1000 requests/hour limit)
    final request = await _httpClient.getUrl(
      Uri.parse('http://ip-api.com/json/$ip?fields=countryCode,status')
    );
    request.headers.add('User-Agent', 'Network-Monitor-Tool/1.0');
    
    final response = await request.close();
    if (response.statusCode == 200) {
      final responseBody = await response.transform(utf8.decoder).join();
      final data = json.decode(responseBody);
      
      if (data['status'] == 'success') {
        final countryCode = data['countryCode'] as String?;
        if (countryCode != null && countryCode.isNotEmpty) {
          _geoCache[ip] = countryCode; // Cache the result
          return countryCode;
        }
      }
    }
  } catch (e) {
    // Silently handle network errors - geolocation is non-critical
  }
  
  // Cache failed lookups to avoid repeated attempts
  _geoCache[ip] = 'UNKNOWN';
  return 'UNKNOWN';
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
      String? country;

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

      // Get country for remote IP
      country = await _getCountryForAddress(remote);

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
        country: country,
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

  final headers = ['Proto', 'PID', 'Process', 'State', 'Local', 'Remote', 'Country', 'CPU%', 'MEM%'];
  
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
          c.country ?? '-',
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
