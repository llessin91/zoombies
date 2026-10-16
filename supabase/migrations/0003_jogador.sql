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
