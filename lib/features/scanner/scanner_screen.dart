import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:opennutritracker/core/data/data_source/local_food_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/error_dialog.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/ai/ai_provider.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/features/scanner/presentation/scanner_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final log = Logger('ScannerScreen');

  String? _scannedBarcode;
  late IntakeTypeEntity _intakeTypeEntity;
  late DateTime _day;

  late ScannerBloc _scannerBloc;

  @override
  void initState() {
    _scannerBloc = locator<ScannerBloc>();
    super.initState();
  }

  @override
  void didChangeDependencies() {
    final args =
        ModalRoute.of(context)?.settings.arguments as ScannerScreenArguments;
    _intakeTypeEntity = args.intakeTypeEntity;
    _day = args.day;
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScannerBloc, ScannerState>(
      bloc: _scannerBloc,
      builder: (context, state) {
        if (state is ScannerInitial) {
          return _getScannerContent(context);
        } else if (state is ScannerLoadingState) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()));
        } else if (state is ScannerLoadedState) {
          // Push new route after build
          Future.microtask(() {
            if (context.mounted) {
              return Navigator.of(context).pushReplacementNamed(
                  NavigationOptions.mealDetailRoute,
                  arguments: MealDetailScreenArguments(state.product,
                      _intakeTypeEntity, _day, state.usesImperialUnits));
            }
          });
        } else if (state is ScannerFailedState) {
          if (state.type == ScannerFailedStateType.productNotFound) {
            return _getProductNotFoundContent(context);
          }
          return Scaffold(
              appBar: AppBar(),
              body: Center(
                child: ErrorDialog(
                  errorText: S.of(context).errorFetchingProductData,
                  onRefreshPressed: _onRefreshButtonPressed,
                ),
              ));
        }
        return const SizedBox();
      },
    );
  }

  Scaffold _getScannerContent(BuildContext context) {
    final cameraController = MobileScannerController();
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).scanProductLabel),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off || TorchState.unavailable:
                    return const Icon(Icons.flash_off_outlined,
                        color: Colors.grey);
                  case TorchState.on || TorchState.auto:
                    return const Icon(Icons.flash_on_outlined);
                }
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android_outlined),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: MobileScanner(
          controller: cameraController,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null &&
                  barcode.type == BarcodeType.product) {
                final barcodeResult = barcode.rawValue;
                if (barcodeResult != null) {
                  _scannedBarcode = barcodeResult;
                  log.fine('Barcode found: $barcodeResult');
                  _scannerBloc
                      .add(ScannerLoadProductEvent(barcode: barcodeResult));
                }
              }
            }
          }),
    );
  }

  bool _isExtractingLabel = false;
  String? _labelError;

  Scaffold _getProductNotFoundContent(BuildContext context) {
    if (_isExtractingLabel) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Reading nutrition label...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(S.of(context).errorProductNotFound,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              if (_labelError != null) ...[
                Text(_labelError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
              ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _extractFromLabel(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Photograph the label'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _extractFromLabel(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Pick label from gallery'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _onRefreshButtonPressed,
                  child: Text(S.of(context).retryLabel),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _extractFromLabel(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _isExtractingLabel = true;
      _labelError = null;
    });

    try {
      final imageBytes = await picked.readAsBytes();
      final mimeType = picked.mimeType ?? 'image/jpeg';
      final aiProvider = locator<AiProvider>();

      final response = await aiProvider.extractFromLabel(imageBytes, mimeType);

      if (!mounted) return;

      if (response.needsClarification) {
        setState(() {
          _labelError = response.clarification!.question;
          _isExtractingLabel = false;
        });
        return;
      }

      if (response.items.isEmpty) {
        setState(() {
          _labelError = 'Could not read the label. Try again with a clearer photo.';
          _isExtractingLabel = false;
        });
        return;
      }

      final item = response.items.first;
      final nutriments = MealNutrimentsEntity(
        energyKcal100: item.per100g.energyKcal,
        carbohydrates100: item.per100g.carbohydratesG,
        fat100: item.per100g.fatG,
        proteins100: item.per100g.proteinG,
        sugars100: item.per100g.sugarsG,
        saturatedFat100: item.per100g.saturatedFatG,
        fiber100: item.per100g.fiberG,
        sodiumMg100: item.per100g.sodiumMg,
      );

      final meal = MealEntity(
        code: _scannedBarcode,
        name: item.name,
        brands: null,
        url: null,
        thumbnailImageUrl: null,
        mainImageUrl: null,
        mealQuantity: null,
        mealUnit: 'g',
        servingQuantity: item.estimatedWeightG,
        servingUnit: 'g',
        servingSize: '${item.estimatedWeightG.toInt()}g',
        nutriments: nutriments,
        source: MealSourceEntity.ai,
      );

      // Save to local overrides so next scan of this barcode works
      if (_scannedBarcode != null) {
        final localFoodDataSource = locator<LocalFoodDataSource>();
        await localFoodDataSource.saveFood(
            _scannedBarcode!, MealDBO.fromMealEntity(meal));
      }

      if (mounted) {
        Navigator.of(context).pushReplacementNamed(
          NavigationOptions.mealDetailRoute,
          arguments: MealDetailScreenArguments(
              meal, _intakeTypeEntity, _day, false),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _labelError = 'Error: $e';
          _isExtractingLabel = false;
        });
      }
    }
  }

  void _onRefreshButtonPressed() {
    final barcode = _scannedBarcode;
    if (barcode != null) {
      _scannerBloc.add(ScannerLoadProductEvent(barcode: barcode));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).errorFetchingProductData)));
    }
  }
}

class ScannerScreenArguments {
  final DateTime day;
  final IntakeTypeEntity intakeTypeEntity;

  ScannerScreenArguments(this.day, this.intakeTypeEntity);
}
