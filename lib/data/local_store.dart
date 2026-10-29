import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_execution.dart';

/// Armazenamento local do app: tudo o que precisa sobreviver sem conexão.
///
/// - Execuções (respostas, metadados de fotos, assinatura) e caches de consulta: `shared_preferences`.
/// - Bytes das fotos: arquivos no diretório privado do app (mobile). Na web (apenas pré-visualização de
///   desenvolvimento) ficam em memória.
///
/// Fotos, coordenadas e assinaturas são dados sensíveis (LGPD): ficam no armazenamento privado do app e
/// as fotos são apagadas depois que o servidor confirma o recebimento.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalStore> open() async => LocalStore(await SharedPreferences.getInstance());

  static const _executionPrefix = 'ic.exec.';
  static const _detailPrefix = 'ic.detail.';
  static const _listKey = 'ic.list';
  static const _tokenKey = 'ic.token';
  static const _userKey = 'ic.user';

  // ---- sessão

  String? get token => _prefs.getString(_tokenKey);
  Map<String, dynamic>? get user {
    final raw = _prefs.getString(_userKey);
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveSession(String token, Map<String, dynamic> user) async {
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_userKey, jsonEncode(user));
  }

  /// Remove só a sessão. Execuções pendentes permanecem para serem enviadas depois do próximo login.
  Future<void> clearSession() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userKey);
  }

  // ---- execuções

  List<LocalExecution> allExecutions() => [
        for (final k in _prefs.getKeys().where((k) => k.startsWith(_executionPrefix)))
          LocalExecution.fromJson(jsonDecode(_prefs.getString(k)!) as Map<String, dynamic>)
      ];

  Future<void> saveExecution(LocalExecution e) =>
      _prefs.setString('$_executionPrefix${e.inspectionId}', jsonEncode(e.toJson()));

  Future<void> deleteExecution(String inspectionId) => _prefs.remove('$_executionPrefix$inspectionId');

  // ---- caches de consulta (JSON bruto da API)

  List<Map<String, dynamic>> get cachedList {
    final raw = _prefs.getString(_listKey);
    return raw == null ? const [] : [for (final e in jsonDecode(raw) as List) e as Map<String, dynamic>];
  }

  Future<void> saveList(List<dynamic> content) => _prefs.setString(_listKey, jsonEncode(content));

  Map<String, dynamic>? cachedDetail(String id) {
    final raw = _prefs.getString('$_detailPrefix$id');
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveDetail(String id, Map<String, dynamic> json) => _prefs.setString('$_detailPrefix$id', jsonEncode(json));
}

/// Bytes das fotos tiradas em campo, separados dos metadados.
class PhotoBlobStore {
  /// [inMemory] mantém os bytes só na memória: usado na web (pré-visualização de desenvolvimento) e em testes.
  PhotoBlobStore({this.inMemory = kIsWeb});

  final bool inMemory;
  final Map<String, Uint8List> _memory = {};

  Future<File> _file(String id) async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/photos');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/$id.jpg');
  }

  Future<void> save(String id, Uint8List bytes) async {
    if (inMemory) {
      _memory[id] = bytes;
      return;
    }
    await (await _file(id)).writeAsBytes(bytes, flush: true);
  }

  Future<Uint8List?> read(String id) async {
    if (inMemory) return _memory[id];
    final f = await _file(id);
    return await f.exists() ? f.readAsBytes() : null;
  }

  Future<void> delete(String id) async {
    if (inMemory) {
      _memory.remove(id);
      return;
    }
    final f = await _file(id);
    if (await f.exists()) await f.delete();
  }
}
