import 'package:analyzer/dart/element/visitor2.dart';
import 'package:analyzer/dart/element/element.dart';

class ModelVisitor extends SimpleElementVisitor2<void> {
  late String className;

  @override
  void visitConstructorElement(ConstructorElement element) {
    // get the event type
    final elementReturnType = element.type.returnType.toString();
    className = elementReturnType.replaceFirst('*', '');
  }
}
