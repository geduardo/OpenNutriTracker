import 'package:opennutritracker/core/presentation/widgets/app_text.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/pregnancy/pregnancy_controller.dart';
import 'package:opennutritracker/pregnancy/pregnancy_hub.dart';
import 'package:opennutritracker/pregnancy/pregnancy_settings.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/add_item_bottom_sheet.dart';
import 'package:opennutritracker/features/diary/diary_page.dart';
import 'package:opennutritracker/core/presentation/widgets/home_appbar.dart';
import 'package:opennutritracker/features/food_library/food_library_page.dart';
import 'package:opennutritracker/features/home/home_page.dart';
import 'package:opennutritracker/core/presentation/widgets/main_appbar.dart';
import 'package:opennutritracker/generated/l10n.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncWeights());
  }

  void _syncWeights() {
    if (mounted && locator.isRegistered<PregnancyController>()) {
      locator<PregnancyController>().syncHealth();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncWeights();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  int _selectedPageIndex = 0;

  late List<Widget> _bodyPages;
  late List<PreferredSizeWidget> _appbarPages;

  @override
  void didChangeDependencies() {
    _bodyPages = [
      const HomePage(),
      const FoodLibraryPage(),
      const PregnancyHub(embedded: true),
      const DiaryPage(),
      const PregnancySettings(embedded: true),
    ];
    _appbarPages = [
      const HomeAppbar(),
      MainAppbar(
          title: S.of(context).libraryLabel, iconData: Icons.restaurant_menu),
      MainAppbar(title: tr('Pregnancy'), iconData: Icons.favorite_outline),
      MainAppbar(title: S.of(context).diaryLabel, iconData: Icons.book),
      MainAppbar(title: tr('Settings'), iconData: Icons.settings)
    ];
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(
        context); // Rebuild non-Text labels when language changes.

    return Scaffold(
      appBar: _appbarPages[_selectedPageIndex],
      body: _bodyPages[_selectedPageIndex],
      floatingActionButton: _selectedPageIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _onFabPressed(context),
              tooltip: S.of(context).addLabel,
              icon: const Icon(Icons.add),
              label: const AppText('Log food'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedPageIndex,
        onDestinationSelected: _setPage,
        destinations: [
          NavigationDestination(
              icon: _selectedPageIndex == 0
                  ? const Icon(Icons.home)
                  : const Icon(Icons.home_outlined),
              label: S.of(context).homeLabel),
          NavigationDestination(
              icon: _selectedPageIndex == 1
                  ? const Icon(Icons.restaurant_menu)
                  : const Icon(Icons.restaurant_menu_outlined),
              label: S.of(context).libraryLabel),
          NavigationDestination(
              icon: _selectedPageIndex == 2
                  ? const Icon(Icons.favorite_outline)
                  : const Icon(Icons.favorite_border),
              label: tr('Pregnancy')),
          NavigationDestination(
              icon: _selectedPageIndex == 3
                  ? const Icon(Icons.book)
                  : const Icon((Icons.book_outlined)),
              label: S.of(context).diaryLabel),
          NavigationDestination(
              icon: _selectedPageIndex == 4
                  ? const Icon(Icons.settings)
                  : const Icon(Icons.settings_outlined),
              label: tr('Settings'))
        ],
      ),
    );
  }

  void _setPage(int selectedIndex) {
    if (selectedIndex == 2) _syncWeights();
    setState(() {
      _selectedPageIndex = selectedIndex;
    });
  }

  void _onFabPressed(BuildContext context) async {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.0),
                topRight: Radius.circular(16.0))),
        builder: (BuildContext context) {
          return AddItemBottomSheet(day: DateTime.now());
        });
  }
}
