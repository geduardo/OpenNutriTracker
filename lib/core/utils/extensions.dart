import 'dart:math';

import 'package:flutter/material.dart';

extension Cast on Object? {
  double? asDoubleOrNull() {
    double? value;
    if (this is int) {
      final intValue = this as int;
      value = intValue.toDouble();
    } else if (this is double) {
      value = this as double;
    } else if (this is String) {
      // OFF sometimes sends values such as "", "<0.5" or "1,5".
      final cleaned = (this as String)
          .trim()
          .replaceAll(RegExp(r'^[<>~≈]+'), '')
          .replaceAll(',', '.');
      value = double.tryParse(cleaned);
    } else {
      value = null;
    }

    return value;
  }
}

extension CastString on String {
  String? toStringOrNull() {
    if (isEmpty) {
      return null;
    } else {
      return this;
    }
  }

  double? toDoubleOrNull() {
    if (isEmpty) {
      return null;
    } else {
      return double.parse(this);
    }
  }
}

extension Round on double {
  double roundToPrecision(int n) {
    int fac = pow(10, n).toInt();
    return (this * fac).round() / fac;
  }
}

extension DisplayDouble on double? {
  String toStringOrEmpty() {
    if (this == null) {
      return "";
    } else {
      return toString();
    }
  }
}

extension FormatString on DateTime {
  /// Storage key for a calendar day. Fixed ASCII format, independent of the
  /// app language.
  String toParsedDay() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

extension ColorExtension on Color {
  /// Converts the color to a hexadecimal string.
  String toHex() {
    final red = (r * 255).toInt().toRadixString(16).padLeft(2, '0');
    final green = (g * 255).toInt().toRadixString(16).padLeft(2, '0');
    final blue = (b * 255).toInt().toRadixString(16).padLeft(2, '0');

    return '#' '$red$green$blue'.toUpperCase();
  }
}
