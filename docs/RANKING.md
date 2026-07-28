# Ranking TrackNight

A aba `/ranking` reúne duas classificações diferentes:

- **Ranking do perfil:** Bronze, Prata, Ouro e Diamante, calculado separadamente para cada perfil de piloto.
- **Classificação geral:** lista numerada de todos os pilotos encontrados nas provas, sem atribuir uma faixa a terceiros.

## Classificação geral

A ordem usa a média da posição relativa de cada piloto no grid:

```text
nota = (1 - (posição - 1) / (tamanho do grid - 1)) × 100
```

Os desempates são, nesta ordem: vitórias, melhor posição, número de encontros, melhor volta e nome. A melhor volta não é o critério principal porque sessões de pistas e traçados diferentes não são diretamente comparáveis.

Nomes sem cadastro próprio são agrupados sem considerar acentos, caixa, pontuação ou espaços repetidos. Todos os perfis de um mesmo piloto são reunidos somente na classificação geral; os ranks de cada perfil continuam separados.

## Markdown completo

O botão **Exportar Markdown** gera a lista atual diretamente do banco. No servidor, o mesmo arquivo pode ser gravado em `docs/ranking_geral.md` com:

```powershell
bundle exec rails ranking:export_markdown
```