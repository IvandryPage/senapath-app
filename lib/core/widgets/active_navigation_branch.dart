import 'package:flutter/widgets.dart';

class ActiveNavigationBranch extends InheritedWidget {
  /// Membuat inherited widget yang meneruskan indeks cabang navigasi aktif.
  const ActiveNavigationBranch({
    required this.index,
    required super.child,
    super.key,
  });

  final int index;

  /// Mengambil instance terdekat dan mendaftarkan konteks pada pembaruannya.
  static ActiveNavigationBranch? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ActiveNavigationBranch>();
  }

  /// Menentukan apakah cabang dengan [branchIndex] sedang aktif.
  bool isActive(int branchIndex) => index == branchIndex;

  /// Memberi tahu dependen hanya ketika indeks cabang aktif berubah.
  @override
  bool updateShouldNotify(ActiveNavigationBranch oldWidget) {
    return index != oldWidget.index;
  }
}
