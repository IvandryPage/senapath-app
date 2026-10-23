enum UnitSystem {
  metric('metric'),
  imperial('imperial');

  /// Membuat nilai enum dengan representasi penyimpanan yang dipakai.
  const UnitSystem(this.storageValue);

  final String storageValue;

  /// Mengubah nilai penyimpanan menjadi satuan, default metrik bila tak dikenal.
  static UnitSystem fromStorage(String? value) =>
      value == imperial.storageValue ? imperial : metric;
}
