import 'dart:async';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:event_sync_generator/src/model_visitor.dart';
import 'package:event_sync_generator/src/models/event_config.dart';
import 'package:recase/recase.dart';
import 'package:source_gen/source_gen.dart';

import 'package:event_sync/event_sync.dart';

class ExtensionGenerator extends GeneratorForAnnotation<EventSync> {
  @override
  FutureOr<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    final visitor = ModelVisitor();
    element.visitChildren(visitor);
    final events = annotation.read('events').listValue;

    final classBuffer = StringBuffer();

    // generate the sync manager
    if (!visitor.className.startsWith('\$')) {
      throw Exception(
          'The target class of the EventSync annotation must start with a dollar (\$) sign.');
    }
    final managerName = visitor.className.replaceFirst('\$', '');
    classBuffer.writeln('class $managerName extends EventSyncBase {');
    classBuffer.writeln('@override');
    classBuffer.writeln('final Map<String, Command> commandsMap = {');
    // TODO: this isn't repetitive and inefficient, but it works for now.
    for (var entry in events) {
      var eventReader = ConstantReader(entry);
      EventConfig event = resolveEvent(eventReader);
      final String eventName = event.className.snakeCase;
      classBuffer.writeln("'$eventName': ${event.className}(),");
    }
    classBuffer.writeln('};');
    classBuffer.writeln('}');

    // generate event types
    final List<String> eventNames = [];
    for (var entry in events) {
      var eventReader = ConstantReader(entry);
      EventConfig event = resolveEvent(eventReader);
      final String eventName = event.className.snakeCase;
      if (eventNames.contains(eventName)) {
        throw Exception('Duplicate event $eventName. You tried registering the event command ${event.className} more than once.');
      }
      eventNames.add(eventName);
      final String eventClassName = '${event.className}Event';

      classBuffer.writeln(
          'class $eventClassName extends EventInfo<${event.paramsClassName}> {');
      classBuffer.writeln(
          'const $eventClassName({required String streamId, required ${event.paramsClassName} params})');
      classBuffer.writeln(': super(');
      classBuffer.writeln('streamId: streamId,');
      classBuffer.writeln("name: '$eventName',");
      classBuffer.writeln('data: params,');
      classBuffer.writeln(');');
      classBuffer.writeln('}');
    }

    return classBuffer.toString();
  }

  void generateGettersAndSetters(
      ModelVisitor visitor, StringBuffer classBuffer) {
    for (final field in visitor.fields.keys) {
      final variable =
          field.startsWith('_') ? field.replaceFirst('_', '') : field;

      classBuffer.writeln(
          "${visitor.fields[field]} get $variable => variables['$variable'];");

      classBuffer.writeln('set $variable(${visitor.fields[field]} $variable)');
      classBuffer.writeln('=> $field = $variable;');
    }
  }

  EventConfig resolveEvent(ConstantReader eventReader) {
    final command = eventReader.peek('command')?.typeValue;

    if (command == null) {
      throw Exception('Event must have a command');
    }

    final className = command.getDisplayString(withNullability: false);
    final genericClassType = getCommandParamType(command);
    final paramsClassName =
        genericClassType.getDisplayString(withNullability: false);

    return EventConfig(
      className: className,
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