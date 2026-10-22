import 'package:eme_app_sdk/eme_app_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LibraryCollectionModel Tests', () {
    test('fromJson parses key fields correctly', () {
      final json = {
        'id': 'col_123',
        'name': 'Design Systems Collection',
        'urlname': 'design-systems',
        'description': 'A collection of UI design tokens',
        'collectivedescription': 'Collective notes',
        'manifesto': 'Build beautiful apps',
        'library': 'lib_global',
        'collectiontype': 'curated',
        'visibility': 'public',
        'projectstatus': 'active',
        'priviacylevel': 'community',
        'keywords': 'design, flutter, theme',
        'collectivetags': ['mobile', 'sdk'],
        'assetportrait': 'http://example.com/portrait.jpg',
        'assetbanner': 'http://example.com/banner.jpg',
        'collectionimage': 'http://example.com/thumb.jpg',
        'contactname': 'Alice Smith',
        'contactemail': 'alice@example.com',
        'featuredcollection': 'true',
        'automatictagging': true,
        'revisions': '4',
        'totalsessionsused': 10,
        'creationdate': '2026-10-22T00:00:00.000Z',
      };

      final model = LibraryCollectionModel.fromJson(json);

      expect(model.id, 'col_123');
      expect(model.name, 'Design Systems Collection');
      expect(model.urlName, 'design-systems');
      expect(model.description, 'A collection of UI design tokens');
      expect(model.displayDescription, 'A collection of UI design tokens');
      expect(model.primaryImageUrl, 'http://example.com/thumb.jpg');
      expect(model.keywords, ['design', 'flutter', 'theme']);
      expect(model.collectiveTags, ['mobile', 'sdk']);
      expect(model.contactName, 'Alice Smith');
      expect(model.contactEmail, 'alice@example.com');
      expect(model.featuredCollection, true);
      expect(model.automaticTagging, true);
      expect(model.revisions, 4);
      expect(model.totalSessionsUsed, 10);
      expect(model.creationDate, DateTime.utc(2026, 10, 22));

      final serialized = model.toJson();
      expect(serialized['id'], 'col_123');
      expect(serialized['name'], 'Design Systems Collection');
      expect(serialized['featuredcollection'], true);
    });

    test('copyWith updates specified fields', () {
      const model = LibraryCollectionModel(
        id: '1',
        name: 'Initial Name',
      );

      final updated = model.copyWith(
        name: 'Updated Name',
        featuredCollection: true,
      );

      expect(updated.id, '1');
      expect(updated.name, 'Updated Name');
      expect(updated.featuredCollection, true);
    });
  });
}
