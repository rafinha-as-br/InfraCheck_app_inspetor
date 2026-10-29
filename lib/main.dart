import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import 'app.dart';
import 'core/app_services.dart';
import 'core/config.dart';
import 'data/inspection_repository.dart';
import 'data/local_store.dart';
import 'data/location_service.dart';
import 'data/session_controller.dart';
import 'data/sync_service.dart';

/// Ponto de entrada do app do inspetor InfraCheck.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalStore.open();
  final api = InfraCheckApi(baseUrl: AppConfig.apiBaseUrl);
  final session = SessionController(api: api, store: store);
  final repository = InspectionRepository(api: api, store: store, blobs: PhotoBlobStore(), location: LocationService());
  final sync = SyncService(repository)..startAutoSync();
  runApp(InspectorApp(services: AppServices(session: session, repository: repository, sync: sync)));
}
