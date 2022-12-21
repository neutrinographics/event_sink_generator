import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:event_sync_generator/src/extension_generator.dart';

Builder generateExtension(BuilderOptions options) =>
    SharedPartBuilder([ExtensionGenerator()], 'extension_generator');
