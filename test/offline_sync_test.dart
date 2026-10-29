import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infracheck_inspetor/data/inspection_repository.dart';
import 'package:infracheck_inspetor/data/local_execution.dart';
import 'package:infracheck_inspetor/data/local_store.dart';
import 'package:infracheck_inspetor/data/location_service.dart';
import 'package:infracheck_inspetor/data/sync_service.dart';
import 'package:infracheck_modules/infracheck_modules.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fixtures.dart';

class _FakeLocation extends LocationService {
  @override
  Future<GeoPoint> current({Duration timeout = const Duration(seconds: 20)}) async =>
      const GeoPoint(lat: -23.5613, lng: -46.6559, accuracy: 6);

  @override
  Future<GeoPoint?> currentOrNull() async => const GeoPoint(lat: -23.5613, lng: -46.6559, accuracy: 6);
}

/// Servidor simulado: pode ser colocado offline; registra as chamadas recebidas.
class _FakeServer {
  bool online = false;
  String? submitFailure; // se definido, o envio final é recusado com 422
  final calls = <String>[];

  Future<http.Response> handle(http.Request r) async {
    if (!online) throw http.ClientException('sem rede');
    calls.add('${r.method} ${r.url.path}');
    if (r.url.path.endsWith('/submit') && submitFailure != null) {
      return http.Response(jsonEncode({'code': 'SUBMISSION_INVALID', 'message': submitFailure, 'details': <String>[]}), 422,
          headers: {'content-type': 'application/json'});
    }
    if (r.url.path.contains('/photos/')) {
      return http.Response(jsonEncode({'id': 'x', 'capturedAt': '2025-06-12T11:30:00Z'}), 200,
          headers: {'content-type': 'application/json'});
    }
    if (r.url.path.endsWith('/submit')) {
      return http.Response(jsonEncode(detailJson(status: 'COMPLETED')), 200, headers: {'content-type': 'application/json'});
    }
    if (r.url.path.endsWith('/inspections')) {
      return http.Response(jsonEncode({'content': <dynamic>[], 'total': 0, 'page': 0, 'size': 200}), 200,
          headers: {'content-type': 'application/json'});
    }
    return http.Response('{}', 404);
  }
}

void main() {
  late _FakeServer server;
  late InspectionRepository repo;
  late SyncService sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    server = _FakeServer();
    final store = await LocalStore.open();
    await store.saveDetail('insp-1', detailJson());
    repo = InspectionRepository(
      api: InfraCheckApi(baseUrl: 'http://x', client: MockClient(server.handle)),
      store: store,
      blobs: PhotoBlobStore(inMemory: true),
      location: _FakeLocation(),
    );
    sync = SyncService(repo);
  });

  /// Inspeção respondida e encerrada no aparelho, com uma foto de não conformidade ainda por enviar.
  Future<LocalExecution> closedExecution() async {
    final d = detail();
    var exec = await repo.beginExecution(d);
    exec = exec.copyWith(answers: {
      'item-1': const ItemAnswer(itemId: 'item-1', result: ItemResult.conforming),
      'item-2': const ItemAnswer(itemId: 'item-2', result: ItemResult.nonConforming, criticality: Criticality.medium, description: 'x'),
    }, signaturePngBase64: base64Encode([0x89, 0x50, 0x4e, 0x47]));
    exec = await repo.addPhoto(exec, 'item-2', Uint8List.fromList([1, 2, 3]));
    return repo.closeExecution(d, exec);
  }

  test('sem conexão nada se perde: a execução fica na fila e o app aponta offline', () async {
    await closedExecution();

    await sync.syncAll();

    expect(repo.unsent, hasLength(1));
    expect(repo.unsent.single.sync, SyncState.pending);
    expect(repo.offline, isTrue);
    expect(await repo.blobs.read(repo.unsent.single.photos.single.id), isNotNull, reason: 'a foto continua no aparelho');
  });

  test('ao voltar a conexão envia a foto e depois o pacote final, e limpa a cópia local', () async {
    final exec = await closedExecution();
    await sync.syncAll(); // offline
    server.online = true;

    await sync.syncAll();

    expect(server.calls.first, startsWith('PUT /api/v1/inspections/insp-1/photos/'));
    expect(server.calls, contains('POST /api/v1/inspections/insp-1/submit'));
    expect(server.calls.indexWhere((c) => c.contains('/photos/')), lessThan(server.calls.indexWhere((c) => c.endsWith('/submit'))));
    expect(repo.unsent, isEmpty);
    expect(repo.executionOf('insp-1'), isNull);
    expect(await repo.blobs.read(exec.photos.single.id), isNull, reason: 'dado sensível apagado após confirmação');
  });

  test('envio recusado pelo servidor vira "failed" com o motivo, sem apagar nada', () async {
    await closedExecution();
    server
      ..online = true
      ..submitFailure = 'Item 02 não conforme sem foto';

    await sync.syncAll();

    final e = repo.executionOf('insp-1')!;
    expect(e.sync, SyncState.failed);
    expect(e.syncError, contains('Item 02'));
    expect(e.photos.single.uploaded, isTrue, reason: 'a foto já enviada não é reenviada');

    await repo.reopen('insp-1');
    expect(repo.executionOf('insp-1')!.sync, SyncState.draft);
  });

  test('a execução em andamento sobrevive a reabrir o app (persistida no aparelho)', () async {
    await closedExecution();
    final reopened = InspectionRepository(api: repo.api, store: repo.store, blobs: repo.blobs, location: _FakeLocation());
    expect(reopened.executionOf('insp-1')!.answers, hasLength(2));
    expect(reopened.executionOf('insp-1')!.photos, hasLength(1));
  });
}
