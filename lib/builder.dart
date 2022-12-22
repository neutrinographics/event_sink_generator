import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:event_sync_generator/src/sync_controller_generator.dart';

Builder generateSyncManager(BuilderOptions options) =>
    SharedPartBuilder([SyncControllerGenerator()], 'manager');
