import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';

class GetIntakeUsecase {
  final IntakeRepository _intakeRepository;

  GetIntakeUsecase(this._intakeRepository);

  Future<List<IntakeEntity>> _getIntakeByDay(
      IntakeTypeEntity type, DateTime day) async {
    return await _intakeRepository.getIntakeByDateAndType(type, day);
  }

  Future<List<IntakeEntity>> getBreakfastIntakeByDay(day) async =>
      await _getIntakeByDay(IntakeTypeEntity.breakfast, day);

  Future<List<IntakeEntity>> getTodayBreakfastIntake() async =>
      getBreakfastIntakeByDay(DateTime.now());

  Future<List<IntakeEntity>> getLunchIntakeByDay(day) async =>
      await _getIntakeByDay(IntakeTypeEntity.lunch, day);

  Future<List<IntakeEntity>> getTodayLunchIntake() async =>
      await getLunchIntakeByDay(DateTime.now());

  Future<List<IntakeEntity>> getDinnerIntakeByDay(day) async =>
      await _getIntakeByDay(IntakeTypeEntity.dinner, day);

  Future<List<IntakeEntity>> getTodayDinnerIntake() async =>
      await getDinnerIntakeByDay(DateTime.now());

  Future<List<IntakeEntity>> getSnackIntakeByDay(day) async =>
      await _getIntakeByDay(IntakeTypeEntity.snack, day);

  Future<List<IntakeEntity>> getTodaySnackIntake() async =>
      await getSnackIntakeByDay(DateTime.now());

  Future<List<IntakeEntity>> getRecentIntake() async {
    return _intakeRepository.getRecentIntake();
  }

  /// Every persisted intake. Used by the diary self-healing pass that
  /// recomputes per-day aggregates from the authoritative intake list.
  Future<List<IntakeEntity>> getAllIntakes() async {
    return _intakeRepository.getAllIntakes();
  }

  Future<IntakeEntity?> getIntakeById(String intakeId) async {
    return _intakeRepository.getIntakeById(intakeId);
  }

  Future<IntakeEntity?> getLastIntakeForMeal(
      String? code, String? name) async {
    return _intakeRepository.getLastIntakeForMeal(code, name);
  }
}
