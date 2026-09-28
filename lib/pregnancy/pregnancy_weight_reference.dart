import 'pregnancy_model.dart';

/// Cheikh Ismail et al., BMJ 2016;352:i555. Oxford published centile table:
/// https://media.tghn.org/medialibrary/2017/05/GROW_GWG-nw-ct_Table.pdf
/// Exact weeks 15–40; columns are 10th, 50th, 90th centiles in kg.
/// Gain is relative to the first-trimester enrollment weight, NOT pre-pregnancy.
abstract final class PregnancyWeightReference {
  static const centiles = <List<double>>[
    [-1.1, .4, 2.2],
    [-.6, 1, 2.9],
    [-.1, 1.6, 3.7],
    [.4, 2.2, 4.4],
    [.8, 2.8, 5.1],
    [1.2, 3.3, 5.8],
    [1.7, 3.8, 6.5],
    [2.1, 4.4, 7.2],
    [2.4, 4.9, 7.9],
    [2.8, 5.4, 8.6],
    [3.2, 5.9, 9.3],
    [3.6, 6.5, 10],
    [3.9, 7, 10.7],
    [4.3, 7.5, 11.4],
    [4.7, 8, 12.1],
    [5, 8.5, 12.9],
    [5.4, 9, 13.6],
    [5.7, 9.5, 14.3],
    [6.1, 10, 15],
    [6.5, 10.5, 15.7],
    [6.8, 11.1, 16.5],
    [7.2, 11.6, 17.2],
    [7.6, 12.1, 17.9],
    [7.9, 12.6, 18.7],
    [8.3, 13.2, 19.4],
    [8.7, 13.7, 20.1],
  ];

  /// Match the study's enrollment window (9+0–13+6), using the earliest
  /// available reading there. Never substitute current or pre-pregnancy weight.
  static WeightEntry? baseline(
      PregnancyProfile profile, List<WeightEntry> entries) {
    if (profile.type != PregnancyType.singleton || profile.heightCm == null) {
      return null;
    }
    final eligible = entries.where((e) {
      final days = profile.gestationDays(e.date);
      return days >= 63 && days < 98;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (eligible.isEmpty) return null;
    final first = eligible.first;
    final h = profile.heightCm! / 100;
    final bmi = first.kg / (h * h);
    return bmi >= 18.5 && bmi < 25 ? first : null;
  }

  /// Adjacent published weeks are interpolated for days, with no extrapolation.
  static List<double>? atWeek(double week) {
    if (!week.isFinite || week < 15 || week > 40) return null;
    final index = week.floor() - 15;
    if (index == 25) return centiles.last;
    final fraction = week - week.floor();
    return List.generate(
        3,
        (i) =>
            centiles[index][i] +
            (centiles[index + 1][i] - centiles[index][i]) * fraction);
  }
}
