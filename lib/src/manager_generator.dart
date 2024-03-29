import 'dart:async';

import 'package:build/build.dart';

// https://stackoverflow.com/questions/56972823/dart-build-runner-generate-one-dart-file-with-content
@Deprecated('Use SinkManagerGenerator instead')
class ManagerGenerator implements Builder {
  @override
  Future<void> build(BuildStep buildStep) async {
    final classBuilder = StringBuffer();

    // final events = buildStep.findAssets(Glob('**/*.event.g.dart'));
    // await for (var exportedLibrary in events) {
    //   // final eventName = exportedLibrary.pathSegments.last;
    //   final library = await buildStep.inputLibrary;
    //   final reader = LibraryReader(library);
    //   classBuilder.writeln(
    //       '// ${reader.classes.first.getDisplayString(withNullability: false)}');
    //   // TODO: read the event information
    // }

    classBuilder.writeln('// hello world!');

    await buildStep.writeAsString(
        AssetId(buildStep.inputId.package, 'lib/event_sink.g.dart'),
        classBuilder.toString());
  }

  @override
  final buildExtensions = const {
    r'$lib$': ['event_sink.g.dart']
  };
}
