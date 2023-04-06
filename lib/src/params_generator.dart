import 'dart:async';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'package:event_sink/event_sink.dart';

@Deprecated('This has not been implemented yet')
class ParamsGenerator extends GeneratorForAnnotation<EventSerializable> {
  @override
  FutureOr<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    final classBuffer = StringBuffer();
    // TODO: generate a serializable event params class.
    return classBuffer.toString();
  }
}
