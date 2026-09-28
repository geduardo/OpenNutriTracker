// Reference calculations are educational, not a diagnostic growth standard.
DateTime calendarDate(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

enum PregnancyType { singleton, twins, higherOrder }

abstract final class PregnancyDating {
  // Inclusive support for every day in weeks 0–42. This is an input window,
  // not a recommendation about the duration of an individual pregnancy.
  static const maxGestationDays = 42 * 7 + 6;

  static DateTime dueDateFromStage(
      {required DateTime onDate, required int weeks, required int days}) {
    if (weeks < 0 || weeks > 42 || days < 0 || days > 6) {
      throw ArgumentError('Enter weeks 0–42 and additional days 0–6.');
    }
    return calendarDate(onDate).add(Duration(days: 280 - weeks * 7 - days));
  }

  static bool supports(PregnancyProfile profile, DateTime day) {
    final age = profile.gestationDays(day);
    return age >= 0 && age <= maxGestationDays;
  }
}

class PregnancySetupResult {
  final PregnancyProfile profile;
  final WeightEntry? firstReading;
  const PregnancySetupResult(this.profile, {this.firstReading});
}

class PregnancyProfile {
  final DateTime dueDate;
  final double? prePregnancyKg;
  final double? heightCm;
  final PregnancyType type;
  final double? maintenanceKcal;
  final double? clinicianEnergyKcal;

  PregnancyProfile({
    required DateTime dueDate,
    this.prePregnancyKg,
    this.heightCm,
    this.type = PregnancyType.singleton,
    this.maintenanceKcal,
    this.clinicianEnergyKcal,
  }) : dueDate = calendarDate(dueDate) {
    for (final value in [maintenanceKcal, clinicianEnergyKcal]) {
      if (value != null && (!value.isFinite || value <= 0)) {
        throw ArgumentError('Energy must be positive');
      }
    }
    if (prePregnancyKg != null &&
        (!prePregnancyKg!.isFinite || prePregnancyKg! <= 0)) {
      throw ArgumentError('Pre-pregnancy weight must be positive.');
    }
    if (heightCm != null && (!heightCm!.isFinite || heightCm! <= 0)) {
      throw ArgumentError('Height must be positive.');
    }
  }

  DateTime get startDate => dueDate.subtract(const Duration(days: 280));
  int gestationDays(DateTime day) =>
      calendarDate(day).difference(startDate).inDays;
  double gestationWeeks(DateTime day) => gestationDays(day) / 7;
  double? get prePregnancyBmi => prePregnancyKg == null || heightCm == null
      ? null
      : prePregnancyKg! / ((heightCm! / 100) * (heightCm! / 100));

  Map<String, dynamic> toJson() => {
        'dueDate': dueDate.toIso8601String(),
        'prePregnancyKg': prePregnancyKg,
        'heightCm': heightCm,
        'type': type.name,
        'maintenanceKcal': maintenanceKcal,
        'clinicianEnergyKcal': clinicianEnergyKcal,
      };

  factory PregnancyProfile.fromJson(Map<String, dynamic> json) =>
      PregnancyProfile(
        dueDate: DateTime.parse(json['dueDate'] as String),
        prePregnancyKg: (json['prePregnancyKg'] as num?)?.toDouble(),
        heightCm: (json['heightCm'] as num?)?.toDouble(),
        type: PregnancyType.values.byName(json['type'] as String),
        maintenanceKcal: (json['maintenanceKcal'] as num?)?.toDouble(),
        clinicianEnergyKcal: (json['clinicianEnergyKcal'] as num?)?.toDouble(),
      );
}

class WeightEntry {
  final DateTime date;
  final double kg;
  final String source;
  final String? sourcePackage;
  final DateTime? measuredAt;
  WeightEntry(DateTime date, this.kg,
      {this.source = 'manual', this.sourcePackage, this.measuredAt})
      : date = calendarDate(date) {
    if (!kg.isFinite || kg <= 0) throw ArgumentError('Invalid weight.');
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'kg': kg,
        'source': source,
        'sourcePackage': sourcePackage,
        'measuredAt': measuredAt?.toIso8601String()
      };
  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
      DateTime.parse(json['date'] as String), (json['kg'] as num).toDouble(),
      source: json['source'] as String? ?? 'manual',
      sourcePackage: json['sourcePackage'] as String?,
      measuredAt: DateTime.tryParse(json['measuredAt'] as String? ?? ''));
}

class GainRange {
  final double low;
  final double high;
  const GainRange(this.low, this.high);
}

class PregnancyReference {
  /// National Academies 2009 singleton total gain (kg), also used by CDC.
  /// Never classify using weight measured during pregnancy.
  static GainRange? totalGain(PregnancyProfile profile) {
    final bmi = profile.prePregnancyBmi;
    if (profile.type != PregnancyType.singleton || bmi == null) return null;
    if (bmi < 18.5) return const GainRange(12.5, 18);
    if (bmi < 25) return const GainRange(11.5, 16);
    if (bmi < 30) return const GainRange(7, 11.5);
    return const GainRange(5, 9);
  }

  /// IOM 2009 Table S-1: average weekly rates in trimesters 2 and 3.
  /// These are guidance, not week-specific population centiles.
  static GainRange? weeklyRate(PregnancyProfile profile) {
    final bmi = profile.prePregnancyBmi;
    if (profile.type != PregnancyType.singleton || bmi == null) return null;
    if (bmi < 18.5) return const GainRange(.44, .58);
    if (bmi < 25) return const GainRange(.35, .50);
    if (bmi < 30) return const GainRange(.23, .33);
    return const GainRange(.17, .27);
  }
}

class PregnancyData {
  final PregnancyProfile? profile;
  final List<WeightEntry> weights;
  final bool healthSyncEnabled;
  final DateTime? lastHealthSync;
  final Set<String> hiddenHealthDays;
  PregnancyData(
      {this.profile,
      List<WeightEntry> weights = const [],
      this.healthSyncEnabled = false,
      this.lastHealthSync,
      Set<String> hiddenHealthDays = const {}})
      : weights = List.unmodifiable(
            [...weights]..sort((a, b) => a.date.compareTo(b.date))),
        hiddenHealthDays = Set.unmodifiable(hiddenHealthDays);

  static String dayKey(DateTime day) =>
      calendarDate(day).toIso8601String().substring(0, 10);
  PregnancyData copyWith(
          {PregnancyProfile? profile,
          List<WeightEntry>? weights,
          bool? healthSyncEnabled,
          DateTime? lastHealthSync,
          Set<String>? hiddenHealthDays}) =>
      PregnancyData(
          profile: profile ?? this.profile,
          weights: weights ?? this.weights,
          healthSyncEnabled: healthSyncEnabled ?? this.healthSyncEnabled,
          lastHealthSync: lastHealthSync ?? this.lastHealthSync,
          hiddenHealthDays: hiddenHealthDays ?? this.hiddenHealthDays);
  PregnancyData withProfile(PregnancyProfile value) => copyWith(profile: value);
  PregnancyData withWeight(WeightEntry entry) => copyWith(
      weights: [...weights.where((value) => value.date != entry.date), entry]);
  PregnancyData withoutWeight(WeightEntry entry) => copyWith(
          weights: weights.where((value) => value.date != entry.date).toList(),
          hiddenHealthDays: {
            ...hiddenHealthDays,
            if (entry.source == 'healthConnect') dayKey(entry.date)
          });

  Map<String, dynamic> toJson() => {
        'schema': 1,
        'profile': profile?.toJson(),
        'weights': weights.map((value) => value.toJson()).toList(),
        'healthSyncEnabled': healthSyncEnabled,
        'lastHealthSync': lastHealthSync?.toIso8601String(),
        'hiddenHealthDays': hiddenHealthDays.toList(),
      };
  factory PregnancyData.fromJson(Map<String, dynamic> json) {
    if (json['schema'] != 1) {
      throw const FormatException('Unsupported data version');
    }
    return PregnancyData(
      profile: json['profile'] == null
          ? null
          : PregnancyProfile.fromJson(json['profile'] as Map<String, dynamic>),
      weights: (json['weights'] as List)
          .map((value) => WeightEntry.fromJson(value as Map<String, dynamic>))
          .toList(),
      healthSyncEnabled: json['healthSyncEnabled'] as bool? ?? false,
      lastHealthSync:
          DateTime.tryParse(json['lastHealthSync'] as String? ?? ''),
      hiddenHealthDays:
          (json['hiddenHealthDays'] as List? ?? []).cast<String>().toSet(),
    );
  }
}
