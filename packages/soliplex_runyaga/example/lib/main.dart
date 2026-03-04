import 'package:flutter/material.dart';
import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:soliplex_runyaga/soliplex_runyaga.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LogManager.instance
    ..minimumLevel = LogLevel.debug
    ..addSink(StdoutSink());
  runApp(const RunyagaApp());
}
