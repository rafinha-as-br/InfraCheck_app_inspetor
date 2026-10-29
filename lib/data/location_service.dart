import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../core/config.dart';

/// Falha ao obter a localização, com mensagem pronta para o inspetor.
class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Acesso ao GPS. A localização de início e de fim da visita é prova contratual e requisito para a aprovação.
class LocationService {
  /// Posição atual com precisão máxima. Lança [LocationException] se o GPS estiver desligado, a permissão
  /// for negada ou não houver sinal em [timeout].
  Future<GeoPoint> current({Duration timeout = const Duration(seconds: 20)}) async {
    final fake = _fakePoint();
    if (fake != null) return fake;
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('A localização do aparelho está desligada. Ative o GPS para registrar a visita.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw const LocationException(
          'Sem permissão de localização. Libere o acesso nas configurações do app para registrar a visita.');
    }
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.best, timeLimit: timeout),
      );
      return GeoPoint(lat: p.latitude, lng: p.longitude, accuracy: p.accuracy);
    } on Exception {
      throw const LocationException('Não foi possível obter a localização. Vá para um local aberto e tente de novo.');
    }
  }

  /// Ponto fixo de [AppConfig.fakeGps] (só fora de release), ou `null` para usar o GPS real.
  GeoPoint? _fakePoint() {
    if (kReleaseMode || AppConfig.fakeGps.isEmpty) return null;
    final parts = AppConfig.fakeGps.split(',');
    return GeoPoint(lat: double.parse(parts[0]), lng: double.parse(parts[1]), accuracy: 6);
  }

  /// Versão tolerante, usada nas fotos: devolve `null` em vez de falhar (a foto vale mesmo sem GPS).
  Future<GeoPoint?> currentOrNull() async {
    try {
      return await current(timeout: const Duration(seconds: 6));
    } on LocationException {
      return null;
    }
  }
}
