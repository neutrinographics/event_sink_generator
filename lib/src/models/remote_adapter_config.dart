class RemoteAdapterConfig {
  final String remoteAdapterClassName;
  final String remoteAdapterPropertyName;
  final int priority;
  final String pullStrategy;

  RemoteAdapterConfig({
    required this.remoteAdapterClassName,
    required this.remoteAdapterPropertyName,
    required this.priority,
    required this.pullStrategy,
  });
}
