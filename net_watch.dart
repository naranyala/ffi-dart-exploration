import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<String?> getDefaultInterface() async {
  try {
    final data = await File('/proc/net/route').readAsString();
    final lines = const LineSplitter().convert(data).skip(1); // skip header
    for (final line in lines) {
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length >= 2 && parts[1] == '00000000') {
        return parts[0];
      }
    }
  } catch (_) {
    // ignore errors
  }
  return null;
}

Future<(int, int)?> readNetBytes(String iface) async {
  try {
    final data = await File('/proc/net/dev').readAsString();
    final lines = const LineSplitter().convert(data).skip(2); // skip headers
    for (final line in lines) {
      final pos = line.indexOf(':');
      if (pos != -1) {
        final name = line.substring(0, pos).trim();
        if (name == iface) {
          final parts = line.substring(pos + 1).trim().split(RegExp(r'\s+'));
          if (parts.length >= 9) {
            final rxBytes = int.tryParse(parts[0]);
            final txBytes = int.tryParse(parts[8]);
            if (rxBytes != null && txBytes != null) {
              return (rxBytes, txBytes);
            }
          }
        }
      }
    }
  } catch (_) {
    // ignore errors
  }
  return null;
}

String formatBytes(int bytes) {
  const units = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
  double value = bytes.toDouble();
  int unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  return '${value.toStringAsFixed(2)} ${units[unitIndex]}';
}

Future<void> main() async {
  final iface = await getDefaultInterface();
  if (iface == null) {
    stderr.writeln('No default interface found');
    return;
  }

  print('Watching active interface: $iface');

  final firstRead = await readNetBytes(iface);
  if (firstRead == null) {
    stderr.writeln('Interface $iface not found in /proc/net/dev');
    return;
  }

  // prev is now non-nullable
  var prev = firstRead;
  const interval = Duration(seconds: 1);

  while (true) {
    await Future.delayed(interval);
    final curr = await readNetBytes(iface);
    if (curr != null) {
      // Handle counter wrap-around (e.g., after reboot or overflow)
      final rxRate = (curr.$1 >= prev.$1)
          ? curr.$1 - prev.$1
          : (curr.$1 + (1 << 32) - prev.$1);
      final txRate = (curr.$2 >= prev.$2)
          ? curr.$2 - prev.$2
          : (curr.$2 + (1 << 32) - prev.$2);

      print('RX: ${formatBytes(rxRate)} | TX: ${formatBytes(txRate)}');
      prev = curr;
    } else {
      stderr.writeln('Interface $iface disappeared');
      break;
    }
  }
}

