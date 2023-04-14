import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:event_sink_generator/src/event_sink_generator.dart';

Builder generateSinkManager(BuilderOptions options) =>
    SharedPartBuilder([EventSinkGenerator()], 'manager');
