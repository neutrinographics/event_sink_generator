import 'dart:async';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:event_sink_generator/src/model_visitor.dart';
import 'package:event_sink_generator/src/models/data_source_config.dart';
import 'package:event_sink_generator/src/models/event_config.dart';
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
    final dataSources = annotation.read('dataSources').listValue;
    final events = annotation.read('events').listValue;

    final classBuffer = StringBuffer();

    // generate the sync manager
    if (!visitor.className.startsWith('\$')) {
      throw Exception(
          'The target class of the EventSinkConfig annotation must start with a dollar (\$) sign.');
    }
    final managerName = visitor.className.replaceFirst('\$', '');
    classBuffer.writeln('class $managerName extends EventSink {');
    classBuffer.writeln('$managerName({');
    classBuffer.writeln("required this.dataSources,");
    for (var i = 0; i < events.length; i++) {
      final entry = events[i];
      final eventReader = ConstantReader(entry);
      EventConfig event = resolveEvent(eventReader);
      classBuffer.writeln(
          "required ${event.handlerClassName} ${event.eventPropertyName},");
    }
    classBuffer.writeln('}) :');
    for (var i = 0; i < events.length; i++) {
      final entry = events[i];
      final eventReader = ConstantReader(entry);
      EventConfig event = resolveEvent(eventReader);
      classBuffer.writeln(
          "this._${event.eventPropertyName} = ${event.eventPropertyName},");
    }
    classBuffer.writeln(' super();');

    // generate properties
    classBuffer.writeln('final \$DataSources dataSources;');
    for (var i = 0; i < events.length; i++) {
      final entry = events[i];
      final eventReader = ConstantReader(entry);
      EventConfig event = resolveEvent(eventReader);
      classBuffer.writeln(
          "final ${event.handlerClassName} _${event.eventPropertyName};");
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

    // generate data sources class
    classBuffer.writeln('class \$DataSources {');
    classBuffer.writeln('const \$DataSources({');
    for (var i = 0; i < dataSources.length; i++) {
      final entry = dataSources[i];
      final dataSourceReader = ConstantReader(entry);
      DataSourceConfig dataSource = resolveDataSource(dataSourceReader);
      classBuffer
          .writeln('required this.${dataSource.dataSourcePropertyName},');
    }
    classBuffer.writeln('});');
    for (var i = 0; i < dataSources.length; i++) {
      final entry = dataSources[i];
      final dataSourceReader = ConstantReader(entry);
      DataSourceConfig dataSource = resolveDataSource(dataSourceReader);
      classBuffer.writeln(
          'final ${dataSource.dataSourceClassName} ${dataSource.dataSourcePropertyName};');
    }
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

    return classBuffer.toString();
  }

  DataSourceConfig resolveDataSource(ConstantReader dataSourceReader) {
    final dataSourceName = dataSourceReader.read('name').stringValue;
    final dataSourceType = dataSourceReader.objectValue.type;

    if (dataSourceType == null) {
      throw Exception(
          'Missing data source data type. You must specify a data type like DataSource<EventDataSource>()');
    }

    final genericClassType = getEventDataType(dataSourceType);
    final dataSourceClassName =
        genericClassType.getDisplayString(withNullability: false);
    return DataSourceConfig(
      dataSourceClassName: dataSourceClassName.pascalCase,
      dataSourcePropertyName: dataSourceName.camelCase,
    );
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
