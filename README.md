# InfraCheck_app_inspetor

App do inspetor (**Flutter**, Android 8.0+ e iOS 14+) para executar inspeções em campo, **inclusive sem conexão**.

> **Estado: protótipo do MVP**, seguindo os designs M01–M05. Consome o `InfraCheck_Server` e o pacote compartilhado
> `InfraCheck_modules`. Nenhum build de Android/iOS foi gerado ou testado em aparelho neste protótipo — a verificação
> foi feita com testes automatizados e com a versão web como pré-visualização.

## Rodar

```bash
flutter pub get
flutter run                                   # emulador Android: API em http://10.0.2.2:8080
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8080      # aparelho na rede local
flutter run -d chrome --dart-define=FAKE_GPS=-23.5613,-46.6559       # pré-visualização web (GPS simulado)
```

`FAKE_GPS` é **só para desenvolvimento** (ignorado em release). Login: ver `InfraCheck_Server/README.md`
(inspetor de demonstração `marcos.oliveira@infracheck.com.br`). Gestores usam o painel web.

## Fluxo implementado

1. **Login** (precisa de internet na primeira vez; depois o app abre offline).
2. **Minhas inspeções:** Hoje / Próximas / Concluídas, aviso de envio pendente, puxar para atualizar.
3. **Detalhes:** local, prazo, categorias do checklist, observação do gestor. "Iniciar" registra horário e GPS.
4. **Executar:** um item por vez — Conforme / Não conforme / N/A; NC exige criticidade e foto; fotos gravam data, hora e GPS;
   tudo salvo no aparelho a cada toque.
5. **Revisar e enviar:** resumo de conformidade, verificações, observações, **assinatura**; "Encerrar e enviar".
6. **Sincronização:** fila de envio com motivo de recusa; reenvio automático a cada 45 s, ao voltar ao app e sob demanda.

## Testes

```bash
flutter analyze && flutter test
```

`offline_sync_test.dart` simula servidor offline → online (fotos antes do pacote final, limpeza da cópia local,
recusa do servidor, persistência ao reabrir o app). Mais em [docs/](docs/overview.md).
