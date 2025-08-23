import 'dart:io';
import 'package:args/args.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('html-path', abbr: 'p', help: 'Path to the HTML file to serve')
    ..addOption('port', abbr: 'P', defaultsTo: '8080', help: 'Port to serve on');

  final argResults = parser.parse(arguments);
  final htmlPath = argResults['html-path'] as String?;
  final port = int.tryParse(argResults['port'] as String) ?? 8080;

  if (htmlPath == null || htmlPath.isEmpty) {
    print('❌ Missing required argument: --html-path');
    print('Usage: dart run serve_html.dart --html-path=<path> [--port=<port>]');
    exit(1);
  }

  final htmlFile = File(htmlPath);
  if (!await htmlFile.exists()) {
    print('❌ File not found: $htmlPath');
    exit(1);
  }

  final directory = htmlFile.parent.path;
  final filename = htmlFile.uri.pathSegments.last;

  final handler = createStaticHandler(
    directory,
    defaultDocument: filename,
    serveFilesOutsidePath: true,
  );

  final server = await io.serve(handler, InternetAddress.loopbackIPv4, port);
  print('🚀 Serving $filename at http://${server.address.host}:${server.port}');
}

