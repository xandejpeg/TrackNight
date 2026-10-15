# Ranking TrackNight

A aba `/ranking` reúne duas classificações diferentes:

- **Ranking da conta:** Bronze, Prata, Ouro e Diamante, calculado separadamente para ACF e AC.
- **Classificação geral:** lista numerada de todos os pilotos encontrados nas provas das duas contas, sem atribuir uma faixa a terceiros.

## Classificação geral

A classificação soma os pontos de chegada de todas as provas confirmadas das duas contas:

- P1: 10 pontos
- P2: 7 pontos
- P3: 6 pontos
- P4–P5: 5 pontos
- P6–P10: 2 pontos
- P11–P20: 1 ponto
- P21 em diante: 0 pontos

Os desempates são, nesta ordem: vitórias, pódios, melhor média de posição, número de corridas, melhor posição e nome. A melhor volta é apenas informativa e nunca altera a ordem.

Nomes sem cadastro próprio são agrupados sem considerar acentos, caixa, pontuação ou espaços repetidos. As contas ACF e AC são reunidas como Alessandro somente na classificação geral.

## Markdown completo

O botão **Exportar Markdown** gera a lista atual diretamente do banco. No servidor, o mesmo arquivo pode ser gravado em `docs/ranking_geral.md` com:

```powershell
bundle exec rails ranking:export_markdown
```

## Emblemas visuais

Os emblemas de Bronze, Prata, Ouro e Diamante usam o pacote **Ranks Coins and More**, criado por Sinestesia e publicado sob licença CC0 no OpenGameArt:

<https://opengameart.org/content/ranks-coins-and-more>

As imagens foram redimensionadas e convertidas para WebP. A progressão visual do pacote foi mapeada como base (`I`), intermediária (`II`) e elite (`III`).