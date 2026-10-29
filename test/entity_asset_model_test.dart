import 'package:eme_app_sdk/eme_app_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('EntityAssetModel.fromJson reads the assets.json fields', () {
    final asset = EntityAssetModel.fromJson({
      'id': 'ea_1',
      'name': 'Deed',
      'description': '',
      'date': '2026-09-11T10:00:00+00:00',
      'sourcetype': 'document',
      'imageurl': '/img.jpg',
      'emeprofile': 'u1',
      'collectionid': '',
    });
    expect(asset.id, 'ea_1');
    expect(asset.name, 'Deed');
    expect(asset.description, '');
    expect(asset.date, isNotNull);
    expect(asset.sourceType, 'document');
    expect(asset.imageUrl, '/img.jpg');
    expect(asset.emeProfileId, 'u1');
    expect(asset.collectionId, isNull);
  });
}
