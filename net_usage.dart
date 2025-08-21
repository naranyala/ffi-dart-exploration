import 'dart:io';
import 'dart:async';
import 'dart:convert';

/// Network interface information
class NetworkInterface {
  final String name;
  final String type;
  final bool isActive;
  final int rxBytes;
  final int txBytes;
  final int rxPackets;
  final int txPackets;
  final DateTime timestamp;

  NetworkInterface({
    required this.name,
    required this.type,
    required this.isActive,
    required this.rxBytes,
    required this.txBytes,
    required this.rxPackets,
    required this.txPackets,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'isActive': isActive,
        'rxBytes': rxBytes,
        'txBytes': txBytes,
        'rxPackets': rxPackets,
        'txPackets': txPackets,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Bandwidth statistics with enhanced JSON support
class BandwidthStats {
  final String interfaceName;
  final String interfaceType;
  final int totalRxBytes;
  final int totalTxBytes;
  final double rxRate; // bytes per second
  final double txRate; // bytes per second
  final DateTime timestamp;
  final int? sessionRxBytes;
  final int? sessionTxBytes;
  final Duration? sessionDuration;

  BandwidthStats({
    required this.interfaceName,
    required this.interfaceType,
    required this.totalRxBytes,
    required this.totalTxBytes,
    required this.rxRate,
    required this.txRate,
    required this.timestamp,
    this.sessionRxBytes,
    this.sessionTxBytes,
    this.sessionDuration,
  });

  Map<String, dynamic> toJson() => {
        'interface': interfaceName,
        'type': interfaceType,
        'timestamp': timestamp.toIso8601String(),
        'totals': {
          'rxBytes': totalRxBytes,
          'txBytes': totalTxBytes,
          'combinedBytes': totalRxBytes + totalTxBytes,
          'rxFormatted': _formatBytes(totalRxBytes),
          'txFormatted': _formatBytes(totalTxBytes),
          'combinedFormatted': _formatBytes(totalRxBytes + totalTxBytes),
        },
        'rates': {
          'rxBytesPerSec': rxRate.round(),
          'txBytesPerSec': txRate.round(),
          'combinedBytesPerSec': (rxRate + txRate).round(),
          'rxFormatted': _formatRate(rxRate),
          'txFormatted': _formatRate(txRate),
          'combinedFormatted': _formatRate(rxRate + txRate),
        },
        'session': sessionRxBytes != null && sessionTxBytes != null && sessionDuration != null ? {
          'rxBytes': sessionRxBytes,
          'txBytes': sessionTxBytes,
          'combinedBytes': sessionRxBytes! + sessionTxBytes!,
          'rxFormatted': _formatBytes(sessionRxBytes!),
          'txFormatted': _formatBytes(sessionTxBytes!),
          'combinedFormatted': _formatBytes(sessionRxBytes! + sessionTxBytes!),
          'duration': sessionDuration!.inSeconds,
          'durationFormatted': _formatDuration(sessionDuration!),
        } : null,
        'activity': {
          'level': _getActivityLevel(rxRate + txRate),
          'indicator': _getRateIndicator(rxRate + txRate),
        },
      };
}

// Previous measurements for rate calculation
NetworkInterface? _previousMeasurement;
DateTime? _startTime;
int? _initialRxBytes;
int? _initialTxBytes;

Future<void> main(List<String> args) async {
  final jsonMode = args.contains('--json');
  final watch = args.contains('--watch');
  final showAll = args.contains('--all');
  int intervalSeconds = 2;

  // Parse custom interval if provided
  final intervalIndex = args.indexOf('--interval');
  if (intervalIndex != -1 && intervalIndex + 1 < args.length) {
    intervalSeconds = int.tryParse(args[intervalIndex + 1]) ?? 2;
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
    // Setup JSON streaming mode
    if (jsonMode) {
      print('{"mode": "realtime", "interval": $intervalSeconds}');
      stdout.flush();
    } else {
      // Clear screen and show header info for table mode
      _clearScreen();
      print('Bandwidth Monitor - Press Ctrl+C to exit');
      print('Update interval: ${intervalSeconds}s');
      if (showAll) print('Showing all interfaces');
      print('${'=' * 80}');
    }

    // Initial measurement
    final activeInterface = await _getActiveInternetInterface(showAll);
    if (activeInterface != null) {
      _initializeCounters(activeInterface);
      if (jsonMode) {
        final stats = _calculateBandwidthStats(activeInterface);
        _printJsonUpdate(stats);
      } else {
        _printBandwidthInfo(activeInterface, null);
      }
    } else {
      if (jsonMode) {
        print('{"error": "No active internet connection detected", "timestamp": "${DateTime.now().toIso8601String()}"}');
      } else {
        print('No active internet connection detected.');
      }
      return;
    }

    // Setup periodic updates
    activeTimer = Timer.periodic(interval, (_) async {
      try {
        final currentInterface = await _getActiveInternetInterface(showAll);
        if (currentInterface != null) {
          final stats = _calculateBandwidthStats(currentInterface);
          
          if (jsonMode) {
            _printJsonUpdate(stats);
          } else {
            _clearScreen();
            print('Bandwidth Monitor - Press Ctrl+C to exit');
            print('Update interval: ${intervalSeconds}s');
            if (showAll) print('Showing all interfaces');
            print('${'=' * 80}');
            _printBandwidthInfo(currentInterface, stats);
          }

          _previousMeasurement = currentInterface;
        } else {
          if (jsonMode) {
            print('{"error": "No active internet connection detected", "timestamp": "${DateTime.now().toIso8601String()}"}');
          } else {
            print('No active internet connection detected.');
          }
        }
      } catch (e) {
        if (jsonMode) {
          final errorJson = {
            'error': 'Error monitoring bandwidth: $e',
            'timestamp': DateTime.now().toIso8601String(),
          };
          print(const JsonEncoder().convert(errorJson));
        } else {
          print('Error monitoring bandwidth: $e');
        }
      }
    });

    // Keep the program running
    await Completer().future;
  } else {
    // Single measurement
    final activeInterface = await _getActiveInternetInterface(showAll);
    if (activeInterface != null) {
      if (jsonMode) {
        print(const JsonEncoder.withIndent('  ').convert(activeInterface.toJson()));
      } else {
        _printBandwidthInfo(activeInterface, null);
      }
    } else {
      print('No active internet connection detected.');
    }
  }
}

/// Clear screen using ANSI escape codes
void _clearScreen() {
  stdout.write('\x1B[2J\x1B[0;0H');
}

/// Initialize counters for session tracking
void _initializeCounters(NetworkInterface interface) {
  _startTime = DateTime.now();
  _initialRxBytes = interface.rxBytes;
  _initialTxBytes = interface.txBytes;
}

/// Get the active internet interface (cable or wireless)
Future<NetworkInterface?> _getActiveInternetInterface(bool showAll) async {
  try {
    // Get all network interfaces
    final interfaces = await _getAllNetworkInterfaces();
    
    if (showAll) {
      // Return the first active interface when showing all
      return interfaces.firstWhere(
        (iface) => iface.isActive,
        orElse: () => interfaces.first,
      );
    }

    // Detect the primary internet interface by checking default route
    final defaultInterface = await _getDefaultRouteInterface();
    if (defaultInterface != null) {
      final matchingInterface = interfaces.where(
        (iface) => iface.name == defaultInterface && iface.isActive,
      ).firstOrNull;
      
      if (matchingInterface != null) {
        return matchingInterface;
      }
    }

    // Fallback: find the most active interface
    final activeInterfaces = interfaces.where((iface) => 
      iface.isActive && 
      (iface.rxBytes > 0 || iface.txBytes > 0)
    ).toList();

    if (activeInterfaces.isNotEmpty) {
      // Sort by total traffic and return the most active
      activeInterfaces.sort((a, b) => 
        (b.rxBytes + b.txBytes).compareTo(a.rxBytes + a.txBytes)
      );
      return activeInterfaces.first;
    }

    return null;
  } catch (e) {
    throw Exception('Failed to detect active internet interface: $e');
  }
}

/// Get default route interface name
Future<String?> _getDefaultRouteInterface() async {
  try {
    final result = await Process.run('ip', ['route', 'show', 'default']);
    if (result.exitCode == 0) {
      final output = result.stdout as String;
      final match = RegExp(r'dev (\w+)').firstMatch(output);
      return match?.group(1);
    }
  } catch (_) {
    // Fallback method using route command
    try {
      final result = await Process.run('route', ['-n']);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n');
        for (final line in lines) {
          if (line.startsWith('0.0.0.0') || line.contains('default')) {
            final parts = line.split(RegExp(r'\s+'));
            if (parts.length > 7) {
              return parts.last;
            }
          }
        }
      }
    } catch (_) {}
  }
  return null;
}

/// Get all network interfaces with statistics
Future<List<NetworkInterface>> _getAllNetworkInterfaces() async {
  final interfaces = <NetworkInterface>[];

  try {
    // Read from /proc/net/dev
    final file = File('/proc/net/dev');
    if (!await file.exists()) {
      throw Exception('/proc/net/dev not found');
    }

    final lines = await file.readAsLines();
    
    for (int i = 2; i < lines.length; i++) { // Skip header lines
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 17) continue;

      var interfaceName = parts[0];
      if (interfaceName.endsWith(':')) {
        interfaceName = interfaceName.substring(0, interfaceName.length - 1);
      }

      // Skip loopback and virtual interfaces unless explicitly requested
      if (interfaceName == 'lo' || 
          interfaceName.startsWith('docker') ||
          interfaceName.startsWith('veth') ||
          interfaceName.startsWith('br-')) {
        continue;
      }

      final rxBytes = int.tryParse(parts[1]) ?? 0;
      final rxPackets = int.tryParse(parts[2]) ?? 0;
      final txBytes = int.tryParse(parts[9]) ?? 0;
      final txPackets = int.tryParse(parts[10]) ?? 0;

      // Determine interface type and status
      final interfaceType = await _getInterfaceType(interfaceName);
      final isActive = await _isInterfaceActive(interfaceName);

      interfaces.add(NetworkInterface(
        name: interfaceName,
        type: interfaceType,
        isActive: isActive,
        rxBytes: rxBytes,
        txBytes: txBytes,
        rxPackets: rxPackets,
        txPackets: txPackets,
        timestamp: DateTime.now(),
      ));
    }
  } catch (e) {
    throw Exception('Failed to read network interface statistics: $e');
  }

  return interfaces;
}

/// Determine interface type (Ethernet, WiFi, etc.)
Future<String> _getInterfaceType(String interfaceName) async {
  try {
    // Check if it's a wireless interface
    final wirelessDir = Directory('/sys/class/net/$interfaceName/wireless');
    if (await wirelessDir.exists()) {
      return 'WiFi';
    }

    // Check interface type from sysfs
    final typeFile = File('/sys/class/net/$interfaceName/type');
    if (await typeFile.exists()) {
      final type = await typeFile.readAsString();
      switch (type.trim()) {
        case '1':
          return 'Ethernet';
        case '24':
          return 'Firewire';
        case '32':
          return 'InfiniBand';
        default:
          break;
      }
    }

    // Guess based on interface name patterns
    if (interfaceName.startsWith('eth') || interfaceName.startsWith('en')) {
      return 'Ethernet';
    } else if (interfaceName.startsWith('wl') || interfaceName.startsWith('wlan')) {
      return 'WiFi';
    } else if (interfaceName.startsWith('ppp')) {
      return 'PPP';
    } else if (interfaceName.startsWith('usb')) {
      return 'USB';
    }

    return 'Unknown';
  } catch (_) {
    return 'Unknown';
  }
}

/// Check if interface is active (up and running)
Future<bool> _isInterfaceActive(String interfaceName) async {
  try {
    final operStateFile = File('/sys/class/net/$interfaceName/operstate');
    if (await operStateFile.exists()) {
      final state = await operStateFile.readAsString();
      return state.trim().toLowerCase() == 'up';
    }

    // Fallback: use ip command
    final result = await Process.run('ip', ['link', 'show', interfaceName]);
    if (result.exitCode == 0) {
      final output = result.stdout as String;
      return output.contains('state UP');
    }
  } catch (_) {}
  
  return false;
}

/// Calculate bandwidth statistics with rates and session info
BandwidthStats _calculateBandwidthStats(NetworkInterface current) {
  double rxRate = 0.0;
  double txRate = 0.0;

  if (_previousMeasurement != null) {
    final timeDiff = current.timestamp.difference(_previousMeasurement!.timestamp).inMilliseconds / 1000.0;
    if (timeDiff > 0) {
      final rxDiff = current.rxBytes - _previousMeasurement!.rxBytes;
      final txDiff = current.txBytes - _previousMeasurement!.txBytes;
      
      rxRate = rxDiff / timeDiff;
      txRate = txDiff / timeDiff;
    }
  }

  // Calculate session stats if available
  int? sessionRx;
  int? sessionTx;
  Duration? sessionDuration;
  
  if (_startTime != null && _initialRxBytes != null && _initialTxBytes != null) {
    sessionRx = current.rxBytes - _initialRxBytes!;
    sessionTx = current.txBytes - _initialTxBytes!;
    sessionDuration = current.timestamp.difference(_startTime!);
  }

  return BandwidthStats(
    interfaceName: current.name,
    interfaceType: current.type,
    totalRxBytes: current.rxBytes,
    totalTxBytes: current.txBytes,
    rxRate: rxRate,
    txRate: txRate,
    timestamp: current.timestamp,
    sessionRxBytes: sessionRx,
    sessionTxBytes: sessionTx,
    sessionDuration: sessionDuration,
  );
}

/// Print bandwidth information
void _printBandwidthInfo(NetworkInterface interface, BandwidthStats? stats) {
  print('Interface: ${interface.name} (${interface.type})');
  print('Status: ${interface.isActive ? "Active" : "Inactive"}');
  print('Last updated: ${interface.timestamp.toString().substring(11, 19)}');
  print('');

  // Current totals
  print('Total Statistics:');
  print('  Downloaded: ${_formatBytes(interface.rxBytes)} (${interface.rxPackets} packets)');
  print('  Uploaded:   ${_formatBytes(interface.txBytes)} (${interface.txPackets} packets)');
  print('  Combined:   ${_formatBytes(interface.rxBytes + interface.txBytes)}');
  print('');

  // Session statistics (since start)
  if (_startTime != null && _initialRxBytes != null && _initialTxBytes != null) {
    final sessionDuration = DateTime.now().difference(_startTime!);
    final sessionRx = interface.rxBytes - _initialRxBytes!;
    final sessionTx = interface.txBytes - _initialTxBytes!;
    
    print('Session Statistics (${_formatDuration(sessionDuration)}):');
    print('  Downloaded: ${_formatBytes(sessionRx)}');
    print('  Uploaded:   ${_formatBytes(sessionTx)}');
    print('  Combined:   ${_formatBytes(sessionRx + sessionTx)}');
    print('');
  }

  // Current rates
  if (stats != null) {
    print('Current Rates:');
    print('  Download: ${_formatRate(stats.rxRate)}');
    print('  Upload:   ${_formatRate(stats.txRate)}');
    print('  Combined: ${_formatRate(stats.rxRate + stats.txRate)}');
    
    // Visual rate indicator
    final totalRate = stats.rxRate + stats.txRate;
    if (totalRate > 0) {
      print('');
      print('Activity: ${_getRateIndicator(totalRate)}');
    }
  }
}

/// Print real-time JSON update
void _printJsonUpdate(BandwidthStats stats) {
  final jsonData = stats.toJson();
  print(const JsonEncoder().convert(jsonData));
  stdout.flush(); // Ensure immediate output
}

/// Get activity level as string
String _getActivityLevel(double bytesPerSecond) {
  if (bytesPerSecond < 1024) return 'low';
  if (bytesPerSecond < 10240) return 'moderate';
  if (bytesPerSecond < 102400) return 'high';
  if (bytesPerSecond < 1048576) return 'very_high';
  return 'maximum';
}

/// Format bytes with appropriate units
String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  double size = bytes.toDouble();
  int unitIndex = 0;

  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }

  return '${size.toStringAsFixed(2)} ${units[unitIndex]}';
}

/// Format transfer rate
String _formatRate(double bytesPerSecond) {
  return '${_formatBytes(bytesPerSecond.round())}/s';
}

/// Format duration
String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  final seconds = duration.inSeconds % 60;
  
  if (hours > 0) {
    return '${hours}h ${minutes}m ${seconds}s';
  } else if (minutes > 0) {
    return '${minutes}m ${seconds}s';
  } else {
    return '${seconds}s';
  }
}

/// Get visual indicator for transfer rate
String _getRateIndicator(double bytesPerSecond) {
  if (bytesPerSecond < 1024) return '▁ Low';
  if (bytesPerSecond < 10240) return '▃ Moderate';
  if (bytesPerSecond < 102400) return '▅ High';
  if (bytesPerSecond < 1048576) return '▇ Very High';
  return '█ Maximum';
}
