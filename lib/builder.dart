import 'package:build/build.dart';
import 'package:event_sync_generator/src/event_generator.dart';
import 'package:event_sync_generator/src/manager_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:event_sync_generator/src/sync_manager_generator.dart';

Builder generateSyncManager(BuilderOptions options) =>
    SharedPartBuilder([SyncManagerGenerator()], 'manager');

Builder generateEvents(BuilderOptions options) =>
    SharedPartBuilder([EventGenerator()], 'event');

Builder generateManager(BuilderOptions options) => ManagerGenerator();
