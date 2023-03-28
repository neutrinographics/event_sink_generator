class EventConfig {
  final String eventClassName;
  final String handlerClassName;
  final String paramsClassName;
  final String eventMachineName;
  final String eventPropertyName;

  EventConfig({
    required this.eventClassName,
    required this.handlerClassName,
    required this.paramsClassName,
    required this.eventMachineName,
    required this.eventPropertyName,
  });
}
