import 'package:build/build.dart';
import 'package:event_sync_generator/src/event_generator.dart';
import 'package:event_sync_generator/src/manager_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:event_sync_generator/src/extension_generator.dart';

Builder generateExtension(BuilderOptions options) =>
    SharedPartBuilder([ExtensionGenerator()], 'extension_generator');

Builder generateEvents(BuilderOptions options) =>
    SharedPartBuilder([EventGenerator()], 'event');

Builder generateManager(BuilderOptions options) => ManagerGenerator();
