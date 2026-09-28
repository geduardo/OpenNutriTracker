import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/features/settings/domain/service/backup_archive_parser.dart';
import 'package:opennutritracker/features/settings/domain/usecase/export_data_usecase.dart';
import 'package:opennutritracker/features/settings/domain/usecase/import_data_usecase.dart';

part 'export_import_event.dart';

part 'export_import_state.dart';

class ExportImportBloc extends Bloc<ExportImportEvent, ExportImportState> {
  static final _log = Logger('ExportImportBloc');

  final ExportDataUsecase _exportDataUsecase;
  final ImportDataUsecase _importDataUsecase;

  ExportImportBloc(this._exportDataUsecase, this._importDataUsecase)
      : super(ExportImportInitial()) {
    on<ExportDataEvent>((event, emit) async {
      try {
        emit(ExportImportLoadingState());

        final timestamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
        final result = await _exportDataUsecase.exportData(
          'opennutritracker-backup-$timestamp.zip',
        );

        if (result) {
          emit(ExportImportSuccess());
        } else {
          emit(ExportImportInitial());
        }
      } catch (e, stackTrace) {
        _log.severe('Export failed', e, stackTrace);
        emit(const ExportImportError());
      }
    });

    on<ImportDataEvent>((event, emit) async {
      try {
        emit(ExportImportLoadingState());

        final result = await _importDataUsecase.importData();
        if (result) {
          emit(ExportImportSuccess());
        } else {
          emit(ExportImportInitial());
        }
      } on InvalidBackupException catch (e, stackTrace) {
        _log.warning('Rejected backup file', e, stackTrace);
        emit(const ExportImportError(invalidBackup: true));
      } catch (e, stackTrace) {
        _log.severe('Import failed', e, stackTrace);
        emit(const ExportImportError());
      }
    });
  }
}
