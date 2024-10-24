import 'dart:async';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:event_sink_generator/src/model_visitor.dart';
import 'package:event_sink_generator/src/models/event_config.dart';
import 'package:event_sink_generator/src/models/remote_adapter_config.dart';
import 'package:recase/recase.dart';
import 'package:source_gen/source_gen.dart';

import 'package:event_sink/event_sink.dart';

/// Generates a new sync controller.
class EventSinkGenerator extends GeneratorForAnnotation<EventSinkConfig> {
  @override
  FutureOr<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    final visitor = ModelVisitor();
    element.visitChildren(visitor);
    final events = annotation.read('events').listValue;
    final remotes = annotation.read('remotes').listValue;

    final classBuffer = StringBuffer();

    // generate the sync manager
    if (!visitor.className.startsWith('\$')) {
      throw Exception(
          'The target class of the EventSinkConfig annotation must start with a dollar (\$) sign.');
    }
    final managerName = visitor.className.replaceFirst('\$', '');
    classBuffer.writeln('class $managerName extends EventSink {');
    classBuffer.writeln('$managerName({');
    for (var i = 0; i < events.length; i++) {
      final entry = events[i];
      final eventReader = ConstantReader(entry);
      EventConfig event = resolveEvent(eventReader);
      classBuffer.writeln(
          "required ${event.handlerClassName} ${event.eventPropertyName},");
    }
    for (var i = 0; i < remotes.length; i++) {
      final entry = remotes[i];
      final remoteReader = ConstantReader(entry);
      RemoteAdapterConfig remote = resolveRemoteAdapter(remoteReader);
      classBuffer.writeln("required this.${remote.remoteAdapterPropertyName},");
    }
    classBuffer.writeln('}) :');
    for (var i = 0; i < events.length; i++) {
      final entry = events[i];
      final eventReader = ConstantReader(entry);
      EventConfig event = resolveEvent(eventReader);
      classBuffer
          .writeln("_${event.eventPropertyName} = ${event.eventPropertyName},");
    }
    classBuffer.writeln(' super();');

    // generate properties
    for (var i = 0; i < events.length; i++) {
      final entry = events[i];
      final eventReader = ConstantReader(entry);
      EventConfig event = resolveEvent(eventReader);
      classBuffer.writeln(
          "final ${event.handlerClassName} _${event.eventPropertyName};");
    }
    for (var i = 0; i < remotes.length; i++) {
      final entry = remotes[i];
      final remoteReader = ConstantReader(entry);
      RemoteAdapterConfig remote = resolveRemoteAdapter(remoteReader);
      classBuffer.writeln(
          'final ${remote.remoteAdapterClassName} ${remote.remoteAdapterPropertyName};');
    }

    // generate handler map
    classBuffer.writeln('@override');
    classBuffer.writeln('Map<String, EventHandler> eventHandlersMap() => {');
    // TODO: this is repetitive and inefficient, but it works for now.
    for (var i = 0; i < events.length; i++) {
      final entry = events[i];
      final eventReader = ConstantReader(entry);
      EventConfig event = resolveEvent(eventReader);
      classBuffer
          .writeln("'${event.eventMachineName}': _${event.eventPropertyName},");
    }
    classBuffer.writeln('};');

    // generate params map
    classBuffer.writeln('@override');
    classBuffer.writeln(
        'final Map<String, EventDataGenerator> eventDataGeneratorMap = {');
    // TODO: this is repetitive and inefficient, but it works for now.
    for (var i = 0; i < events.length; i++) {
      final entry = events[i];
      final eventReader = ConstantReader(entry);
      EventConfig event = resolveEvent(eventReader);
      classBuffer.writeln(
          "'${event.eventMachineName}': (Map<String, dynamic> json) => ${event.paramsClassName}.fromJson(json),");
    }
    classBuffer.writeln('};');

    classBuffer.writeln('}');

    // generate handler classes
    for (var i = 0; i < events.length; i++) {
      final entry = events[i];
      final eventReader = ConstantReader(entry);
      EventConfig event = resolveEvent(eventReader);
      classBuffer.writeln(
          "abstract class ${event.handlerClassName} extends EventHandler<${event.paramsClassName}> {}");
    }

    // generate param classes
    // for (var i = 0; i < events.length; i++) {
    //   final entry = events[i];
    //   final eventReader = ConstantReader(entry);
    //   EventConfig event = resolveEvent(eventReader);
    //   classBuffer.writeln(
    //       "abstract class ${event.paramsClassName} implements EventParams {}");
    // }

    // generate event classes
    final List<String> eventNames = [];
    for (var entry in events) {
      var eventReader = ConstantReader(entry);
      EventConfig event = resolveEvent(eventReader);
      if (eventNames.contains(event.eventMachineName)) {
        throw Exception(
            'Duplicate event ${event.eventMachineName}. Event names must be unique.');
      }
      eventNames.add(event.eventMachineName);

      classBuffer.writeln(
          'class ${event.eventClassName} extends EventInfo<${event.paramsClassName}> {');
      classBuffer.writeln(
          'const ${event.eventClassName}({required String streamId, required ${event.paramsClassName} data})');
      classBuffer.writeln(': super(');
      classBuffer.writeln('streamId: streamId,');
      classBuffer.writeln("name: '${event.eventMachineName}',");
      classBuffer.writeln('data: data,');
      classBuffer.writeln(');');
      classBuffer.writeln('@override');
      classBuffer.writeln('List<Object?> get props => [streamId, name, data];');
      classBuffer.writeln('}');
    }

    // generate remote adapters classes
    for (var i = 0; i < remotes.length; i++) {
      final entry = remotes[i];
      final remoteReader = ConstantReader(entry);
      RemoteAdapterConfig remote = resolveRemoteAdapter(remoteReader);
      classBuffer.writeln(
          'abstract class ${remote.remoteAdapterClassName} extends EventRemoteAdapter with RemoteAdapterProperties {');
      classBuffer.writeln('@override');
      classBuffer
          .writeln('PullStrategy get pullStrategy => ${remote.pullStrategy};');
      classBuffer.writeln('@override');
      classBuffer.writeln('int get priority => ${remote.priority};');
      classBuffer.writeln('}');
    }

    return classBuffer.toString();
  }

  EventConfig resolveEvent(ConstantReader eventReader) {
    final eventName = eventReader.read('name').stringValue;
    final eventType = eventReader.objectValue.type;
    // final command = eventReader.read('handler').objectValue;
    // final commandType = command.type;

    if (eventType == null) {
      throw Exception(
          'Missing event data type. You must specify a data type like Event<MyEventData>()');
    }

    // final className = commandType.getDisplayString(withNullability: false);
    final genericClassType = getEventDataType(eventType);
    final paramsClassName =
        genericClassType.getDisplayString(withNullability: false);
    return EventConfig(
      eventMachineName: eventName.snakeCase,
      eventPropertyName: eventName.camelCase,
      eventClassName: '${eventName.pascalCase}Event',
      handlerClassName: '\$${eventName.pascalCase}EventHandler',
      paramsClassName: paramsClassName, //'${eventName.pascalCase}EventParams',
    );
  }

  RemoteAdapterConfig resolveRemoteAdapter(ConstantReader remoteReader) {
    final remoteName = remoteReader.read('name').stringValue;
    final priority = remoteReader.read('priority').intValue;
    final pullStrategy = remoteReader
        .read('pullStrategy')
        .objectValue
        .getField('_name')
        ?.toStringValue();

    if (pullStrategy == null) {
      throw Exception('Cannot resolve pull strategy');
    }

    return RemoteAdapterConfig(
      remoteAdapterClassName: '\$${remoteName.pascalCase}RemoteAdapter',
      remoteAdapterPropertyName: '${remoteName.camelCase}RemoteAdapter',
      priority: priority,
      pullStrategy: 'PullStrategy.$pullStrategy',
    );
  }

  bool canHaveGenerics(DartType type) {
    final element = type.element;
    if (element is ClassElement) {
      element.allSupertypes;
      return element.typeParameters.isNotEmpty;
    }
    return false;
  }

  DartType getEventDataType(DartType type) {
    final element = type.element;
    if (element is ClassElement) {
      final genericTypes = getGenericTypes(type);
      if (genericTypes.isEmpty) {
        throw Exception('Missing event data type');
      }
      final dataType = genericTypes.first;
      if (genericTypes.first is ClassElement) {
        throw Exception('Event Data type must be a class');
      }
      return dataType;
    } else {
      throw Exception('Event must be a class');
    }
  }

  DartType getCommandParamType(DartType type) {
    String commandName = type.getDisplayString(withNullability: false);
    final element = type.element;
    if (element is ClassElement) {
      final superTypes = element.allSupertypes;
      if (superTypes.isEmpty) {
        throw Exception('Event command $commandName must extend Command');
      }
      final genericTypes = getGenericTypes(superTypes.first);
      if (genericTypes.isEmpty) {
        throw Exception('No generic types found on $commandName');
      }
      return genericTypes.first;
    } else {
      throw Exception('Event command $commandName must be a class');
    }
  }

  Iterable<DartType> getGenericTypes(DartType type) {
    return type is ParameterizedType ? type.typeArguments : const [];
  }
}
