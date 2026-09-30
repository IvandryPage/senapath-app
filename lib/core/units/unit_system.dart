enum UnitSystem {
  metric('metric'),
  imperial('imperial');

  const UnitSystem(this.storageValue);

  final String storageValue;

  static UnitSystem fromStorage(String? value) =>
      value == imperial.storageValue ? imperial : metric;
}
