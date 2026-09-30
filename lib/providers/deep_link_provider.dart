import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/deep_link_service.dart';

/// Provider for DeepLinkService instance
final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService.instance;
});

/// Stream provider for incoming deep links
final deepLinkStreamProvider = StreamProvider<DeepLinkPayload>((ref) {
  final service = ref.watch(deepLinkServiceProvider);
  return service.onDeepLink;
});
