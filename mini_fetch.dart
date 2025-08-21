import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<String?> runUname(String arg) async {
  try {
    final result = await Process.run('uname', [arg]);
    if (result.exitCode == 0) {
      return (result.stdout as String).trim();
    }
  } catch (_) {}
  return null;
}

Future<Duration?> uptime() async {
  try {
    final data = await File('/proc/uptime').readAsString();
    final secs = double.tryParse(data.split(RegExp(r'\s+')).first);
    if (secs != null) {
      return Duration(seconds: secs.floor());
    }
  } catch (_) {}
  return null;
}

Future<String?> cpuModel() async {
  try {
    final data = await File('/proc/cpuinfo').readAsString();
    for (final line in const LineSplitter().convert(data)) {
      if (line.startsWith('model name')) {
        return line.split(':').elementAtOrNull(1)?.trim();
      }
    }
  } catch (_) {}
  return null;
}

Future<(int, int)?> memInfo() async {
  try {
    final data = await File('/proc/meminfo').readAsString();
    int total = 0;
    int free = 0;
    for (final line in const LineSplitter().convert(data)) {
      if (line.startsWith('MemTotal')) {
        total = int.tryParse(line.split(RegExp(r'\s+'))[1]) ?? 0;
      } else if (line.startsWith('MemAvailable')) {
        free = int.tryParse(line.split(RegExp(r'\s+'))[1]) ?? 0;
      }
    }
    return (total, free);
  } catch (_) {}
  return null;
}

Future<void> main() async {
  final user = Platform.environment['USER'] ?? '?';
  final shell = Platform.environment['SHELL'] ?? '?';

  final sysname = await runUname('-s') ?? '?';
  final nodename = await runUname('-n') ?? '?';
  final release = await runUname('-r') ?? '?';
  final machine = await runUname('-m') ?? '?';

  final up = await uptime() ?? Duration.zero;
  final upHours = up.inHours;
  final upMins = (up.inMinutes % 60);

  final cpu = await cpuModel() ?? '?';
  final mem = await memInfo() ?? (0, 0);
  final memTotal = mem.$1;
  final memFree = mem.$2;

  print('$user@$nodename');
  print('-------------------------');
  print('OS: $sysname $release');
  print('Arch: $machine');
  print('Uptime: ${upHours}h ${upMins}m');
  print('CPU: $cpu');
  print(
    'Memory: ${(memTotal - memFree) ~/ 1024} MiB / ${memTotal ~/ 1024} MiB',
  );
  print('Shell: $shell');
}

