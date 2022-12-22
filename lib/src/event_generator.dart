import 'dart:async';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:event_sync_generator/src/event_model_visitor.dart';
import 'package:event_sync_generator/src/models/event_config.dart';
import 'package:recase/recase.dart';
import 'package:source_gen/source_gen.dart';

import 'package:event_sync/event_sync.dart';

/// Generates individual event classes
@Deprecated('Use the SyncManagerGenerator instead')
class EventGenerator extends GeneratorForAnnotation<SynchronizedEvent> {
  final List<String> eventNames = [];

  @override
  FutureOr<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    final classBuffer = StringBuffer();
    final visitor = EventModelVisitor();
    element.visitChildren(visitor);

    // generate event class
    final eventClassName = '${visitor.className}Event';
    final String eventName =
        annotation.peek('name')?.stringValue ?? visitor.className.snakeCase;

    // prevent duplicate event names
    if (eventNames.contains(eventName)) {
      throw Exception(
          "Duplicate event '$eventName'. Each event must have a unique name.");
    }
    eventNames.add(eventName);

    classBuffer.writeln();
    classBuffer.writeln(
        'class $eventClassName extends EventInfo<${visitor.paramsClassName}> {');
    classBuffer.writeln(
        'const $eventClassName({required String streamId, required ${visitor.paramsClassName} params})');
    classBuffer.writeln(': super(');
    classBuffer.writeln('streamId: streamId,');
    classBuffer.writeln("name: '$eventName',");
    classBuffer.writeln('data: params,');
    classBuffer.writeln(');');
    classBuffer.writeln('}');

    // extend the event handler
    // classBuffer.writeln('extension ${visitor.className}Extension on ${visitor.className} {');
    // classBuffer.writeln('@override');
    // classBuffer.writeln("String get name => '$eventName';");
    // classBuffer.writeln('}');
    return classBuffer.toString();
  }

  EventConfig resolveEvent(ConstantReader eventReader) {
    final command = eventReader.read('command').objectValue;
    final commandType = command.type;
    // final command = eventReader.peek('command')?.typeValue;

    if (commandType == null) {
      throw Exception('Unknown command type');
    }

    final className = commandType.getDisplayString(withNullability: false);
    final genericClassType = getCommandParamType(commandType);
    final paramsClassName =
        genericClassType.getDisplayString(withNullability: false);

    return EventConfig(
      commandClassName: className,
      paramsClassName: paramsClassName,
    );
  }

  bool canHaveGenerics(DartType type) {
    final element = type.element2;
    if (element is ClassElement) {
      element.allSupertypes;
      return element.typeParameters.isNotEmpty;
    }
    return false;
  }

  DartType getCommandParamType(DartType type) {
    String commandName = type.getDisplayString(withNullability: false);
    final element = type.element2;
    if (element is ClassElement) {
      final superTypes = element.allSupertypes;
      if (superTypes.isEmpty) {
        throw Exception('Event command $commandName must extend Command');
      }
      final genericTypes = getGenericTypes(superTypes.first);
      return genericTypes.first;
    } else {
      throw Exception('Event command $commandName must be a class');
    }
  }

  Iterable<DartType> getGenericTypes(DartType type) {
    return type is ParameterizedType ? type.typeArguments : const [];
  }
}
