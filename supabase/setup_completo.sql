-- ZOMBIES: configuração completa do banco (Fase 2). Cole tudo no SQL Editor do Supabase e clique em Run.

-- ======== migrations/0001_utilitarios.sql ========
-- 0001: utilitários. Pode ser executado mais de uma vez sem problema.

-- Atualiza a coluna atualizado_em automaticamente em todo UPDATE
create or replace function public.definir_atualizado_em()
returns trigger
language plpgsql
as $$
begin
  new.atualizado_em := now();
  return new;
end;
$$;

-- ======== migrations/0002_catalogos.sql ========
-- 0002: tabelas de catálogo (conteúdo do jogo, somente leitura para jogadores).

create table if not exists public.regions (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  nome text not null,
  descricao text not null default '',
  ordem int not null,
  nivel_minimo int not null default 1 check (nivel_minimo >= 1),
  -- slug do item-chave exigido (ex.: credencial_industrial). Validado pela lógica do jogo.
  item_acesso_slug text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.locations (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  region_id uuid not null references public.regions(id) on delete restrict,
  nome text not null,
  descricao text not null default '',
  ordem int not null default 0,
  requisitos jsonb not null default '{}'::jsonb,
  -- null = usar o cooldown por dificuldade da tabela game_config
  cooldown_dias int check (cooldown_dias is null or cooldown_dias >= 0),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index if not exists idx_locations_region on public.locations(region_id);

create table if not exists public.shelters (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  tipo text not null check (tipo in ('inicial', 'local_comum')),
  nome text not null,
  descricao text not null default '',
  region_id uuid references public.regions(id) on delete set null,
  location_id uuid references public.locations(id) on delete set null,
  slots_iniciais int not null check (slots_iniciais >= 1),
  vantagens jsonb not null default '{}'::jsonb,
  desvantagens jsonb not null default '{}'::jsonb,
  ordem int not null default 0,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.items (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  nome text not null,
  tipo text not null check (tipo in ('recurso', 'consumivel', 'arma', 'item_chave')),
  subtipo text,
  raridade text not null default 'comum' check (raridade in ('comum', 'incomum', 'raro', 'epico', 'lendario')),
  peso numeric(6,2) not null default 0 check (peso >= 0),
  descricao text not null default '',
  efeitos jsonb not null default '{}'::jsonb,
  durabilidade_max int check (durabilidade_max is null or durabilidade_max > 0),
  nivel_requisito int not null default 1 check (nivel_requisito >= 1),
  -- armas com durabilidade ficam em linhas separadas no inventário
  empilhavel boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.building_types (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  nome text not null,
  categoria text not null check (categoria in ('estrutural', 'energia', 'producao')),
  descricao text not null default '',
  custo jsonb not null default '{}'::jsonb,           -- { "madeira": 3 }
  requisitos jsonb not null default '{}'::jsonb,
  tempo_construcao_dias numeric(5,2) not null default 1 check (tempo_construcao_dias >= 0),
  niveis jsonb not null default '[]'::jsonb,          -- melhorias (níveis 1, 2, 3...)
  producao jsonb not null default '{}'::jsonb,
  manutencao jsonb not null default '{}'::jsonb,
  consumo_energia numeric(4,1) not null default 0 check (consumo_energia >= 0),
  efeitos jsonb not null default '{}'::jsonb,
  desmontavel boolean not null default false,
  ordem int not null default 0,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.missions (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  nome text not null,
  location_id uuid not null references public.locations(id) on delete restrict,
  categoria text not null check (categoria in ('exploracao', 'coleta_materiais', 'coleta_combustivel', 'resgate', 'combate', 'chefe')),
  dificuldade text not null check (dificuldade in ('facil', 'media', 'dificil', 'lendaria')),
  -- null = usar o valor da dificuldade em game_config
  custo_stamina int check (custo_stamina is null or custo_stamina >= 0),
  duracao_segundos int check (duracao_segundos is null or duracao_segundos > 0),
  xp_base int check (xp_base is null or xp_base >= 0),
  pesos jsonb not null default '{}'::jsonb,      -- { "percepcao": 50, "agilidade": 25 }
  loot jsonb not null default '[]'::jsonb,
  requisitos jsonb not null default '{}'::jsonb,
  textos jsonb not null default '{}'::jsonb,     -- { "abertura": "...", "log": ["..."] }
  ativa boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index if not exists idx_missions_location on public.missions(location_id);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  escopo text not null check (escopo in ('geral', 'regional', 'local')),
  region_id uuid references public.regions(id) on delete set null,
  location_id uuid references public.locations(id) on delete set null,
  peso int not null default 1 check (peso >= 0),
  titulo text not null,
  texto text not null default '',
  opcoes jsonb not null default '[]'::jsonb,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index if not exists idx_events_escopo on public.events(escopo);

create table if not exists public.recipes (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  nome text not null,
  tipo text not null default 'fabricar' check (tipo in ('fabricar', 'reparar')),
  item_resultado_id uuid references public.items(id) on delete restrict,
  quantidade_resultado int not null default 1 check (quantidade_resultado >= 1),
  ingredientes jsonb not null default '{}'::jsonb,   -- { "metal": 2, "pecas_mecanicas": 1 }
  instalacao_slug text,                              -- ex.: oficina
  projeto_item_id uuid references public.items(id) on delete set null,
  dica_projeto text,                                 -- dica mostrada quando a receita é "???"
  atributo_exigido text check (atributo_exigido is null or atributo_exigido in ('forca', 'agilidade', 'percepcao', 'medicina', 'engenharia', 'lideranca')),
  nivel_atributo int check (nivel_atributo is null or nivel_atributo >= 1),
  duracao_dias numeric(5,2) not null default 0 check (duracao_dias >= 0),
  ativa boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

-- Constantes de balanceamento. Edite o "valor" pelo Table Editor do Supabase.
create table if not exists public.game_config (
  chave text primary key,
  valor jsonb not null,
  descricao text not null default '',
  provisorio boolean not null default true,
  atualizado_em timestamptz not null default now()
);

-- ======== migrations/0003_jogador.sql ========
-- 0003: tabelas de estado do jogador. Todas ligadas ao usuário com "on delete cascade":
-- apagar a conta apaga tudo (política de exclusão de conta).

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nome_sobrevivente text not null check (char_length(nome_sobrevivente) between 3 and 20),
  aceitou_16_mais boolean not null check (aceitou_16_mais),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
-- Nome único sem diferenciar maiúsculas de minúsculas
create unique index if not exists uq_profiles_nome on public.profiles (lower(nome_sobrevivente));

-- Valores iniciais de atributos, stamina e moral NÃO têm default aqui:
-- vêm de game_config na criação do personagem (Fase 3).
-- O limite de 100 nos atributos é só uma trava de segurança; o máximo do jogo fica em game_config.
create table if not exists public.characters (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  nivel int not null default 1 check (nivel >= 1),
  xp int not null default 0 check (xp >= 0),
  pontos_disponiveis int not null default 0 check (pontos_disponiveis >= 0),
  forca int not null check (forca between 1 and 100),
  agilidade int not null check (agilidade between 1 and 100),
  percepcao int not null check (percepcao between 1 and 100),
  medicina int not null check (medicina between 1 and 100),
  engenharia int not null check (engenharia between 1 and 100),
  lideranca int not null check (lideranca between 1 and 100),
  moral int not null check (moral between 0 and 100),
  stamina_atual int not null check (stamina_atual >= 0),
  stamina_atualizada_em timestamptz not null default now(),
  xp_multiplier numeric(5,2) not null default 1.00 check (xp_multiplier > 0),  -- gancho futuro (sem interface)
  tutorial_etapa int not null default 0 check (tutorial_etapa >= 0),
  ultimo_evento_id uuid references public.events(id) on delete set null,
  ultimo_tick_em timestamptz not null default now(),
  stats jsonb not null default '{}'::jsonb,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.location_cooldowns (
  user_id uuid not null references public.profiles(id) on delete cascade,
  location_id uuid not null references public.locations(id) on delete cascade,
  disponivel_em timestamptz not null,
  primary key (user_id, location_id)
);

create table if not exists public.user_shelters (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  shelter_id uuid not null references public.shelters(id) on delete restrict,
  ativo boolean not null default true,
  slots int not null check (slots >= 0),
  vezes_reconstruido int not null default 0 check (vezes_reconstruido >= 0),
  ameaca_mult numeric(5,2) not null default 1.00 check (ameaca_mult > 0),
  destruido_em timestamptz,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
-- Só um abrigo ativo por jogador
create unique index if not exists uq_user_shelters_ativo on public.user_shelters(user_id) where ativo;
create index if not exists idx_user_shelters_user on public.user_shelters(user_id);

create table if not exists public.user_buildings (
  id uuid primary key default gen_random_uuid(),
  user_shelter_id uuid not null references public.user_shelters(id) on delete cascade,
  building_type_id uuid not null references public.building_types(id) on delete restrict,
  nivel int not null default 1 check (nivel >= 1),
  estado text not null default 'construindo' check (estado in ('construindo', 'ativo', 'danificado', 'parado')),
  dano int not null default 0 check (dano >= 0),
  producao_acumulada numeric(10,2) not null default 0 check (producao_acumulada >= 0),
  ultimo_ciclo_em timestamptz,
  manutencao_ok boolean not null default true,
  concluido_em timestamptz,   -- quando a construção termina
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index if not exists idx_user_buildings_abrigo on public.user_buildings(user_shelter_id);

-- DECISÃO: inventário e depósito unificados nesta tabela, com a coluna "local"
-- ('mochila' ou 'deposito'). Motivo: mover item entre mochila e depósito vira só
-- um UPDATE, o código de peso/carga fica em um lugar só, e há menos tabelas para
-- proteger com RLS. O depósito pertence a um abrigo (user_shelter_id).
create table if not exists public.inventory (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  item_id uuid not null references public.items(id) on delete restrict,
  local text not null default 'mochila' check (local in ('mochila', 'deposito')),
  user_shelter_id uuid references public.user_shelters(id) on delete cascade,
  quantidade int not null check (quantidade >= 0),
  durabilidade int check (durabilidade is null or durabilidade >= 0),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  check ((local = 'deposito') = (user_shelter_id is not null))
);
-- Itens empilháveis (sem durabilidade): uma linha por item e local
create unique index if not exists uq_inventory_pilha on public.inventory
  (user_id, item_id, local, coalesce(user_shelter_id, '00000000-0000-0000-0000-000000000000'::uuid))
  where durabilidade is null;
create index if not exists idx_inventory_user on public.inventory(user_id);

-- Aponta para a linha do inventário (assim a durabilidade da arma equipada é a da própria linha)
create table if not exists public.equipment (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  slot text not null check (slot in ('arma_principal', 'arma_corpo_a_corpo')),
  inventory_id uuid not null references public.inventory(id) on delete cascade,
  atualizado_em timestamptz not null default now(),
  unique (user_id, slot)
);

create table if not exists public.expeditions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  mission_id uuid not null references public.missions(id) on delete restrict,
  estado text not null default 'em_andamento' check (estado in ('em_andamento', 'aguardando_evento', 'concluida', 'expirada')),
  iniciada_em timestamptz not null default now(),
  termina_em timestamptz not null,
  seed bigint not null,
  evento_id uuid references public.events(id) on delete set null,
  evento_resolvido boolean not null default false,
  resultado jsonb,
  arma_id uuid references public.inventory(id) on delete set null,
  consumiveis jsonb not null default '[]'::jsonb,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index if not exists idx_expeditions_user_estado on public.expeditions(user_id, estado);
create index if not exists idx_expeditions_termina on public.expeditions(termina_em);

create table if not exists public.recruits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  user_shelter_id uuid references public.user_shelters(id) on delete set null,
  nome text not null,
  saude int not null default 100 check (saude between 0 and 100),
  moral int not null default 70 check (moral between 0 and 100),
  estado text not null default 'ativo' check (estado in ('ativo', 'doente', 'ferido', 'inativo')),
  desde_em timestamptz not null default now(),
  aparencia jsonb not null default '{}'::jsonb,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index if not exists idx_recruits_user on public.recruits(user_id);

create table if not exists public.unlocked_recipes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  recipe_id uuid not null references public.recipes(id) on delete cascade,
  desbloqueada_em timestamptz not null default now(),
  primary key (user_id, recipe_id)
);

create table if not exists public.crafting_queue (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  recipe_id uuid not null references public.recipes(id) on delete restrict,
  inicia_em timestamptz not null default now(),
  termina_em timestamptz not null,
  estado text not null default 'em_andamento' check (estado in ('em_andamento', 'pronta', 'coletada')),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index if not exists idx_crafting_user_estado on public.crafting_queue(user_id, estado);
create index if not exists idx_crafting_termina on public.crafting_queue(termina_em);

create table if not exists public.game_log (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  tipo text not null,
  texto text not null,
  dados jsonb not null default '{}'::jsonb,
  criado_em timestamptz not null default now()
);
create index if not exists idx_game_log_user on public.game_log(user_id, criado_em desc);

-- Gatilho de atualizado_em em todas as tabelas que têm a coluna
do $$
declare t text;
begin
  foreach t in array array[
    'regions', 'locations', 'shelters', 'items', 'building_types', 'missions', 'events', 'recipes',
    'game_config', 'profiles', 'characters', 'user_shelters', 'user_buildings', 'inventory',
    'equipment', 'expeditions', 'recruits', 'crafting_queue'
  ] loop
    execute format('drop trigger if exists trg_atualizado_em on public.%I', t);
    execute format(
      'create trigger trg_atualizado_em before update on public.%I for each row execute function public.definir_atualizado_em()', t
    );
  end loop;
end;
$$;

-- ======== migrations/0004_perfil_e_nome.sql ========
-- 0004: cria o perfil automaticamente quando um usuário se cadastra,
-- e uma função para checar se o nome de sobrevivente está livre.

create or replace function public.criar_perfil_novo_usuario()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_nome text;
  v_aceitou boolean;
begin
  v_nome := btrim(coalesce(new.raw_user_meta_data->>'nome_sobrevivente', ''));
  v_aceitou := coalesce((new.raw_user_meta_data->>'aceitou_16_mais')::boolean, false);

  -- O servidor também valida (não confia só na tela)
  if char_length(v_nome) < 3 or char_length(v_nome) > 20 then
    raise exception 'Nome do sobrevivente inválido (3 a 20 caracteres).';
  end if;
  if not v_aceitou then
    raise exception 'É preciso confirmar que tem 16 anos ou mais.';
  end if;

  insert into public.profiles (id, nome_sobrevivente, aceitou_16_mais)
  values (new.id, v_nome, true);

  return new;
end;
$$;

drop trigger if exists ao_criar_usuario on auth.users;
create trigger ao_criar_usuario
  after insert on auth.users
  for each row execute function public.criar_perfil_novo_usuario();

-- Usada na tela de cadastro para avisar "nome já em uso" antes de criar a conta
create or replace function public.nome_disponivel(p_nome text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1 from public.profiles where lower(nome_sobrevivente) = lower(btrim(p_nome))
  );
$$;

revoke all on function public.nome_disponivel(text) from public;
grant execute on function public.nome_disponivel(text) to anon, authenticated;

-- ======== migrations/0005_rls.sql ========
-- 0005: segurança (Row Level Security).
-- Regra: o jogador só LÊ dados próprios e o catálogo. Ninguém altera estado do jogo
-- direto pelo navegador: escritas só por funções SECURITY DEFINER ou pelo servidor.

-- 1) Liga RLS em TODAS as tabelas do schema public
do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end;
$$;

-- 2) Catálogos: leitura para usuários logados
do $$
declare t text;
begin
  foreach t in array array[
    'regions', 'locations', 'shelters', 'items', 'building_types', 'missions', 'events', 'recipes', 'game_config'
  ] loop
    execute format('drop policy if exists "catalogo_leitura" on public.%I', t);
    execute format('create policy "catalogo_leitura" on public.%I for select to authenticated using (true)', t);
  end loop;
end;
$$;

-- 3) Dados do jogador: cada um lê só o que é seu
do $$
declare t text;
begin
  foreach t in array array[
    'characters', 'location_cooldowns', 'expeditions', 'user_shelters', 'inventory',
    'equipment', 'recruits', 'unlocked_recipes', 'crafting_queue', 'game_log'
  ] loop
    execute format('drop policy if exists "proprio_leitura" on public.%I', t);
    execute format(
      'create policy "proprio_leitura" on public.%I for select to authenticated using (user_id = (select auth.uid()))', t
    );
  end loop;
end;
$$;

drop policy if exists "proprio_leitura" on public.profiles;
create policy "proprio_leitura" on public.profiles
  for select to authenticated using (id = (select auth.uid()));

drop policy if exists "proprio_leitura" on public.user_buildings;
create policy "proprio_leitura" on public.user_buildings
  for select to authenticated
  using (exists (
    select 1 from public.user_shelters us
    where us.id = user_buildings.user_shelter_id and us.user_id = (select auth.uid())
  ));

-- 4) Permissões de tabela (cinto e suspensório): só leitura para logados, nada para anônimos
revoke all on all tables in schema public from anon;
revoke insert, update, delete, truncate, references, trigger on all tables in schema public from authenticated;
grant select on all tables in schema public to authenticated;

-- ======== seed/seed_game_config.sql ========
-- Constantes de balanceamento. TODAS provisórias (marcadas como provisorio = true).
-- "do nothing": rodar de novo NÃO apaga valores que você já editou.

insert into public.game_config (chave, valor, descricao, provisorio) values
  ('tempo.dias_jogo_por_hora_real', '24', '1 hora real = 24 horas (1 dia) do jogo', true),
  ('tempo.max_catchup_dias_producao', '30', 'Máximo de dias do jogo de produção aplicados por consulta', true),

  ('stamina.inicial', '20', 'Stamina inicial', true),
  ('stamina.maxima', '20', 'Stamina máxima base', true),
  ('stamina.custo_por_dificuldade', '{"facil":2,"media":3,"dificil":5,"lendaria":6}', 'Custo de stamina por dificuldade', true),
  ('stamina.minutos_por_ponto', '6', 'Minutos reais para recuperar 1 ponto de stamina', true),
  ('stamina.recupera_por_item', '{"agua_potavel":1,"comida_enlatada":2,"racao_militar":3}', 'Stamina recuperada ao consumir', true),

  ('atributos.pontos_na_criacao', '12', 'Pontos distribuídos na criação do personagem', true),
  ('atributos.minimo_na_criacao', '1', 'Mínimo por atributo na criação', true),
  ('atributos.maximo_na_criacao', '3', 'Máximo por atributo na criação', true),
  ('atributos.maximo', '20', 'Valor máximo de um atributo', true),

  ('moral.inicial', '70', 'Moral inicial (0 a 100)', true),
  ('moral.divisor_modificador', '10', 'M = (moral - 50) / divisor, em pontos percentuais', true),
  ('moral.bonus_sucesso_facil', '2', 'Moral recuperada por sucesso em missão fácil', true),
  ('moral.perda_por_nao_ajudar', '{"facil":5,"media":8,"dificil":12,"lendaria":15}', 'Perda de moral ao deixar sobrevivente morrer', true),

  ('missao.formula', '{"base":50,"peso_diferenca":5,"minimo":5,"maximo":95,"margem_parcial":15,"parcial_loot_pct":50,"parcial_xp_pct":50,"falha_xp_pct":15}', 'Constantes da fórmula de sucesso', true),
  ('missao.dificuldade_numerica', '{"facil":3,"media":6,"dificil":10,"lendaria":14}', 'D da fórmula por dificuldade', true),
  ('missao.duracao_segundos', '{"facil":30,"media":60,"dificil":90,"lendaria":120}', 'Duração real da expedição', true),
  ('missao.xp_base', '{"facil":20,"media":45,"dificil":90,"lendaria":160}', 'XP base por dificuldade', true),
  ('missao.cooldown_local_dias', '{"facil":3,"media":5,"dificil":8,"lendaria":12}', 'Dias do jogo de local esgotado após saque', true),

  ('eventos.probabilidade_pct', '{"facil":60,"media":70,"dificil":80,"lendaria":90}', 'Chance de ocorrer evento na expedição', true),
  ('eventos.peso_regional_pct', '70', 'Peso de eventos regionais no sorteio (o resto é geral)', true),
  ('eventos.prazo_decisao_horas', '24', 'Horas reais até a opção mais cautelosa ser aplicada sozinha', true),

  ('xp.para_subir_ate_nivel_10', '[100,150,220,320,450,600,800,1050,1350]', 'XP para 1→2, 2→3 ... 9→10', true),
  ('xp.incremento_apos_nivel_10', '350', 'A cada nível a partir de 10→11 soma-se este valor', true),
  ('xp.pontos_por_nivel', '{"ate_nivel_10":3,"a_partir_nivel_11":2}', 'Pontos de atributo ganhos por nível', true),

  ('carga.base', '10', 'Capacidade de carga base em expedição', true),
  ('carga.por_ponto_forca', '2', 'Carga extra por ponto de Força', true),
  ('deposito.capacidade_inicial', '100', 'Capacidade do depósito do abrigo', true),

  ('recrutas.limite_base', '2', 'Limite de recrutas sem residências', true),
  ('recrutas.consumo_dias', '{"comida":2,"agua":2,"energia":3}', 'A cada quantos dias do jogo 1 unidade é consumida por recruta', true),
  ('recrutas.lideranca_reducao_pct_por_ponto', '2.5', 'Redução de consumo por ponto de Liderança', true),
  ('recrutas.lideranca_reducao_max_pct', '20', 'Teto da redução de consumo', true),

  ('energia.gerador_basico', '{"cobre_recrutas":3,"dias_por_combustivel":5}', 'Gerador básico', true),
  ('energia.gerador_avancado', '{"cobre_recrutas":6,"dias_por_combustivel":3}', 'Gerador avançado', true),
  ('energia.painel_solar', '{"cobre_recrutas":2}', 'Painel solar', true),

  ('ataques.chance_base_por_regiao_pct', '{"periferia":3,"centro_urbano":5,"zona_industrial":7,"zona_militar_cientifica":9}', 'Chance diária de ataque ao abrigo', true),
  ('ataques.acrescimo_por_reconstrucao_pct', '25', 'Aumento permanente de chance e gravidade por reconstrução', true),

  ('fabricacao.reducao_pct_por_ponto_acima', '2', 'Redução de duração por ponto de atributo acima do exigido', true),
  ('fabricacao.limite_reducao_pct', '50', 'Máximo de redução da duração base', true),
  ('fabricacao.fila_maxima', '1', 'Itens simultâneos na fila (2 com Oficina avançada, opcional)', true)
on conflict (chave) do nothing;

-- ======== seed/seed_regions.sql ========
-- Regiões e os 32 locais. Pode rodar de novo (atualiza textos).

insert into public.regions (slug, nome, descricao, ordem, nivel_minimo, item_acesso_slug) values
  ('periferia', 'Periferia', 'Casas baixas, postes caídos e lixo ao vento. O melhor lugar para errar sem consequências graves.', 1, 1, null),
  ('centro_urbano', 'Centro Urbano', 'Prédios altos, carros abandonados e letreiros que ainda piscam para ninguém.', 2, 4, null),
  ('zona_industrial', 'Zona Industrial', 'Chaminés, guindastes e ferro velho. Tudo aqui pode ser útil, e quase tudo pode te machucar.', 3, 8, 'credencial_industrial'),
  ('zona_militar_cientifica', 'Zona Militar e Científica', 'Cercas, holofotes, bunkers e laboratórios com luz fria. Alguém sabia o que estava fazendo. Não deu certo.', 4, 12, 'cartao_acesso_militar')
on conflict (slug) do update set
  nome = excluded.nome, descricao = excluded.descricao, ordem = excluded.ordem,
  nivel_minimo = excluded.nivel_minimo, item_acesso_slug = excluded.item_acesso_slug;

-- Observação: o "Posto de gasolina" da Periferia (missões de combustível) é um ponto de missão
-- dentro do Terminal do Bairro Novo, criado na Fase 4. Por isso são exatamente 32 locais aqui.
insert into public.locations (slug, region_id, nome, descricao, ordem)
select v.slug, r.id, v.nome, v.descricao, v.ordem
from (values
  ('praca_do_lotus', 'periferia', 'Praça do Lótus', 'A fonte secou antes do mundo acabar. Os pombos foram os primeiros a desistir.', 1),
  ('mercearia_do_joaquim', 'periferia', 'Mercearia do Joaquim', 'Prateleiras reviradas e um caderno de fiado que ninguém vai cobrar.', 2),
  ('oficina_dois_irmaos', 'periferia', 'Oficina Dois Irmãos', 'Ferramentas, graxa e um calendário parado em um mês que não existe mais.', 3),
  ('lavanderia_brisa_limpa', 'periferia', 'Lavanderia Brisa Limpa', 'Tudo cheira a sabão e a mofo. Sobrou muita roupa, nenhum cliente.', 4),
  ('conjunto_primavera', 'periferia', 'Conjunto Primavera', 'Blocos de apartamentos com portas arrombadas e síndico ausente.', 5),
  ('terminal_do_bairro_novo', 'periferia', 'Terminal do Bairro Novo', 'Ônibus parados em fila, como sempre. A diferença é que agora ninguém reclama.', 6),
  ('campo_do_uniao', 'periferia', 'Campo do União', 'O gramado virou mato. As traves resistem, como o time sempre resistiu.', 7),
  ('clinica_sao_bento', 'periferia', 'Clínica São Bento', 'Sala de espera lotada, só que de quem não precisa mais de consulta.', 8),
  ('farmacia_drogalina', 'centro_urbano', 'Farmácia Drogalina', 'Remédios por todo lado. O problema é saber quais ainda servem.', 1),
  ('estacionamento_do_ze', 'centro_urbano', 'Estacionamento do Zé', 'Carros demais, donos de menos. Os tanques raramente estão vazios.', 2),
  ('escola_infantil_jujuba', 'centro_urbano', 'Escola Infantil Jujuba', 'Desenhos na parede e um silêncio que ninguém gosta de quebrar.', 3),
  ('galeria_aurora', 'centro_urbano', 'Galeria Aurora', 'Lojas de eletrônicos e roupas de liquidação. O último desconto foi definitivo.', 4),
  ('hotel_imperial', 'centro_urbano', 'Hotel Imperial', 'Cinco estrelas por fora, cinco andares de problema por dentro.', 5),
  ('estacao_central', 'centro_urbano', 'Estação Central', 'Os trens atrasaram para sempre. Os corredores do metrô nem se discute.', 6),
  ('edificio_horizonte', 'centro_urbano', 'Edifício Horizonte', 'Vista panorâmica do fim do mundo, andar por andar.', 7),
  ('mercado_bom_vizinho', 'centro_urbano', 'Mercado Bom Vizinho', 'Corredores cheios de latas, e de gente que não está mais ali para brigar por elas.', 8),
  ('fabrica_textil_fio_norte', 'zona_industrial', 'Fábrica Têxtil Fio Norte', 'Teares parados e rolos de tecido. A produção só parou por falta de funcionários vivos.', 1),
  ('deposito_sete_trilhos', 'zona_industrial', 'Depósito Sete Trilhos', 'Contêineres empilhados e reservatórios que ninguém esvaziou a tempo.', 2),
  ('usina_termeletrica_vale_cinzento', 'zona_industrial', 'Usina Termelétrica Vale Cinzento', 'Dá para ouvir o metal estalando. Tanques de reserva, se você chegar neles.', 3),
  ('ferro_velho_parafuso', 'zona_industrial', 'Ferro-Velho Parafuso', 'Montanhas de sucata e cães que já não latem.', 4),
  ('frigorifico_santa_brasa', 'zona_industrial', 'Frigorífico Santa Brasa', 'As câmaras frias perderam a energia. O cheiro conta o resto da história.', 5),
  ('estaleiro_mare_morta', 'zona_industrial', 'Estaleiro Maré Morta', 'Cascos inacabados e guindastes inclinados sobre a água parada.', 6),
  ('silos_graneleiros_horizonte', 'zona_industrial', 'Silos Graneleiros Horizonte', 'Grãos suficientes para um inverno inteiro, e ratos que pensam o mesmo.', 7),
  ('estacao_tratamento_agua_clara', 'zona_industrial', 'Estação de Tratamento Água Clara', 'O nome é otimista. A água, nem tanto.', 8),
  ('posto_avancado_corvo', 'zona_militar_cientifica', 'Posto Avançado Corvo', 'Cerca eletrificada sem eletricidade e um depósito que ainda guarda segredos.', 1),
  ('base_campanula', 'zona_militar_cientifica', 'Base Campânula', 'Quartéis vazios e uma bandeira que ninguém baixou.', 2),
  ('laboratorio_helix_9', 'zona_militar_cientifica', 'Laboratório Helix-9', 'Luz fria, vidro quebrado e pranchetas com notas que ninguém deveria ler.', 3),
  ('hospital_isolamento_santa_augusta', 'zona_militar_cientifica', 'Hospital de Isolamento Santa Augusta', 'Fica claro por que chamavam de isolamento. Só não deu para isolar o suficiente.', 4),
  ('complexo_subterraneo_nemesis', 'zona_militar_cientifica', 'Complexo Subterrâneo Nêmesis', 'Quanto mais fundo, menos gente. Quanto mais fundo, mais outras coisas.', 5),
  ('campo_testes_cobalto', 'zona_militar_cientifica', 'Campo de Testes Cobalto', 'Crateras alinhadas e placas de aviso que chegaram tarde.', 6),
  ('centro_comunicacoes_vigilia', 'zona_militar_cientifica', 'Centro de Comunicações Vigília', 'Antenas ainda apontadas para o céu, esperando uma resposta que não vem.', 7),
  ('hangar_setor_vibora', 'zona_militar_cientifica', 'Hangar Setor Víbora', 'Um hangar enorme com muito combustível e muito pouco motivo para você estar aqui.', 8)
) as v(slug, regiao, nome, descricao, ordem)
join public.regions r on r.slug = v.regiao
on conflict (slug) do update set
  region_id = excluded.region_id, nome = excluded.nome, descricao = excluded.descricao, ordem = excluded.ordem;

-- ======== seed/seed_items.sql ========
-- Itens. Pesos, bônus de arma e durabilidades são PROVISÓRIOS (ajuste aqui).
-- Efeitos de bandagem, kits, antibióticos etc. ficam vazios até a Fase 6.
-- Colunas: slug, nome, tipo, subtipo, raridade, peso, descricao, efeitos, durabilidade_max, nivel_requisito, empilhavel

insert into public.items (slug, nome, tipo, subtipo, raridade, peso, descricao, efeitos, durabilidade_max, nivel_requisito, empilhavel) values
  -- Recursos
  ('madeira', 'Madeira', 'recurso', null, 'comum', 1, 'Tábuas, pallets e móveis que não vão mais ser usados como móveis.', '{}', null, 1, true),
  ('sucata', 'Sucata', 'recurso', null, 'comum', 1, 'Pedaços de coisas que já foram outras coisas.', '{}', null, 1, true),
  ('metal', 'Metal', 'recurso', null, 'comum', 1, 'Chapas, barras e canos. Pesa mais do que parece.', '{}', null, 1, true),
  ('tecido', 'Tecido', 'recurso', null, 'comum', 1, 'Pano limpo o bastante para servir de curativo ou de cortina.', '{}', null, 1, true),
  ('componentes_eletronicos', 'Componentes eletrônicos', 'recurso', null, 'incomum', 1, 'Placas, chips e resistores. Tecnologia de antes.', '{}', null, 1, true),
  ('combustivel', 'Combustível', 'recurso', null, 'incomum', 1, 'Mantém o gerador, e a esperança, funcionando.', '{}', null, 1, true),
  ('pecas_mecanicas', 'Peças mecânicas', 'recurso', null, 'comum', 1, 'Engrenagens, molas e rolamentos.', '{}', null, 1, true),
  ('vidro', 'Vidro', 'recurso', null, 'comum', 1, 'Cacos úteis e inteiros raros.', '{}', null, 1, true),
  ('plastico', 'Plástico', 'recurso', null, 'comum', 1, 'Garrafas, caixas e tubos. Vai durar mais que todos nós.', '{}', null, 1, true),
  ('fios_cabos', 'Fios e cabos', 'recurso', null, 'comum', 1, 'Cobre em rolos e emaranhados.', '{}', null, 1, true),

  -- Consumíveis (stamina recuperada vem de game_config; aqui só espelha para exibição)
  ('agua_potavel', 'Água potável', 'consumivel', null, 'comum', 1, 'Limpa, o que hoje é luxo.', '{"stamina":1}', null, 1, true),
  ('comida_enlatada', 'Comida enlatada', 'consumivel', null, 'comum', 1, 'Feijão, atum e uma validade questionável.', '{"stamina":2}', null, 1, true),
  ('racao_militar', 'Ração militar', 'consumivel', null, 'incomum', 1, 'Sem sabor definido, mas com calorias de sobra.', '{"stamina":3}', null, 1, true),
  ('bandagem', 'Bandagem', 'consumivel', null, 'comum', 0.5, 'Estanca um corte. Para o resto, reze.', '{}', null, 1, true),
  ('kit_primeiros_socorros', 'Kit de primeiros socorros', 'consumivel', null, 'incomum', 2, 'Tudo que cabe numa caixa vermelha.', '{}', null, 1, true),
  ('antibiotico', 'Antibiótico', 'consumivel', null, 'raro', 0.5, 'Combate infecções comuns, e algumas incomuns.', '{}', null, 1, true),
  ('antidoto', 'Antídoto', 'consumivel', null, 'raro', 0.5, 'Funciona contra venenos. Contra zumbis, depende.', '{}', null, 1, true),
  ('analgesico', 'Analgésico', 'consumivel', null, 'comum', 0.5, 'A dor continua lá, só fica mais educada.', '{}', null, 1, true),
  ('kit_reparo', 'Kit de reparo', 'consumivel', null, 'incomum', 2, 'Fita, parafusos e paciência embalados juntos.', '{}', null, 1, true),
  ('molotov', 'Molotov', 'consumivel', null, 'incomum', 1, 'Garrafa, pano e combustível. Arremessar de longe.', '{}', null, 1, true),
  ('sinalizador', 'Sinalizador', 'consumivel', null, 'incomum', 1, 'Chama a atenção. Escolha bem de quem.', '{}', null, 1, true),

  -- Itens-chave
  ('credencial_industrial', 'Credencial industrial', 'item_chave', null, 'raro', 0, 'Abre os portões da Zona Industrial.', '{}', null, 1, false),
  ('cartao_acesso_militar', 'Cartão de acesso militar', 'item_chave', null, 'epico', 0, 'Abre a Zona Militar e Científica. Alguém não vai sentir falta dele.', '{}', null, 1, false),
  ('painel_solar', 'Painel solar', 'item_chave', null, 'raro', 5, 'Energia de graça, sem combustível. Permite construir a instalação Painel solar.', '{}', null, 1, false),

  -- Pistolas
  ('glock_17', 'Glock 17', 'arma', 'pistola', 'incomum', 2, 'Confiável e discreta. A escolha de quem ainda quer parecer normal.', '{"bonus_missao":3}', 60, 1, false),
  ('beretta_92fs', 'Beretta 92FS', 'arma', 'pistola', 'incomum', 2, 'Clássica. Pesa um pouco mais do que a reputação.', '{"bonus_missao":3}', 60, 2, false),
  ('sig_sauer_p226', 'SIG Sauer P226', 'arma', 'pistola', 'raro', 2, 'Precisa e robusta. Pistola de quem sabe o que faz.', '{"bonus_missao":4}', 70, 4, false),
  -- Fuzis
  ('ak_47', 'AK-47', 'arma', 'fuzil', 'raro', 4, 'Aguenta lama, chuva e descaso. Como você deveria aguentar.', '{"bonus_missao":6}', 90, 6, false),
  ('m4a1', 'M4A1', 'arma', 'fuzil', 'epico', 4, 'Leve, modular e fora do orçamento de qualquer civil.', '{"bonus_missao":7}', 90, 8, false),
  ('fn_fal', 'FN FAL', 'arma', 'fuzil', 'raro', 4, 'Pesado e potente. O braço direito agradece (ou não).', '{"bonus_missao":7}', 90, 7, false),
  -- Escopetas
  ('remington_870', 'Remington 870', 'arma', 'escopeta', 'incomum', 4, 'Bombeia, atira, resolve. Em curtas distâncias.', '{"bonus_missao":5}', 80, 4, false),
  ('mossberg_500', 'Mossberg 500', 'arma', 'escopeta', 'incomum', 4, 'A irmã mais barata da anterior, com a mesma eficiência.', '{"bonus_missao":5}', 80, 4, false),
  ('benelli_m4', 'Benelli M4', 'arma', 'escopeta', 'epico', 4, 'Tática, rápida e injustamente barata de operar sem munição.', '{"bonus_missao":7}', 90, 8, false),
  -- Rifles de precisão
  ('remington_700', 'Remington 700', 'arma', 'rifle_precisao', 'raro', 5, 'Um tiro, uma decisão, uma consequência.', '{"bonus_missao":6}', 80, 6, false),
  ('barrett_m82', 'Barrett M82', 'arma', 'rifle_precisao', 'lendario', 8, 'Pesada, absurda, impossível de ignorar.', '{"bonus_missao":10}', 100, 12, false),
  ('sako_trg_42', 'Sako TRG-42', 'arma', 'rifle_precisao', 'epico', 5, 'Precisão finlandesa para problemas distantes.', '{"bonus_missao":8}', 80, 9, false),
  -- Corpo a corpo
  ('facao', 'Facão', 'arma', 'corpo_a_corpo', 'comum', 2, 'Ferramenta de mato que trocou de serviço.', '{"bonus_missao":2}', 50, 1, false),
  ('machado', 'Machado', 'arma', 'corpo_a_corpo', 'comum', 3, 'Corta lenha. Ou qualquer coisa que se aproxime.', '{"bonus_missao":3}', 60, 1, false),
  ('pe_de_cabra', 'Pé de cabra', 'arma', 'corpo_a_corpo', 'comum', 3, 'Abre portas, caixas e argumentos.', '{"bonus_missao":3}', 70, 1, false),
  ('bastao_de_beisebol', 'Bastão de beisebol', 'arma', 'corpo_a_corpo', 'comum', 2, 'O esporte nacional de quem nunca jogou.', '{"bonus_missao":2}', 50, 1, false),
  ('faca_de_caca', 'Faca de caça', 'arma', 'corpo_a_corpo', 'comum', 1, 'Silenciosa e confiável. Exige coragem para chegar perto.', '{"bonus_missao":2}', 40, 1, false)
on conflict (slug) do update set
  nome = excluded.nome, tipo = excluded.tipo, subtipo = excluded.subtipo, raridade = excluded.raridade,
  peso = excluded.peso, descricao = excluded.descricao, efeitos = excluded.efeitos,
  durabilidade_max = excluded.durabilidade_max, nivel_requisito = excluded.nivel_requisito, empilhavel = excluded.empilhavel;

-- ======== seed/seed_buildings.sql ========
-- Instalações do abrigo. Custos, tempos e efeitos de defesa são PROVISÓRIOS (exceto os que o prompt
-- define: residências, produção passiva, energia e consumo). Ajuste aqui.
-- Colunas: slug, nome, categoria, descricao, custo, requisitos, tempo_construcao_dias, niveis, producao,
--          manutencao, consumo_energia, efeitos, desmontavel, ordem

insert into public.building_types
  (slug, nome, categoria, descricao, custo, requisitos, tempo_construcao_dias, niveis, producao, manutencao, consumo_energia, efeitos, desmontavel, ordem)
values
  -- Estruturais
  ('residencia', 'Residência', 'estrutural', 'Mais camas, mais gente viva por perto.',
   '{"madeira":3,"tecido":2}', '{}', 1,
   '[{"nivel":1,"nome":"Beliche improvisado","custo":{"madeira":3,"tecido":2},"requisitos":{},"efeitos":{"recrutas_max_bonus":1}},
     {"nivel":2,"nome":"Quarto compartilhado","custo":{"madeira":5,"metal":3},"requisitos":{"engenharia":3,"requer_nivel_anterior":true},"efeitos":{"recrutas_max_bonus":2}},
     {"nivel":3,"nome":"Alojamento reforçado","custo":{"metal":8,"vidro":4},"requisitos":{"engenharia":6,"requer_nivel_anterior":true},"efeitos":{"recrutas_max_bonus":3}}]',
   '{}', '{}', 0, '{"recrutas_max_bonus":1}', false, 1),
  ('area_treinamento', 'Área de treinamento', 'estrutural', 'Sacos de areia, pesos improvisados e muita vontade.',
   '{"madeira":6,"sucata":4}', '{}', 2, '[]', '{}', '{}', 0, '{"atributo_bonus":{"forca":1,"agilidade":1}}', false, 2),
  ('oficina', 'Oficina', 'estrutural', 'Bancada, ferramentas e uma luminária que ainda funciona.',
   '{"madeira":6,"metal":4,"pecas_mecanicas":2}', '{}', 2, '[]', '{}', '{}', 0, '{"atributo_bonus":{"engenharia":1},"desbloqueia_fabricacao":"oficina"}', false, 3),
  ('enfermaria', 'Enfermaria', 'estrutural', 'Uma maca limpa e um estoque de curativos.',
   '{"madeira":4,"tecido":4,"vidro":1}', '{}', 2, '[]', '{}', '{}', 1, '{"atributo_bonus":{"medicina":1},"desbloqueia_fabricacao":"enfermaria"}', false, 4),
  ('cozinha', 'Cozinha', 'estrutural', 'Panela, fogareiro e a arte de render a comida.',
   '{"madeira":4,"metal":2}', '{}', 1, '[]', '{}', '{}', 0, '{"consumo_comida_reducao_pct":10,"desbloqueia_fabricacao":"cozinha"}', false, 5),
  ('muralha', 'Muralha', 'estrutural', 'Entulho, chapas e teimosia empilhados em volta do abrigo.',
   '{"madeira":10,"metal":6,"sucata":6}', '{}', 3, '[]', '{}', '{}', 0, '{"defesa":3}', false, 6),
  ('torre_vigia', 'Torre de vigia', 'estrutural', 'Um lugar alto para ver o problema chegar antes dele.',
   '{"madeira":8,"metal":6,"vidro":2}', '{}', 3, '[]', '{}', '{}', 1, '{"defesa":2,"alerta_ataque":true}', false, 7),
  ('deposito', 'Depósito', 'estrutural', 'Mais prateleiras, menos desculpa para jogar coisa fora.',
   '{"madeira":8,"metal":4}', '{}', 2, '[]', '{}', '{}', 0, '{"capacidade_deposito_bonus":50}', false, 8),
  ('estacao_radio', 'Estação de rádio', 'estrutural', 'Ouve o mundo. Às vezes, o mundo responde.',
   '{"componentes_eletronicos":4,"fios_cabos":4,"metal":2}', '{}', 2, '[]', '{}', '{}', 1, '{"recrutamento_bonus":true,"encontros_resgate_bonus":true}', true, 9),
  ('saida_reforcada', 'Saída reforçada', 'estrutural', 'Uma saída decente, sem tanta ginástica.',
   '{"madeira":6,"metal":4}', '{}', 1, '[]', '{}', '{}', 0, '{"remove_custo_stamina_saida":1}', false, 10),

  -- Energia
  ('gerador_basico', 'Gerador básico', 'energia', 'Faz barulho, cheira mal e mantém a luz acesa.',
   '{"metal":6,"pecas_mecanicas":4,"fios_cabos":2}', '{}', 2, '[]', '{}', '{}', 0,
   '{"cobre_recrutas":3,"dias_por_combustivel":5}', true, 11),
  ('gerador_avancado', 'Gerador avançado', 'energia', 'Mais potência, mais consumo e mais barulho.',
   '{"metal":10,"pecas_mecanicas":6,"componentes_eletronicos":4}', '{"melhora":"gerador_basico"}', 3, '[]', '{}', '{}', 0,
   '{"cobre_recrutas":6,"dias_por_combustivel":3}', true, 12),
  ('painel_solar', 'Painel solar', 'energia', 'Sol de graça. Raro, e por isso mesmo guardado por alguém.',
   '{}', '{"item_chave":"painel_solar"}', 1, '[]', '{}', '{}', 0,
   '{"cobre_recrutas":2}', true, 13),

  -- Produção (valores de produção e manutenção definidos no prompt; chance_extra_pct é provisória)
  ('horta', 'Horta', 'producao', 'Terra, água e a paciência de quem acredita no amanhã.',
   '{"madeira":4}', '{"espaco_externo":true,"agua":true}', 1,
   '[{"nivel":1,"nome":"Horta pequena","custo":{"madeira":4},"requisitos":{"espaco_externo":true,"agua":true},"producao":{"comida":1,"ciclo_dias":2},"manutencao":{"agua":1,"a_cada_ciclos":3}},
     {"nivel":2,"nome":"Horta grande","custo":{"madeira":6,"metal":2},"requisitos":{"engenharia":4},"producao":{"comida":2,"ciclo_dias":2,"extra":1,"chance_extra_pct":25},"manutencao":{"agua":1,"a_cada_ciclos":2}}]',
   '{"comida":1,"ciclo_dias":2}', '{"agua":1,"a_cada_ciclos":3}', 0, '{}', false, 14),
  ('captacao_agua', 'Captação de água', 'producao', 'Calhas, funil e fé na chuva.',
   '{"plastico":3,"sucata":2}', '{"chuva":true}', 1, '[]',
   '{"agua":1,"ciclo_dias":1}', '{}', 0, '{}', false, 15),
  ('galinheiro', 'Galinheiro', 'producao', 'Ovos como moeda, penas como consequência.',
   '{"madeira":2}', '{}', 1, '[]',
   '{"comida":1,"ciclo_dias":1}', '{"comida":1,"a_cada_ciclos":5}', 0, '{}', false, 16),
  ('armadilha_caca', 'Armadilha de caça', 'producao', 'Cordas, arame e um pouco de crueldade necessária.',
   '{"sucata":3,"madeira":2}', '{"percepcao":3}', 1, '[]',
   '{"comida":1,"ciclo_dias":3}', '{"sucata":1,"a_cada_ciclos":4}', 0, '{}', false, 17),
  ('oficina_reciclagem', 'Oficina de reciclagem', 'producao', 'Transforma lixo em coisas menos lixo.',
   '{"metal":6,"pecas_mecanicas":4}', '{"instalacao":"oficina","engenharia":5}', 2, '[]',
   '{"conversoes":{"sucata_para_metal":3,"sucata_para_componentes":5},"modo":"manual_instantaneo"}', '{}', 1, '{}', false, 18),
  ('destilaria', 'Destilaria improvisada', 'producao', 'Cheiro péssimo, resultado inflamável.',
   '{"metal":8,"pecas_mecanicas":4,"vidro":4}', '{"engenharia":6}', 3, '[]',
   '{"combustivel":1,"ciclo_dias":5}', '{"comida":2,"agua":2,"a_cada_ciclos":1}', 1, '{}', false, 19)
on conflict (slug) do update set
  nome = excluded.nome, categoria = excluded.categoria, descricao = excluded.descricao, custo = excluded.custo,
  requisitos = excluded.requisitos, tempo_construcao_dias = excluded.tempo_construcao_dias, niveis = excluded.niveis,
  producao = excluded.producao, manutencao = excluded.manutencao, consumo_energia = excluded.consumo_energia,
  efeitos = excluded.efeitos, desmontavel = excluded.desmontavel, ordem = excluded.ordem;

-- ======== seed/seed_shelters.sql ========
-- Os 4 abrigos iniciais. Números de vantagens e desvantagens do prompt (10%, 5%, 5 unidades, +1 stamina)
-- estão aqui. Quantidade de slots, ruído, dano e custo de reconstrução são PROVISÓRIOS.

insert into public.shelters (slug, tipo, nome, descricao, region_id, location_id, slots_iniciais, vantagens, desvantagens, ordem)
select v.slug, 'inicial', v.nome, v.descricao, r.id, l.id, v.slots, v.vantagens::jsonb, v.desvantagens::jsonb, v.ordem
from (values
  ('apartamento_barricado', 'Apartamento barricado',
   'Quatro paredes, uma porta reforçada com o sofá e uma vista privilegiada do caos. Pequeno, mas ninguém reclamou do aluguel.',
   'periferia', 'conjunto_primavera', 4, '{"stamina_max_bonus_pct":10}', '{"espaco_reduzido":true}', 1),
  ('oficina_abandonada', 'Oficina abandonada',
   'Cheira a graxa e a decisões questionáveis. Tem bancada, ferramentas e um forno que ainda aquece. O barulho, porém, atrai visitas.',
   'periferia', 'oficina_dois_irmaos', 6, '{"engenharia_bonus_pct":10,"forja_basica":true}', '{"ruido_ataque_mult":1.25}', 2),
  ('porao_mercearia', 'Porão da mercearia',
   'Fresco, escuro e cheio de prateleiras que o antigo dono jurava estarem vazias. Sair de lá exige subir uma escada que parece cada vez maior.',
   'periferia', 'mercearia_do_joaquim', 6, '{"recursos_basicos_iniciais":5,"comida_inicial":5,"agua_inicial":5}', '{"custo_stamina_saida_extra":1,"removido_por":"saida_reforcada"}', 3),
  ('trailer_blindado', 'Trailer blindado',
   'Um trailer com chapas soldadas por alguém que nunca viu um manual. Leve e veloz para fugir, mas qualquer ataque sério vira uma lata amassada.',
   'periferia', 'campo_do_uniao', 5, '{"agilidade_bonus_pct_periferia":5,"furtividade_bonus_pct_periferia":5}', '{"dano_ataque_mult":1.25,"reconstrucao_custo_mult":1.5}', 4)
) as v(slug, nome, descricao, regiao, local, slots, vantagens, desvantagens, ordem)
join public.regions r on r.slug = v.regiao
join public.locations l on l.slug = v.local
on conflict (slug) do update set
  nome = excluded.nome, descricao = excluded.descricao, region_id = excluded.region_id, location_id = excluded.location_id,
  slots_iniciais = excluded.slots_iniciais, vantagens = excluded.vantagens, desvantagens = excluded.desvantagens, ordem = excluded.ordem;
