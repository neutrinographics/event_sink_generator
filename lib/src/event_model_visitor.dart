import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/element.dart';

class EventModelVisitor {
  late String className;
  late String paramsClassName;

  void visitConstructorElement(ConstructorElement element) {
    // get the event type
    final elementReturnType = element.type.returnType.toString();
    className = elementReturnType.replaceFirst('*', '');

    // get the event params type
    final genericTypes = getInheritedGenericTypes(element.type.returnType);
    if (genericTypes.isEmpty) {
      throw Exception('Missing params generic type');
    }
    paramsClassName = genericTypes.first.getDisplayString();
  }

  Iterable<DartType> getInheritedGenericTypes(DartType type) {
    final element = type.element;
    if (element is ClassElement) {
      final superTypes = element.allSupertypes;

      return getGenericTypes(superTypes.first);
    }
    return [];
  }

  Iterable<DartType> getGenericTypes(DartType type) {
    return type is ParameterizedType ? type.typeArguments : const [];
  }
}
