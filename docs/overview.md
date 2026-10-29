# Visão geral do InfraCheck_app_inspetor

## Responsabilidade

Executar a vistoria no celular sem depender de rede: responder o checklist, fotografar, registrar GPS e assinatura e
enviar ao servidor quando houver conexão. Não aprova inspeções nem gera relatório.

## Estrutura

| Caminho | Conteúdo | Estado |
| --- | --- | --- |
| `lib/main.dart`, `lib/app.dart` | Boot, tema, porta de entrada por sessão, sincronização ao voltar ao app | Implementado |
| `lib/core/` | `config.dart` (`API_BASE_URL`, `FAKE_GPS` dev), `app_services.dart` (`AppServices`/`AppScope`), `ids.dart` (UUID v4) | Implementado |
| `lib/data/local_execution.dart` | `LocalExecution`, `LocalPhoto`, `SyncState` (modelo gravado no aparelho) | Implementado |
| `lib/data/local_store.dart` | `LocalStore` (shared_preferences: sessão, execuções, caches JSON) e `PhotoBlobStore` (bytes das fotos em arquivo) | Implementado |
| `lib/data/inspection_repository.dart` | Fonte única: cache do servidor + execuções locais; `beginExecution`, `addPhoto`, `closeExecution`, `completeSync` | Implementado |
| `lib/data/sync_service.dart` | Fila de envio (fotos → pacote final), tratamento offline/recusa/401 | Implementado |
| `lib/data/execution_summary.dart` | Regras de pronto-para-enviar (lógica pura) | Implementado |
| `lib/data/location_service.dart`, `session_controller.dart` | GPS (geolocator) e sessão | Implementado |
| `lib/presentation/` | `login`, `home` (abas), `inspections`, `details`, `execution`, `review`, `sync`, `profile` | Implementado |
| Notificações push (nova OS, prazo próximo) | Previsto no escopo | **Não implementado** |
| "Ver rota no mapa" (M03) | No design | **Não implementado** |
| Build/execução em aparelho Android/iOS | — | **Não verificado** |

## Offline-first

- Ao atualizar a lista online, baixa também o checklist das OS abertas (`pending`, `in_progress`, `rejected`).
- Cada resposta/foto é gravada imediatamente (`LocalExecution` em `shared_preferences`; fotos em arquivo).
- Encerrar = `SyncState.pending`. O `SyncService` envia as fotos (UUID do aparelho → idempotente) e depois o `submit`.
  Só após a confirmação do servidor a cópia local e as fotos são apagadas.
- Recusa do servidor (`422`) vira `SyncState.failed` com o motivo; o inspetor corrige e reenvia.
- Sair da conta é bloqueado enquanto houver inspeções sem enviar.
- Inspeção **rejeitada** pelo gestor: o app reaproveita o início original e as respostas/fotos já enviadas; o inspetor
  altera o necessário, assina de novo e reenvia.

## Limitações conhecidas do protótipo

- Troca de usuário no mesmo aparelho com envios pendentes não é tratada (os dados locais são por id de inspeção).
- Fontes vêm do `google_fonts` (cache após o primeiro uso online).
- Detecção de conectividade pela falha das chamadas (sem plugin de conectividade).
- Token expirado volta ao login mantendo os dados locais; não há refresh token.
