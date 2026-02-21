import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:audio_session/audio_session.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'database/app_database.dart';
import 'database/providers.dart';
import 'database/migration/sp_to_drift_migration.dart';
import 'providers/audio_library_provider.dart';
import 'providers/collection_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/collection_screen.dart';
import 'screens/study_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/player_screen.dart';
import 'screens/learning_plan_screen.dart';
import 'models/audio_item.dart' as models;
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final packageInfo = await PackageInfo.fromPlatform();

  // 初始化数据库
  final database = AppDatabase(openConnection());

  // 执行 SP → Drift 迁移
  final prefs = await SharedPreferences.getInstance();
  final migration = SpToDriftMigration(
    database,
    prefs,
    subtitleLoader: defaultSubtitleLoader,
  );
  try {
    await migration.migrate();
  } catch (e) {
    print('SP → Drift 迁移失败，下次启动重试: $e');
  }

  if (!kIsWeb) {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ),
      );
      print('Audio session configured for background playback');
    } catch (e) {
      print('Error configuring audio session: $e');
    }
  } else {
    print('Web platform: skipping audio session configuration');
  }

  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: FluencyApp(packageInfo: packageInfo),
    ),
  );
}

class FluencyApp extends ConsumerWidget {
  final PackageInfo packageInfo;

  const FluencyApp({super.key, required this.packageInfo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp(
      title: 'Fluency',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MainScreen(packageInfo: packageInfo),
      routes: {
        '/settings': (context) => const SettingsScreen(),
        '/player': (context) => const PlayerScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/learning-plan') {
          final audioItem = settings.arguments as models.AudioItem;
          return MaterialPageRoute(
            builder: (context) =>
                LearningPlanScreen(audioItem: audioItem),
          );
        }
        return null;
      },
    );
  }
}

class MainScreen extends ConsumerStatefulWidget {
  final PackageInfo packageInfo;

  const MainScreen({super.key, required this.packageInfo});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioLibraryProvider.notifier).loadLibrary().then((_) {
        ref.read(collectionListProvider.notifier).loadCollections();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 600;

        return Scaffold(
          body: Row(
            children: [
              if (isWideScreen)
                NavigationRail(
                  extended: constraints.maxWidth >= 800,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.collections_bookmark_outlined),
                      selectedIcon: const Icon(
                        Icons.collections_bookmark,
                        color: AppTheme.navActiveColor,
                      ),
                      label: Text(l10n.collections),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.school_outlined),
                      selectedIcon: const Icon(
                        Icons.school,
                        color: AppTheme.navActiveColor,
                      ),
                      label: Text(l10n.study),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.favorite_border),
                      selectedIcon: const Icon(
                        Icons.favorite,
                        color: AppTheme.navActiveColor,
                      ),
                      label: Text(l10n.favorites),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.person_outline),
                      selectedIcon: const Icon(
                        Icons.person,
                        color: AppTheme.navActiveColor,
                      ),
                      label: Text(l10n.profile),
                    ),
                  ],
                ),
              Expanded(child: _getSelectedScreen()),
            ],
          ),
          bottomNavigationBar: isWideScreen
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.collections_bookmark_outlined),
                      selectedIcon: const Icon(
                        Icons.collections_bookmark,
                        color: AppTheme.navActiveColor,
                      ),
                      label: l10n.collections,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.school_outlined),
                      selectedIcon: const Icon(
                        Icons.school,
                        color: AppTheme.navActiveColor,
                      ),
                      label: l10n.study,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.favorite_border),
                      selectedIcon: const Icon(
                        Icons.favorite,
                        color: AppTheme.navActiveColor,
                      ),
                      label: l10n.favorites,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.person_outline),
                      selectedIcon: const Icon(
                        Icons.person,
                        color: AppTheme.navActiveColor,
                      ),
                      label: l10n.profile,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return const CollectionScreen();
      case 1:
        return const StudyScreen();
      case 2:
        return const FavoritesScreen();
      case 3:
        return SettingsScreen(packageInfo: widget.packageInfo);
      default:
        return const CollectionScreen();
    }
  }
}
