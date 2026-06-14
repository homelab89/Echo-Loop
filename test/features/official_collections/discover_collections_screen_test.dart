import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/features/official_collections/data/official_catalog_service.dart';
import 'package:echo_loop/features/official_collections/models/catalog.dart';
import 'package:echo_loop/features/official_collections/screens/discover_collections_screen.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';
import 'fixtures/catalog_fixtures.dart';

class _FakeCatalogService extends OfficialCatalogService {
  final CatalogSnapshot snapshot;

  _FakeCatalogService(this.snapshot)
    : super.withDio(dio: Dio(), resolveDir: () async => Directory.systemTemp);

  @override
  CatalogSnapshot get cached => snapshot;

  @override
  bool get hasInitialized => true;
}

void main() {
  testWidgets('发现页顶部展示精选播客入口', (tester) async {
    final snapshot = makeSnapshot(
      collections: [
        makeCatalogCollection(id: 'official-1', name: 'Official Collection'),
      ],
      podcastCatalogs: [
        makeCatalogPodcast(id: 'podcast-1', title: '6 Minute English'),
        makeCatalogPodcast(id: 'podcast-2', title: 'VOA Learning English'),
      ],
    );

    await tester.pumpWidget(
      createTestApp(
        const DiscoverCollectionsScreen(),
        overrides: [
          officialCatalogServiceProvider.overrideWithValue(
            _FakeCatalogService(snapshot),
          ),
          collectionListProvider.overrideWith(() => TestCollectionList()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Curated Podcasts'), findsOneWidget);
    expect(find.textContaining('2 podcasts'), findsOneWidget);
    expect(find.text('Official Collection'), findsOneWidget);

    final entryImage = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage).first,
    );
    expect(entryImage.imageUrl, 'https://i.postimg.cc/tRPzG4zX/podcast.jpg');
  });

  testWidgets('只有精选播客时不显示精选合集空态', (tester) async {
    final snapshot = makeSnapshot(
      collections: const [],
      podcastCatalogs: [makeCatalogPodcast(id: 'podcast-1')],
    );

    await tester.pumpWidget(
      createTestApp(
        const DiscoverCollectionsScreen(),
        overrides: [
          officialCatalogServiceProvider.overrideWithValue(
            _FakeCatalogService(snapshot),
          ),
          collectionListProvider.overrideWith(() => TestCollectionList()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Curated Podcasts'), findsOneWidget);
    expect(find.text('No curated collections yet'), findsNothing);
  });

  testWidgets('未登录点击发现页添加按钮时先显示登录提示', (tester) async {
    final snapshot = makeSnapshot(
      collections: [
        makeCatalogCollection(id: 'official-1', name: 'Official Collection'),
      ],
    );

    await tester.pumpWidget(
      createTestApp(
        const DiscoverCollectionsScreen(),
        overrides: [
          officialCatalogServiceProvider.overrideWithValue(
            _FakeCatalogService(snapshot),
          ),
          collectionListProvider.overrideWith(() => TestCollectionList()),
          isAuthenticatedProvider.overrideWithValue(false),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to add collections'), findsOneWidget);
    expect(
      find.textContaining('Sign in to add curated collections'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
