import 'dart:io';

import 'package:flutter/services.dart';

class HealthConnectStatus {
  final bool available;
  final bool updateRequired;
  final bool permissionsGranted;
  final bool historyPermissionGranted;

  const HealthConnectStatus({
    required this.available,
    required this.updateRequired,
    required this.permissionsGranted,
    required this.historyPermissionGranted,
  });

  factory HealthConnectStatus.fromMap(Map<dynamic, dynamic> map) {
    return HealthConnectStatus(
      available: map['available'] as bool? ?? false,
      updateRequired: map['updateRequired'] as bool? ?? false,
      permissionsGranted: map['permissionsGranted'] as bool? ?? false,
      historyPermissionGranted:
          map['historyPermissionGranted'] as bool? ?? false,
    );
  }
}

class HealthConnectWeightSample {
  final DateTime time;
  final double weightKg;
  final String? sourcePackageName;

  const HealthConnectWeightSample({
    required this.time,
    required this.weightKg,
    this.sourcePackageName,
  });

  factory HealthConnectWeightSample.fromMap(Map<dynamic, dynamic> map) {
    return HealthConnectWeightSample(
      time: DateTime.fromMillisecondsSinceEpoch(
        (map['timeMillis'] as num).toInt(),
      ),
      weightKg: (map['weightKg'] as num).toDouble(),
      sourcePackageName: map['sourcePackageName'] as String?,
    );
  }
}

class HealthConnectWeightService {
  static const MethodChannel _channel = MethodChannel(
    'opennutritracker/health_connect',
  );

  Future<HealthConnectStatus> getStatus() async {
    if (!Platform.isAndroid) {
      return const HealthConnectStatus(
        available: false,
        updateRequired: false,
        permissionsGranted: false,
        historyPermissionGranted: false,
      );
    }

    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('getStatus');
    return HealthConnectStatus.fromMap(map ?? const {});
  }

  Future<HealthConnectStatus> requestPermissions() async {
    if (!Platform.isAndroid) {
      return const HealthConnectStatus(
        available: false,
        updateRequired: false,
        permissionsGranted: false,
        historyPermissionGranted: false,
      );
    }

    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'requestPermissions',
    );
    return HealthConnectStatus.fromMap(map ?? const {});
  }

  Future<List<HealthConnectWeightSample>> readWeights(
      {int daysBack = 3650}) async {
    if (!Platform.isAndroid) {
      return const [];
    }

    final response = await _channel.invokeMethod<List<dynamic>>(
      'readWeights',
      {'daysBack': daysBack},
    );

    return (response ?? const [])
        .map((entry) => HealthConnectWeightSample.fromMap(entry as Map))
        .toList();
  }

  Future<bool> openHealthConnectSettings() async {
    if (!Platform.isAndroid) {
      return false;
    }

    return await _channel.invokeMethod<bool>('openHealthConnectSettings') ??
        false;
  }

  Future<bool> openHealthConnectManageData() async {
    if (!Platform.isAndroid) {
      return false;
    }

    return await _channel.invokeMethod<bool>('openHealthConnectManageData') ??
        false;
  }

  Future<bool> openHealthConnectStore() async {
    if (!Platform.isAndroid) {
      return false;
    }

    return await _channel.invokeMethod<bool>('openHealthConnectStore') ?? false;
  }
}
