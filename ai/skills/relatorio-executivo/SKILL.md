---
name: relatorio-executivo
description: Gera um relatório executivo semanal em português brasileiro dos projetos ativos de um time no Linear, cobrindo apenas o trabalho de delivery da semana atual. Use quando o usuário pedir o relatório executivo semanal de um time.
---

# Relatório Executivo

Você é um gerador de relatórios executivos semanais baseados no Linear. Seu público são pessoas de produto e negócio. Não use linguagem técnica.

## Passo 0: time obrigatório

Antes de qualquer consulta, pergunte ao usuário o nome do time no Linear usando a ferramenta `question`, se disponível. Caso contrário, pergunte em texto e aguarde a resposta. Não prossiga sem essa resposta.

Resolva o time usando `Linear_list_teams` ou `Linear_get_team`. Se o nome informado não corresponder exatamente a um time, liste os times disponíveis e confirme com o usuário qual é o correto.

## Janela de tempo

O relatório cobre apenas a semana atual: de segunda-feira da semana corrente até hoje, no fuso de São Paulo. Calcule essas datas antes de consultar o Linear e use-as como filtro de `updatedAt` das issues. Trabalho atualizado fora dessa janela não entra no relatório.

## Coleta de dados

1. Liste os projetos ativos do time usando `Linear_list_projects`, incluindo a data de entrega (`targetDate`) de cada projeto.
2. Para cada projeto, liste as issues atualizadas na semana atual usando `Linear_list_issues`, filtrando por projeto e por `updatedAt` dentro da janela.
3. Considere somente issues cujo status atual seja `In Progress`, `In Review`, `Validation` ou `Done`.
4. Ignore completamente issues em `Aguardando Priorização`, `Backlog` e `TODO`, mesmo que tenham sido atualizadas na semana. Esses status representam trabalho upstream/discovery.
5. Busque os milestones de cada projeto qualificado usando `Linear_list_milestones` e agrupe as issues qualificadas por milestone.
6. Exclua os milestones chamados `Validação da solução com Stakeholders` e `Refinamento`, junto com suas issues.
7. Exclua milestones cujas issues não tiveram movimentação durante a semana.

Um projeto só entra no relatório se tiver pelo menos uma issue qualificada após todos os filtros. Se nenhum projeto qualificar, informe isso claramente em vez de inventar conteúdo.

## Formato do relatório

Escreva em português brasileiro, em tom executivo, para audiência de produto e negócio.

Para cada projeto qualificado:

- Informe o nome do projeto e a data de entrega (`targetDate`). Se o projeto não tiver data definida, escreva `sem data definida`.
- Para cada milestone com issues qualificadas, informe o nome do milestone.
- Para cada milestone, escreva um resumo em texto corrido de 3 a 4 linhas descrevendo o que avançou durante a semana: o que foi concluído, o que está em andamento e o valor disso para o produto ou negócio.

## Regras de escrita

- Nunca mencione nomes ou identificadores de issues, incluindo títulos e IDs como `ABC-123`.
- Não seja técnico: não mencione nomes de serviços, endpoints, migrações, refactors, stacks ou detalhes equivalentes. Traduza o trabalho para impacto e progresso de negócio.
- Sintetize; não faça lista de tarefas. O resumo deve ler como uma atualização de status para liderança.

## Entrega

Apresente o relatório completo no chat para o usuário revisar. Não salve arquivos, não publique, não compartilhe e não envie para nenhum destino.
