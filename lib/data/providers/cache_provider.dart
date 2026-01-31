import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/offline_cache_service.dart';

/// Offline Cache Service Provider
final offlineCacheServiceProvider = Provider<OfflineCacheService>((ref) {
  return OfflineCacheService();
});

/// Initialization provider - call this on app startup
final cacheInitializationProvider = FutureProvider<void>((ref) async {
  final cacheService = ref.read(offlineCacheServiceProvider);
  await cacheService.initialize();
});
