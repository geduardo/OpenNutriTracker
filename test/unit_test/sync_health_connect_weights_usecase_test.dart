import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:opennutritracker/core/data/data_source/user_data_source.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_gender_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_pal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_weight_goal_dbo.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/features/strategy/data/data_source/weight_entry_data_source.dart';
import 'package:opennutritracker/features/strategy/data/dbo/weight_entry_dbo.dart';
import 'package:opennutritracker/features/strategy/data/repository/weight_entry_repository.dart';
import 'package:opennutritracker/features/strategy/domain/entity/weight_entry_entity.dart';
import 'package:opennutritracker/features/strategy/domain/service/health_connect_weight_service.dart';
import 'package:opennutritracker/features/strategy/domain/usecase/sync_health_connect_weights_usecase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userBoxName = 'user_sync_health_connect_test';
  const weightBoxName = 'weight_sync_health_connect_test';

  setUpAll(() {
    Hive.init('.');
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(UserDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(UserGenderDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(UserWeightGoalDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(UserPALDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(19)) {
      Hive.registerAdapter(WeightEntryDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(20)) {
      Hive.registerAdapter(WeightEntrySourceDBOAdapter());
    }
  });

  tearDown(() async {
    if (Hive.isBoxOpen(userBoxName)) {
      await Hive.box<UserDBO>(userBoxName).close();
    }
    if (Hive.isBoxOpen(weightBoxName)) {
      await Hive.box<WeightEntryDBO>(weightBoxName).close();
    }
    await Hive.deleteBoxFromDisk(userBoxName);
    await Hive.deleteBoxFromDisk(weightBoxName);
  });

  test('silent sync does not prompt when permissions are missing', () async {
    final userRepository = await _createUserRepository(userBoxName);
    final weightRepository = await _createWeightRepository(weightBoxName);
    final service = _FakeHealthConnectWeightService(
      initialStatus: const HealthConnectStatus(
        available: true,
        updateRequired: false,
        permissionsGranted: false,
        historyPermissionGranted: false,
      ),
    );

    final usecase = SyncHealthConnectWeightsUsecase(
      service,
      weightRepository,
      userRepository,
    );

    final result = await usecase.sync();

    expect(result.outcome, HealthConnectSyncOutcome.permissionsRequired);
    expect(service.requestPermissionsCalls, 0);
    expect(service.readWeightsCalls, 0);
    expect(await weightRepository.getAllEntries(), isEmpty);
  });

  test('sync imports new weights and preserves manual entries', () async {
    final userRepository = await _createUserRepository(userBoxName);
    final weightRepository = await _createWeightRepository(weightBoxName);

    await userRepository.updateUserData(_buildUser(weightKg: 82));
    await weightRepository.addEntry(
      WeightEntryEntity(
        day: DateTime.utc(2026, 4, 4, 8),
        weightKg: 81,
        note: 'old-source',
        source: WeightEntrySource.healthConnect,
      ),
    );
    await weightRepository.addEntry(
      WeightEntryEntity(
        day: DateTime.utc(2026, 4, 5, 8),
        weightKg: 80,
        source: WeightEntrySource.manual,
      ),
    );

    final service = _FakeHealthConnectWeightService(
      initialStatus: const HealthConnectStatus(
        available: true,
        updateRequired: false,
        permissionsGranted: true,
        historyPermissionGranted: true,
      ),
      samples: [
        HealthConnectWeightSample(
          time: DateTime.utc(2026, 4, 4, 7),
          weightKg: 81.4,
          sourcePackageName: 'com.withings.app',
        ),
        HealthConnectWeightSample(
          time: DateTime.utc(2026, 4, 5, 7),
          weightKg: 79.9,
          sourcePackageName: 'com.withings.app',
        ),
        HealthConnectWeightSample(
          time: DateTime.utc(2026, 4, 6, 7),
          weightKg: 79.6,
          sourcePackageName: 'com.withings.app',
        ),
      ],
    );

    final usecase = SyncHealthConnectWeightsUsecase(
      service,
      weightRepository,
      userRepository,
    );

    final result = await usecase.sync();
    final entries = await weightRepository.getAllEntries();
    final user = await userRepository.getUserData();

    expect(result.outcome, HealthConnectSyncOutcome.synced);
    expect(result.importedCount, 2);
    expect(result.skippedCount, 1);
    expect(entries, hasLength(3));

    expect(entries[0].day, DateTime.utc(2026, 4, 4, 7));
    expect(entries[0].weightKg, 81.4);
    expect(entries[0].source, WeightEntrySource.healthConnect);
    expect(entries[0].note, 'com.withings.app');

    expect(entries[1].day, DateTime.utc(2026, 4, 5, 8));
    expect(entries[1].weightKg, 80);
    expect(entries[1].source, WeightEntrySource.manual);

    expect(entries[2].day, DateTime.utc(2026, 4, 6, 7));
    expect(entries[2].weightKg, 79.6);
    expect(entries[2].source, WeightEntrySource.healthConnect);
    expect(user.weightKG, 79.6);
  });
}

Future<UserRepository> _createUserRepository(String boxName) async {
  final box = await Hive.openBox<UserDBO>(boxName);
  return UserRepository(UserDataSource(box));
}

Future<WeightEntryRepository> _createWeightRepository(String boxName) async {
  final box = await Hive.openBox<WeightEntryDBO>(boxName);
  return WeightEntryRepository(WeightEntryDataSource(box));
}

UserEntity _buildUser({required double weightKg}) {
  return UserEntity(
    birthday: DateTime(1995, 1, 1),
    heightCM: 180,
    weightKG: weightKg,
    gender: UserGenderEntity.male,
    goal: UserWeightGoalEntity.maintainWeight,
    pal: UserPALEntity.active,
  );
}

class _FakeHealthConnectWeightService extends HealthConnectWeightService {
  final HealthConnectStatus initialStatus;
  final List<HealthConnectWeightSample> samples;
  int requestPermissionsCalls = 0;
  int readWeightsCalls = 0;

  _FakeHealthConnectWeightService({
    required this.initialStatus,
    this.samples = const [],
  });

  @override
  Future<HealthConnectStatus> getStatus() async => initialStatus;

  @override
  Future<HealthConnectStatus> requestPermissions() async {
    requestPermissionsCalls++;
    return initialStatus;
  }

  @override
  Future<List<HealthConnectWeightSample>> readWeights(
      {int daysBack = 3650}) async {
    readWeightsCalls++;
    return samples;
  }
}
