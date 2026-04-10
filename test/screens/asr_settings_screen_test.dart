import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/providers/offline_asr_settings_provider.dart';
import 'package:fluency/screens/asr_settings_screen.dart';
import 'package:fluency/services/asr/asr_model_manager.dart';
import 'package:fluency/services/asr/offline_asr_engine.dart';
import 'package:fluency/theme/app_theme.dart';

class _StaticOfflineAsrSettingsNotifier extends OfflineAsrSettingsNotifier {
  _StaticOfflineAsrSettingsNotifier(this._initialState);

  final OfflineAsrSettingsState _initialState;

  @override
  OfflineAsrSettingsState build() => _initialState;

  @override
  Future<void> retryDownload() async {}
}

void main() {
  const recommendedModel = AsrModelInfo(
    id: 'whisper-base-en-int8',
    displayName: 'Whisper Base.en',
    type: AsrModelType.whisper,
  );

  testWidgets('残缺模型显示当前本地大小', (tester) async {
    final notifier = _StaticOfflineAsrSettingsNotifier(
      OfflineAsrSettingsState(
        enabled: true,
        backend: AsrBackend.offline,
        downloadStatus: AsrModelDownloadStatus.failed,
        localSizeBytes: 153 * 1024 * 1024,
        recommendedModel: recommendedModel,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [offlineAsrSettingsProvider.overrideWith(() => notifier)],
        child: MaterialApp(
          supportedLocales: const [Locale('en'), Locale('zh')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          home: const AsrSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Accurate'), findsOneWidget);
    expect(find.textContaining('153 MB'), findsOneWidget);
    expect(find.textContaining('Ready'), findsNothing);
  });

  testWidgets('删除模型按钮不显示大小', (tester) async {
    final notifier = _StaticOfflineAsrSettingsNotifier(
      OfflineAsrSettingsState(
        enabled: false,
        localSizeBytes: 153 * 1024 * 1024,
        recommendedModel: recommendedModel,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [offlineAsrSettingsProvider.overrideWith(() => notifier)],
        child: MaterialApp(
          supportedLocales: const [Locale('en'), Locale('zh')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          home: const AsrSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete Model'), findsOneWidget);
    expect(find.textContaining('Delete Model ('), findsNothing);
  });
}
