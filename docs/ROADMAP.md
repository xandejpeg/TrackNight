# TrackNight — Roadmap de transformação em produto multiusuário

> **Status:** documento de planejamento. Nada aqui foi implementado ainda.
> **Objetivo do dia (2026-07-27):** app rodando com o nome TrackNight, sem nenhuma referência pessoal ("Xande", "Xande Racing", "Alessandro Chiarelli" hardcoded), conceito de "smurf" removido do produto, e preparado conceitualmente para receber novos usuários.
> **Fora de escopo hoje:** troca de URL/domínio, migração de VPS, deploy novo, landing page funcional. Isso entra como fases planejadas.

---

## 1. Visão do produto

**TrackNight** é uma plataforma de análise de desempenho em pista — **não exclusiva de kart nem de corrida**: serve para qualquer tipo de "track day" / trekking em pista (kart rental, track day de carro, moto, etc.).

- Cada **usuário** tem uma conta (login/senha).
- Cada usuário tem **um ou mais perfis de piloto** (ex.: nomes diferentes que aparecem nas folhas de resultado). **Não existe mais o conceito de "conta smurf"** — são apenas perfis do mesmo piloto, sem hierarquia "principal/segunda conta".
- No lançamento, o **único traçado aceito na análise é o KGV Circuito 101**. Outros venues/traçados entram depois.
- Usuários podem **comparar perfis entre si** (funcionalidade futura, já mapeada).
- Dados vêm de importação de imagens/PDFs de resultados (pipeline OCR existente).

---

## 2. Inventário do que existe hoje (auditado em 2026-07-27)

### 2.1 Referências pessoais a remover

| Onde | O quê | Ação |
|---|---|---|
| `app/views/layouts/application.html.erb:4` | `<title>` = "TrackNight — Xande Racing Performance" | Trocar para "TrackNight" |
| `app/views/layouts/application.html.erb:29` | Logo "X" e subtítulo "Xande Racing" | Novo logo/neutro, subtítulo "Track Performance" ou nada |
| `app/views/sessions/new.html.erb:5` | "Xande Racing Performance" na tela de login | Trocar para tagline neutra |
| `app/views/karts/index.html.erb:8` | Texto "...caíram pro Xande" | Generalizar: "...números que você já pilotou" |
| `app/views/dashboard/show.html.erb:5` | `<h1>Alessandro Chiarelli</h1>` hardcoded | Usar nome do perfil/usuário logado |
| `db/seeds.rb:4-17` | Usuários seed "Xande" e "Helo" + envs `XANDE_INITIAL_PASSWORD`, `HELO_INITIAL_PASSWORD` | Substituir por usuário admin genérico via `ADMIN_USERNAME`/`ADMIN_INITIAL_PASSWORD` |
| `db/seeds.rb:21-44` | Driver "Alessandro Chiarelli", aliases, perfis ACF/AC como seed estrutural | Mover para seed de desenvolvimento/demo; produção nasce vazia |
| `db/seeds.rb:183` | Mensagem final citando nomes | Atualizar |
| `docs/RANKING.md:18` | "As contas ACF e AC são reunidas como Alessandro" | Reescrever genericamente (perfis de um mesmo piloto) |
| `script/validate_parse.rb:12` | "ALESSANDRO NÃO ENCONTRADO" | Generalizar |

### 2.2 Lógica "piloto único" hardcoded (a generalizar)

Hoje todo o app assume que existe **um** piloto especial ("Alessandro") reconhecido por nome:

| Onde | O quê | Impacto |
|---|---|---|
| `app/services/driver_matcher.rb` | Fuzzy-match de "ALESSANDRO"/"CHIAREL" com regex de OCR, retorna `Driver` fixo por slug | Todo import reconhece só o Alessandro |
| `app/models/race_session.rb:71` | `alessandro_entry` — "a entrada do piloto dono do app" na sessão | Dashboard/timeline/gráfico orbitam esse método |
| `app/models/result_entry.rb:13` | `alessandro?` = `driver_id.present?` | Highlight visual na tabela de resultados |
| `app/services/performance_stats.rb` | "Estatísticas de desempenho do Alessandro" | Classe inteira parte do piloto único |
| `app/services/profile_ranking.rb:22` | Usa `alessandro_entry` | Ranking por perfil |
| `app/controllers/race_sessions_controller.rb:9` | `@entry = @session.alessandro_entry` | |
| `app/controllers/timeline_controller.rb:7` | `s.alessandro_entry` | |
| `app/controllers/imports_controller.rb:119` | `edited[:alessandro]` + slug fixo "alessandro-chiarelli" na revisão do import | Revisão manual amarrada a um piloto |
| `app/views/imports/review.html.erb:81,96` | Checkbox "ALE?" e texto "linha vermelha é o Alessandro" | |
| `app/views/race_sessions/show.html.erb:103-108` | `row-ale`, `e.alessandro? ? "Alessandro Chiarelli" : ...` | |
| `app/views/timeline/show.html.erb:22,69` | "Sem linha do Alessandro nesta sessão." | |
| `app/assets/tailwind/application.css:254` | Classe `.row-ale` (highlight vermelho) | Renomear para `.row-me` / `.row-highlight` |
| `app/assets/tailwind/application.css:13` | `--color-race-glow` | OK manter (nome neutro) |

### 2.3 Conceito "smurf" a eliminar

| Onde | O quê | Ação |
|---|---|---|
| `app/models/driver_profile.rb:6` | `enum :kind, { main: 0, smurf: 1 }` | Remover enum (ou manter coluna legada ignorada até migration de limpeza) |
| `app/controllers/profiles_controller.rb:16` | Novo perfil default `kind: :smurf` | Remover |
| `app/views/profiles/new.html.erb:17,26` | Placeholder "AC (smurf)", select "Conta principal / Conta smurf" | Remover select; perfis são todos iguais |
| `app/views/profiles/edit.html.erb:22` | Idem | Idem |
| `app/views/profiles/index.html.erb:27` | Label "Conta principal / Conta smurf" | Remover label |
| `app/views/profiles/show.html.erb:9` | Idem | Idem |
| `app/views/ranking/index.html.erb:19` | Idem | Idem |
| `app/views/layouts/application.html.erb:56` | "Principal / Smurf" no menu de contas | Remover; título "Contas do piloto" → "Meus perfis" |
| `app/assets/tailwind/application.css:14` | `--color-smurf: #00a8e8` | Renomear token para `--color-accent` (mesma cor, nome neutro) e atualizar todas as classes `text-smurf`, `border-smurf/30`, `border-smurf/40` |
| `db/seeds.rb:42-43` | Perfil "AC (smurf)" kind smurf | Remover do seed estrutural |

### 2.4 Multiusuário — o que já existe e o que falta

**Existe:**
- Modelo `User` (username + `has_secure_password`, `must_change_password`) — `app/models/user.rb`
- Login/logout/troca de senha — `sessions_controller.rb`, `passwords_controller.rb`
- `require_login` global — `application_controller.rb:5`

**Falta (crítico — hoje TODOS os dados são globais):**
- `User` **não tem relação com nada**: `Driver`, `DriverProfile`, `RaceSession`, `ResultEntry`, `SourceDocument`, `ImportBatch` são compartilhados por todo mundo.
- Não existe cadastro (signup) — só seed cria usuários.
- Não existe papel admin vs. usuário comum.
- Não existe landing page pública (root vai direto pro dashboard; `require_login` redireciona pro login).

---

## 3. Roadmap por fases

### Fase 0 — Rebrand neutro (HOJE, 2026-07-27) ✅ meta do dia

**Critério de pronto:** `grep -ri "xande\|alessandro\|chiarelli\|smurf\|helo" app/ db/ config/ docs/` retorna zero (exceto histórico em `docs/` devidamente marcado como legado e dados demo explícitos).

1. **Textos e marca** ✅ (2026-07-27)
   - [x] `application.html.erb`: `<title>` "TrackNight", remover "Xande Racing", logo "X" → marca neutra (ex.: "TN" ou ícone 🏁), item de menu "Contas do piloto" → "Meus perfis".
   - [x] `sessions/new.html.erb`: tagline neutra ("Análise de desempenho em pista").
   - [x] `karts/index.html.erb`: remover "pro Xande".
   - [x] `dashboard/show.html.erb`: `<h1>` dinâmico (nome do usuário logado ou "Seu desempenho").
   - [x] Favicon/`public/icon.*` e `application-name` meta: revisar se há marca pessoal. _(sem marca pessoal — `application-name` já era "TrackNight")_

2. **Fim do "smurf"** ✅ (2026-07-27)
   - [x] Remover selects/labels "Conta principal/Conta smurf" das views de perfil, ranking e menu.
   - [x] `profiles_controller.rb`: novo perfil sem `kind`.
   - [x] Renomear token CSS `--color-smurf` → `--color-accent` e todas as classes utilitárias `*-smurf*` (o app usa `text-smurf`, `border-smurf/30`, `border-smurf/40` em pelo menos 8 arquivos de view).
   - [x] **Decisão aplicada:** coluna `kind` mantida no banco, ignorada (enum legado em `driver_profile.rb`); dropar na fase 1 com migration.

3. **Desacoplar o "piloto único" (mínimo viável hoje)** ✅ (2026-07-27)
   - [x] Renomear `alessandro_entry` → `tracked_entry` (mantém comportamento: entrada com `driver_id` preenchido) em `race_session.rb` e todos os callers (controllers, services, views).
   - [x] Renomear `ResultEntry#alessandro?` → `tracked?`.
   - [x] CSS `.row-ale` → `.row-tracked`.
   - [x] `imports/review.html.erb`: checkbox "ALE?" → "Piloto?", texto genérico; `imports_controller.rb` usa `Driver.joins(:driver_profiles).order(:id).first` em vez de slug fixo (versão definitiva por usuário na fase 1).
   - [x] `driver_matcher.rb`: reescrito genérico — match por aliases cadastrados + similaridade (Levenshtein) contra o nome oficial de qualquer driver, sem constantes hardcoded. Versão definitiva por usuário na fase 1.
   - [x] `script/validate_parse.rb`: mensagem genérica ("PILOTO CADASTRADO NÃO ENCONTRADO").

4. **Seeds e docs** ✅ (2026-07-27)
   - [x] `db/seeds.rb`: sem usuários/pilotos pessoais; dados demo fictícios ("Piloto Demo", perfis PD1/PD2) em `db/seeds/demo.rb`, carregados só com `SEED_DEMO=1`.
   - [x] Env vars: `ADMIN_USERNAME` / `ADMIN_INITIAL_PASSWORD` (substituíram `XANDE_*`, `HELO_*`).
   - [x] Atualizar `docs/RANKING.md`, `README.md` com linguagem neutra (README sem domínio pessoal).

5. **Verificação** ✅ (2026-07-27)
   - [ ] `bin/rails db:seed` em banco limpo funciona sem dados pessoais. _(pendente: rodar no deploy)_
   - [ ] App sobe (`bin/dev`), login funciona, telas sem marca pessoal. _(pendente: validação visual no navegador)_
   - [x] Grep final zero em `app/`, `db/`, `config/`, `script/` (exceção intencional: enum legado `kind` em `driver_profile.rb` e histórico em `docs/`).
   - [x] Suíte de testes: 17 runs, 75 assertions, 0 failures.
   - [x] Tailwind rebuild: `--color-accent` e `.row-tracked` no CSS compilado.

> **Não quebra hoje:** dados existentes no banco de produção/dev (perfis ACF/AC, driver Alessandro) continuam funcionando — o rename é cosmético/estrutural, não deleta dados. A limpeza de dados pessoais do banco é decisão à parte (fase 1).

---

### Fase 1 — Multiusuário real (dados por usuário) ✅ **PARCIALMENTE CONCLUÍDA** (2026-07-28)

**Objetivo:** cada usuário vê apenas os próprios dados. Preparação para receber outras pessoas.

1. **Modelagem** ✅
   - [x] Migration: `users` ganha `role` (enum `admin`/`member`, default `member`) e campos `full_name`, `cpf`.
   - [x] `drivers.user_id` (dono), `driver_profiles` acessível via `user.driver_profiles` (through drivers).
   - [x] `race_sessions.user_id`, `source_documents.user_id`, `import_batches.user_id` — tudo escopado ao dono.
   - [x] Backfill: dados existentes atribuídos ao usuário `xandao` (dono histórico).
   - [x] `result_entries` e `karts` herdam escopo via `race_session` (sem coluna própria).

2. **Autorização/escopo** ✅
   - [x] Todos os controllers: queries escopadas a `current_user`.
   - [x] `all_profile_codes` → perfis do `current_user` apenas.
   - [x] `DriverMatcher` por usuário: match contra aliases dos drivers do usuário logado.
   - [x] Revisão de import: checkbox "Piloto?" marca o driver do usuário logado.
   - [x] 404 ao acessar recurso de outro usuário (via `find` escopado).

3. **Limpeza do enum kind** ✅
   - [x] Migration dropando `driver_profiles.kind` (20260728000001).
   - [x] `DriverProfile.order(:kind, :id)` → `order(:id)` em todos os lugares.

4. **Cadastro de usuários** ✅ (decisão: signup aberto, sem convite)
   - [x] **Decisão aplicada:** signup **aberto** com nome completo, usuário, CPF e senha (sem email/celular).
   - [x] `registrations#new/create` público em `/cadastro`.
   - [x] Recuperação de senha **por identidade** (CPF + nome completo), sem email — token de 2h em `/recuperar-senha`.
   - [x] Validação de CPF com dígitos verificadores (`CpfValidator`).

5. **UX pós-multiusuário** ✅
   - [x] Onboarding: `setup_default_driver!` cria driver + perfil + alias automaticamente no signup.
   - [x] Menu "Meus perfis" com link "Adicionar perfil".
   - [x] Painel admin em `/admin` (dashboard + lista de usuários + detalhe por conta).

**Pendente (fase 1 completa):**
   - [ ] Sessões compartilhadas entre usuários (claim de linha de resultado).
   - [ ] Perfil público opcional (`@username`).

---

### Fase 2 — Landing page + porta de entrada ✅ **CONCLUÍDA** (2026-07-28)

1. **Landing pública** ✅
   - [x] `pages#home` público, root condicional (landing para deslogado, dashboard para logado).
   - [x] Conteúdo: hero, como funciona (3 passos), features (4 cards), traçado suportado, CTAs.
   - [x] Layout `landing` separado (header/footer de marketing).
   - [x] Signup aberto (sem "pedir acesso" — decisão: cadastro livre).

2. **Marca** ✅
   - [x] Logo "TN" + wordmark TrackNight.
   - [x] Favicon, meta description, og tags básicas.
   - [x] Paleta: dark/carbon + race red + `--color-accent`.

---

### Fase 3 — Infraestrutura: URL, banco e VPS 🔶 **CÓDIGO PRONTO** (2026-07-28) — passos manuais pendentes

> Hoje: PostgreSQL local/VPS atual, sem domínio próprio definitivo. O `config/database.yml` já lê `TRACKNIGHT_DB_*` — bom ponto de partida.
> **Guia completo:** `docs/DEPLOY.md` · **Env example:** `.env.production.example` · **Script:** `script/deploy.sh`

1. **Domínio**
   - [ ] Registrar domínio (ex.: `tracknight.app` / `tracknight.com.br` — verificar disponibilidade). **(manual)**
   - [ ] DNS apontando para a VPS. **(manual)**
   - [x] `config/environments/production.rb`: `config.hosts` via `ALLOWED_HOSTS`, `default_url_options` via `APP_HOST`.
   - [x] HTTPS via Nginx + Let's Encrypt (`script/deploy.sh` roda certbot automaticamente).
   - [ ] Redirect do endereço antigo (se houver) por 30–90 dias. **(manual, snippet em DEPLOY.md)**

2. **Banco de dados gerenciado ("conta no Neon")**
   - [ ] Criar conta e projeto no **Neon** (Postgres serverless). **(manual)**
   - [ ] Banco de produção no Neon; connection string via `DATABASE_URL`. **(manual — preencher `/etc/tracknight.env`)**
   - [x] **Resolvido:** app usa 4 bancos (primary, cache, queue, cable). `database.yml` aceita `DATABASE_URL` + `CACHE/QUEUE/CABLE_DATABASE_URL` separadas (4 databases no Neon).
   - [ ] Migração: `pg_dump` da VPS → restore no Neon → smoke test → switch do `DATABASE_URL`. **(manual — passo a passo em DEPLOY.md §3)**
   - [ ] Solid Queue/Cache/Cable: confirmar funcionamento apontando pro Neon. **(validar pós-migração)**
   - [ ] Backups automáticos (Neon faz PITR; validar retenção do plano). **(manual)**

3. **VPS**
   - [x] Script de deploy formalizado: `script/deploy.sh` (idempotente: deps, gems, assets, migrate, systemd app+jobs, nginx, health check, certbot).
   - [x] Variáveis de ambiente documentadas: `.env.production.example`.
   - [ ] Storage: Active Storage local (`storage/`) — avaliar S3/R2 quando escalar. **(depois do lançamento)**
   - [ ] Monitoramento: health check `/up` existe; configurar alerta (UptimeRobot). **(manual)**

4. **Email (transacional)**
   - [x] `ApplicationMailer` + layout de email criados.
   - [x] `config.action_mailer` em produção: SMTP 100% via ENV (`SMTP_ADDRESS`, `SMTP_USERNAME`, etc.) + `MAILER_FROM`.
   - [ ] Provedor: criar conta Resend/Postmark/SES e preencher credenciais. **(manual)**
   - [ ] Mailers de uso real (`InvitationMailer`, `PasswordResetMailer` por email) quando houver email no cadastro. **(futuro — hoje recuperação é por identidade CPF+nome)**

---

### Fase 4 — Comparação entre usuários e social (futuro, já prometido)

- [ ] **Comparar perfil com perfil de outro usuário**: hoje `comparison#show` compara perfis do mesmo dono. Estender: seletor de usuário público + perfil.
- [ ] **Perfis públicos**: página pública opcional do piloto (`/@username`) com stats agregados, melhores voltas, ranking.
- [ ] **Ranking global por traçado**: leaderboard do KGV 101 entre todos os usuários (opt-in de privacidade).
- [ ] **Privacidade**: flag `public_profile` em `users`; padrão privado.
- [ ] **Sessões compartilhadas**: usuários que andaram na mesma bateria veem a mesma sessão e podem "reivindicar" sua linha (claim de `result_entry` por nome/transponder) — reduz trabalho de import duplicado.

---

### Fase 5 — OCR inteligente por piloto (melhoria do pipeline de importação)

**Contexto:** hoje o OCR/parser usa um padrão básico de importação e o reconhecimento do "piloto dono" é feito por nome hardcoded (`DriverMatcher` com fuzzy/regex de um nome específico). Depois da fase 1, o matcher passa a ser por usuário — mas ainda depende de aliases cadastrados. Esta fase torna o OCR realmente orientado ao cadastro de cada piloto.

**Objetivo:** o OCR para de "procurar um nome fixo" e passa a procurar, em cada linha de resultado, o **nome oficial completo** cadastrado no perfil do piloto — distinguindo:

- `username` → login da conta (nunca usado no OCR);
- nome de exibição do perfil (`display_name`) → rótulo visual;
- **nome completo oficial** (novo campo) → alvo da busca OCR nas folhas de resultado.

1. **Modelagem**
   - [ ] Migration: `drivers` ganha `full_name` (nome completo oficial, usado no match) — ou `driver_profiles.full_name` se o nome impresso variar por perfil (decidir).
   - [ ] Cadastro/edição de perfil passa a exigir o nome completo como aparece na folha de resultados do kartódromo.
   - [ ] Aliases (`driver_aliases`) viram aprendizado por usuário: cada grafia nova confirmada na revisão vira alias do driver daquele usuário.

2. **Matcher orientado ao cadastro**
   - [ ] `DriverMatcher` deixa de ter constantes/fuzzy hardcoded: passa a receber o(s) driver(s) do `current_user` e fazer match por `full_name` normalizado + aliases conhecidos.
   - [ ] Fuzzy genérico de OCR (tolerância a trocas de letras típicas: E↔F, I↔L, O↔0, S↔5, espaços/pontuação) aplicado sobre o `full_name` de qualquer piloto, não sobre um padrão fixo.
   - [ ] Score de confiança por linha: match exato > alias > fuzzy; fuzzy com score baixo vai para revisão marcado como "incerto" em vez de ser assumido.
   - [ ] Múltiplos perfis do mesmo usuário: uma linha pode bater com qualquer perfil do usuário; a revisão resolve qual perfil recebe a entrada.

3. **Revisão de import (UX)**
   - [ ] Checkbox genérico "piloto?" por linha (já renomeado na fase 0) agora com seletor de **qual perfil do usuário** aquela linha representa.
   - [ ] Sugestão automática com destaque de confiança (verde = exato, amarelo = fuzzy, cinza = não reconhecido).
   - [ ] Ao confirmar uma linha não reconhecida como "minha", o app pergunta: "salvar esta grafia como variação do seu nome?" → cria alias automaticamente.

4. **Qualidade do OCR em si**
   - [ ] Revisar pré-processamento de imagem (há scripts em `tmp/preprocess_*.ps1` — formalizar o que funciona dentro do pipeline, fora do `tmp/`).
   - [ ] Avaliar melhorias: upscale/threshold adaptativo, tessdata por idioma, segunda passada só nas linhas com baixa confiança.
   - [ ] Métricas: registrar taxa de linhas reconhecidas sem intervenção por import (meta: subir continuamente a cada ajuste).
   - [ ] Testes com corpus real de folhas do KGV (fixture de imagens + resultado esperado) para evitar regressão.

---

### Fase 6 — Mais traçados e modalidades (futuro)

- [ ] Hoje `track_controller.rb:4` fixa `circuito-101` e o import assume KGV. Generalizar:
  - [ ] Seleção de venue/traçado no import (hoje só KGV 101 é aceito — feature, não bug, no lançamento).
  - [ ] Cadastro de novos venues/traçados (admin curadoria inicial; depois submissão por usuários).
  - [ ] `VehicleCategory` já existe (`kart-rental`); adicionar carro/moto track day quando houver demanda.
- [ ] Validação "traçado aceito": import rejeita/alerta sessões fora dos traçados suportados.

---

## 4. Decisões pendentes (precisam de resposta antes de codar)

| # | Decisão | Opções | Recomendação |
|---|---|---|---|
| 1 | Signup aberto ou por convite? | Aberto / convite admin | **Convite** no lançamento |
| 2 | Coluna `kind` (smurf) | Ignorar / dropar agora | Ignorar na fase 0, dropar na fase 1 |
| 3 | Dados pessoais existentes no banco | Manter como dados do admin / anonimizar | Manter como dados do usuário admin |
| 4 | Banco gerenciado | Neon (confirmado?) / Supabase / RDS | Neon, validar custo dos 4 bancos |
| 5 | Domínio | qual registrar? | Verificar `tracknight.*` |
| 6 | Email transacional | Resend / Postmark / SES | Resend (mais simples p/ Rails) |
| 7 | Storage de uploads | Local / S3 / R2 | Local agora, R2 quando escalar |

## 5. Riscos e observações

- **Fase 0 é segura**: renames não tocam dados; rollback é `git revert`.
- **Fase 1 é a mais arriscada**: backfill de `user_id` em todas as tabelas precisa de migration cuidadosa e teste com dump de produção. Fazer em staging primeiro.
- **OCR por usuário**: o `DriverMatcher` hoje aprende aliases globalmente; na fase 1, aliases passam a ser por usuário — pilotos com nomes parecidos entre usuários diferentes não podem vazar match cruzado (escopo obrigatório).
- **`bin/ci` e testes**: rodar `bin/ci` antes de cada fase; cobertura atual em `test/` é pequena — fase 1 exige testes de escopo (usuário A não vê dados de B).
- **Arquivos temporários**: `tmp/` tem muitos scripts de debug pessoais (`debug_band.rb`, `check_*.rb`, etc.) — revisar e limpar na fase 0/1; nada de dado pessoal commitado.

## 6. Checklist resumido de hoje (fase 0)

```
[ ] Layout: título, logo, subtítulo neutros
[ ] Login: tagline neutra
[ ] Dashboard: h1 dinâmico
[ ] Karts: texto sem nome
[ ] Views de perfil/ranking/menu: sem "smurf"/"principal"
[ ] CSS: --color-smurf → --color-accent; .row-ale → .row-tracked
[ ] Models/services: alessandro_entry → tracked_entry; alessandro? → tracked?
[ ] DriverMatcher: padrões via config, sem nome hardcoded
[ ] imports/review: checkbox e texto genéricos
[ ] seeds.rb: sem usuários/pilotos pessoais; demo seed separado
[ ] ENVs: ADMIN_USERNAME / ADMIN_INITIAL_PASSWORD
[ ] docs/RANKING.md + README.md neutros
[ ] script/validate_parse.rb genérico
[ ] grep final: zero xande/alessandro/chiarelli/helo/smurf
[ ] bin/dev sobe, login funciona, telas ok
```
