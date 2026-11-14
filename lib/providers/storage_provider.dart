import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});
