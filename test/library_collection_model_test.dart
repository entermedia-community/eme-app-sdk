import 'package:eme_app_sdk/eme_app_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LibraryCollectionModel Tests', () {
    test('fromJson parses the hit.json fields used by the project page', () {
      final json = {
        'id': 'col_123',
        'name': 'Design Systems Collection',
        'urlname': 'design-systems',
        'collectivedescription': 'A collection of UI design tokens',
        'collectiontype': '5',
        'priviacylevel': 'community',
        'assetportrait': 'asset_1',
        'collectivebanner': 'asset_2',
        'logo': 'http://example.com/logo.jpg',
        'contactemail': 'alice@example.com',
        'donatedescription': 'Be a part of this',
        'proposaltestimonials': '<p>Great</p>',
        'websitelink': 'https://example.com',
        'facebooklink': '',
        // Fields the project page never shows are ignored.
        'manifesto': 'Build beautiful apps',
        'totalsessionsused': 10,
        'team': [
          {
            'userid': 'u1',
            'screenname': 'alice',
            'firstName': 'Alice',
            'lastName': 'Smith',
            'email': 'alice@example.com',
            'portrait': 'http://example.com/alice.jpg',
            'teamroles': ['lead'],
            'teamrolenames': ['Team Lead'],
          },
          {'userid': 'u2', 'screenname': 'bob', 'teamroles': 'dev|ops'},
        ],
      };

      final model = LibraryCollectionModel.fromJson(json);

      expect(model.id, 'col_123');
      expect(model.name, 'Design Systems Collection');
      expect(model.urlName, 'design-systems');
      expect(model.displayDescription, 'A collection of UI design tokens');
      expect(model.isProposal, true);
      expect(model.acceptsDonations, true);
      expect(model.isCommercial, false);
      expect(model.primaryImageUrl, 'http://example.com/logo.jpg');
      expect(model.assetPortrait, 'asset_1');
      expect(model.contactEmail, 'alice@example.com');
      expect(model.donateDescription, 'Be a part of this');
      expect(model.proposalTestimonials, '<p>Great</p>');
      expect(model.facebookLink, isNull);
      expect(model.hasSocialLinks, true);
      expect(model.team, hasLength(2));
      expect(model.team[0].displayName, 'Alice Smith');
      expect(model.team[0].teamRoles, ['lead']);
      expect(model.team[1].displayName, 'bob');
      expect(model.team[1].teamRoles, ['dev', 'ops']);
      expect(model.team[0].roleLabels, ['Team Lead']);
      expect(model.team[1].roleLabels, ['dev', 'ops']);

      final serialized = model.toJson();
      expect(serialized.containsKey('manifesto'), false);
      expect(LibraryCollectionModel.fromJson(serialized).team, hasLength(2));
    });

    test(
      'falls back to urlname; description comes from collectivedescription',
      () {
        final model = LibraryCollectionModel.fromJson({
          'id': 'c1',
          'urlname': 'clean-water',
          // The server's `description` is a search-keyword string.
          'description': 'test@example.com|c1|clean|water|',
          'collectivedescription': 'Water for all',
        });

        expect(model.name, 'clean-water');
        expect(model.displayDescription, 'Water for all');
        expect(model.primaryImageUrl, isNull);
        expect(model.team, isEmpty);
      },
    );

    test('parses followers and team membership', () {
      final model = LibraryCollectionModel.fromJson({
        'id': 'c1',
        'name': 'P',
        'followercount': 3,
        'followedbyuser': true,
        'team': [
          {'userid': 'u1'},
        ],
      });

      expect(model.followerCount, 3);
      expect(model.followedByUser, true);
      expect(model.isOnTeam('u1'), true);
      expect(model.isOnTeam('u2'), false);

      final unfollowed = model.copyWithFollow(
        const ProjectFollowState(following: false, followerCount: 2),
      );
      expect(unfollowed.followerCount, 2);
      expect(unfollowed.followedByUser, false);
      expect(unfollowed.team, hasLength(1));
    });

    test('webUrl resolves the project link', () {
      const absolute = LibraryCollectionModel(
        id: 'c1',
        name: 'P',
        projectLink: 'https://emedialibrary.org/eMediaLibrary-Project',
      );
      expect(
        absolute.webUrl('https://eme.world', 'donate/index.html'),
        'https://emedialibrary.org/eMediaLibrary-Project/donate/index.html',
      );

      final relative = LibraryCollectionModel.fromJson({
        'id': 'c2',
        'urlname': 'water',
        'projectlink': '/water',
      });
      expect(relative.webUrl('https://eme.world/'), 'https://eme.world/water');

      const noLink = LibraryCollectionModel(id: 'c3', name: 'P');
      expect(noLink.webUrl('https://eme.world'), isNull);
    });

    test('anonymous hit has no follow state', () {
      final model = LibraryCollectionModel.fromJson({'id': 'c1'});
      expect(model.followerCount, 0);
      expect(model.followedByUser, isNull);
    });
  });

  group('Project chat and follow responses', () {
    test('ProjectChatConnection parses connectchat.json', () {
      final connection = ProjectChatConnection.fromJson({
        'response': {'status': 'ok'},
        'collectionid': 'c1',
        'topic': 't1',
        'channel': 'ch9',
        'caneditcollection': true,
        'canviewsettings': true,
      });
      expect(connection.canViewSettings, true);
      expect(connection.channelId, 'ch9');
      expect(connection.topicId, 't1');
      expect(connection.canEditCollection, true);

      final missing = ProjectChatConnection.fromJson({
        'response': {'status': 'not found'},
        'channel': '',
        'topic': '',
        'caneditcollection': false,
      });
      expect(missing.channelId, isEmpty);
      expect(missing.topicId, isNull);
      expect(missing.canEditCollection, false);
    });

    test('ProjectFollowState parses togglefollow.json', () {
      final state = ProjectFollowState.fromJson({
        'response': {'status': 'ok'},
        'following': true,
        'followercount': 5,
      });
      expect(state.following, true);
      expect(state.followerCount, 5);
    });
  });

  test('parses the real data/{id} response from a local server', () {
    // Trimmed from GET /services/module/librarycollection/data/{id}
    // on eme-server-world (hit.json with team, projectlink, followers).
    final hit = {
      'description':
          'test@example.com|AaFhKsedAV4z-zI1EuWq|Claude Test Project|',
      'collectiontype': {'id': '1', 'name': 'User Defined'},
      'contactemail': 'test@example.com',
      'id': 'AaFhKsedAV4z-zI1EuWq',
      'name': {'en': 'Claude Test Project'},
      'priviacylevel': {'id': 'community', 'name': 'Community'},
      'proposaltestimonials': '<p><b>Great</b> project</p>',
      'urlname': 'claude-test-project',
      'websitelink': 'https://example.com',
      'team': [
        {
          'collectionid': {'id': 'AaFhKsedAV4z-zI1EuWq', 'name': 'P'},
          'ontheteam': 'true',
          'id': 'AaFhKsjjAV4z-zI1EuWr',
          'followeruser': {'id': 'admin', 'name': 'The.A'},
          'teamroles': [
            {'id': 'r1', 'name': 'Lead'},
          ],
          'userid': 'admin',
          'screenname': 'Admin',
          'firstName': 'The',
          'lastName': 'Administrator',
        },
      ],
      'projectlink': '/claude-test-project',
      'followercount': 0,
      'followedbyuser': false,
    };

    final model = LibraryCollectionModel.fromJson(hit);
    expect(model.name, 'Claude Test Project');
    expect(model.collectionType, '1');
    expect(model.privacyLevel, 'community');
    expect(model.acceptsDonations, true);
    expect(model.displayDescription, isEmpty);
    expect(model.team.single.userId, 'admin');
    expect(model.team.single.memberId, 'AaFhKsjjAV4z-zI1EuWr');
    expect(model.team.single.displayName, 'The Administrator');
    expect(model.team.single.teamRoles, ['r1']);
    expect(model.isOnTeam('admin'), true);
    expect(model.followedByUser, false);
    expect(
      model.webUrl('http://localhost:8080', 'donate/index.html'),
      'http://localhost:8080/claude-test-project/donate/index.html',
    );
  });

  test('chat socket URL is derived from an http(s) server address', () {
    expect(
      ChatSocketService.chatSocketUrlFor(
        Uri.parse('http://localhost:8080/site/mediadb'),
      ),
      'ws://localhost:8080/entermedia/services/websocket/org/entermediadb/websocket/chat/ChatConnection',
    );
    expect(
      ChatSocketService.chatSocketUrlFor(
        Uri.parse('https://eme.world/site/mediadb'),
      ),
      'wss://eme.world/entermedia/services/websocket/org/entermediadb/websocket/chat/ChatConnection',
    );
  });
}
