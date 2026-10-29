# InfraCheck App Inspetor — contexto para agentes

## Propósito

Este repositório abriga o aplicativo móvel usado pelos inspetores da InfraCheck para executar inspeções técnicas em campo. O requisito contratado é Flutter, com suporte a Android 8.0+ e iOS 14+.

O app deve substituir o formulário físico sem comprometer a evidência ou a rastreabilidade da vistoria. A fonte de contexto completa está em `../../AGENTS.md` e nos documentos de briefing indicados ali.

## Responsabilidade no fluxo

O inspetor deve conseguir:

- autenticar-se e consultar as inspeções atribuídas;
- visualizar dados da ordem de serviço, local, prazo e checklist aplicável;
- registrar início e encerramento com data, hora e coordenadas GPS;
- responder cada item do checklist como `Conforme`, `Não Conforme` ou `Não Aplicável`, com descrição e observações quando necessário;
- informar criticidade e ação recomendada para não conformidades;
- capturar e vincular fotos ao item correto do checklist;
- registrar observações gerais e assinatura digital no encerramento;
- trabalhar sem conexão, persistindo a coleta localmente e sincronizando-a quando houver rede;
- receber notificações sobre novas inspeções e prazos próximos.

## Prioridades de produto

Checklist + status + foto vinculada são o núcleo da ferramenta. O modo offline é imediatamente posterior em criticidade: a falta de rede não pode bloquear a coleta nem causar perda de dados.

Preserve a associação entre evidência, item inspecionado, momento de captura e localização. Geolocalização de início/fim, timestamp real e assinatura do inspetor são dados de valor probatório e contratual.

## Limites

- Este app executa e envia inspeções; ele não é responsável por aprová-las nem por gerar o PDF final.
- Regras de aprovação, histórico central e armazenamento definitivo pertencem ao servidor; o app deve respeitar os contratos de API definidos com ele.
- Não assuma estruturas de API, modelo local, biblioteca ou padrão de arquitetura que ainda não existam no repositório. O repositório está em estado inicial; documente decisões antes de transformá-las em convenções.
- Trate fotos, coordenadas e assinaturas como dados pessoais/sensíveis sob a LGPD.
