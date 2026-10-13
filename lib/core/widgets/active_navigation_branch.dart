import 'package:flutter/widgets.dart';

class ActiveNavigationBranch extends InheritedWidget {
  const ActiveNavigationBranch({
    required this.index,
    required super.child,
    super.key,
  });

  final int index;

  static ActiveNavigationBranch? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ActiveNavigationBranch>();
  }

  bool isActive(int branchIndex) => index == branchIndex;

  @override
  bool updateShouldNotify(ActiveNavigationBranch oldWidget) {
    return index != oldWidget.index;
  }
}
