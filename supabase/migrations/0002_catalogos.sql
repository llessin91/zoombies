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
