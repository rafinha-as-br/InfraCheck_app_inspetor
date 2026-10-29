import 'package:infracheck_modules/infracheck_modules.dart';

/// Situação de envio de uma execução gravada no aparelho.
enum SyncState {
  /// Em preenchimento (ainda não encerrada).
  draft,

  /// Encerrada e assinada; aguardando o envio ao servidor.
  pending,

  /// Recusada pelo servidor (ex.: dado inválido); o inspetor precisa corrigir.
  failed,

  /// Confirmada pelo servidor.
  synced,
}

/// Foto tirada em campo. Os bytes ficam em arquivo/armazenamento à parte (ver `PhotoBlobStore`);
/// aqui ficam os metadados que provam quando e onde foi capturada.
class LocalPhoto {
  const LocalPhoto({required this.id, required this.itemId, required this.capturedAt, this.location, this.uploaded = false});

  /// UUID gerado no aparelho (idempotência do envio).
  final String id;
  final String itemId;
  final DateTime capturedAt;
  final GeoPoint? location;
  final bool uploaded;

  LocalPhoto copyWith({bool? uploaded}) =>
      LocalPhoto(id: id, itemId: itemId, capturedAt: capturedAt, location: location, uploaded: uploaded ?? this.uploaded);

  factory LocalPhoto.fromJson(Map<String, dynamic> j) => LocalPhoto(
        id: j['id'] as String,
        itemId: j['itemId'] as String,
        capturedAt: DateTime.parse(j['capturedAt'] as String),
        location: GeoPoint.fromJsonOrNull(j['location']),
        uploaded: j['uploaded'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemId': itemId,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        if (location != null) 'location': location!.toJson(),
        'uploaded': uploaded,
      };
}

/// Tudo o que o inspetor coletou em uma inspeção, gravado no aparelho a cada alteração
/// (nada se perde sem conexão). Imutável: alterações geram uma nova instância via [copyWith].
class LocalExecution {
  const LocalExecution({
    required this.inspectionId,
    required this.startedAt,
    this.startLocation,
    this.answers = const {},
    this.photos = const [],
    this.generalNotes = '',
    this.signaturePngBase64,
    this.finishedAt,
    this.endLocation,
    this.sync = SyncState.draft,
    this.syncError,
  });

  final String inspectionId;
  final DateTime startedAt;
  final GeoPoint? startLocation;

  /// Respostas por id do item.
  final Map<String, ItemAnswer> answers;
  final List<LocalPhoto> photos;
  final String generalNotes;
  final String? signaturePngBase64;
  final DateTime? finishedAt;
  final GeoPoint? endLocation;
  final SyncState sync;

  /// Motivo da recusa do servidor, quando [sync] é [SyncState.failed].
  final String? syncError;

  bool get isClosed => sync == SyncState.pending || sync == SyncState.failed || sync == SyncState.synced;

  List<LocalPhoto> photosOf(String itemId) => photos.where((p) => p.itemId == itemId).toList();

  LocalExecution copyWith({
    Map<String, ItemAnswer>? answers,
    List<LocalPhoto>? photos,
    String? generalNotes,
    Object? signaturePngBase64 = _keep,
    DateTime? finishedAt,
    GeoPoint? endLocation,
    SyncState? sync,
    Object? syncError = _keep,
  }) =>
      LocalExecution(
        inspectionId: inspectionId,
        startedAt: startedAt,
        startLocation: startLocation,
        answers: answers ?? this.answers,
        photos: photos ?? this.photos,
        generalNotes: generalNotes ?? this.generalNotes,
        signaturePngBase64: identical(signaturePngBase64, _keep) ? this.signaturePngBase64 : signaturePngBase64 as String?,
        finishedAt: finishedAt ?? this.finishedAt,
        endLocation: endLocation ?? this.endLocation,
        sync: sync ?? this.sync,
        syncError: identical(syncError, _keep) ? this.syncError : syncError as String?,
      );

  static const _keep = Object();

  factory LocalExecution.fromJson(Map<String, dynamic> j) => LocalExecution(
        inspectionId: j['inspectionId'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        startLocation: GeoPoint.fromJsonOrNull(j['startLocation']),
        answers: {
          for (final e in (j['answers'] as Map<String, dynamic>).entries)
            e.key: ItemAnswer.fromJson(e.value as Map<String, dynamic>)
        },
        photos: [for (final p in j['photos'] as List) LocalPhoto.fromJson(p as Map<String, dynamic>)],
        generalNotes: j['generalNotes'] as String? ?? '',
        signaturePngBase64: j['signature'] as String?,
        finishedAt: j['finishedAt'] == null ? null : DateTime.parse(j['finishedAt'] as String),
        endLocation: GeoPoint.fromJsonOrNull(j['endLocation']),
        sync: SyncState.values.byName(j['sync'] as String),
        syncError: j['syncError'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'inspectionId': inspectionId,
        'startedAt': startedAt.toUtc().toIso8601String(),
        if (startLocation != null) 'startLocation': startLocation!.toJson(),
        'answers': {for (final e in answers.entries) e.key: e.value.toJson()},
        'photos': [for (final p in photos) p.toJson()],
        'generalNotes': generalNotes,
        if (signaturePngBase64 != null) 'signature': signaturePngBase64,
        if (finishedAt != null) 'finishedAt': finishedAt!.toUtc().toIso8601String(),
        if (endLocation != null) 'endLocation': endLocation!.toJson(),
        'sync': sync.name,
        if (syncError != null) 'syncError': syncError,
      };
}
