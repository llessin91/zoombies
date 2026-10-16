-- ZOMBIES: configuração completa do banco (até a Fase 7). Cole tudo no SQL Editor do Supabase e clique em Run.
-- Pode rodar mais de uma vez: não apaga jogadores nem valores que você já editou em game_config.

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

-- ======== migrations/0006_personagem.sql ========
-- 0006: PERSONAGEM (Fase 3)
-- Criação do personagem, curva de XP, pontos por nível, distribuição de pontos,
-- moral e stamina com regeneração por "catch-up" (calculada por horário, nunca por timer do navegador).
--
-- Todas as regras ficam aqui no banco. O navegador só mostra o resultado e pede ações.
-- Todos os números vêm da tabela game_config (nada de número solto no código).
-- Pode rodar este arquivo mais de uma vez sem problema.

-- Coluna nova: último nível que o jogador já viu na animação de "subiu de nível"
alter table public.characters add column if not exists nivel_anunciado int not null default 1;

-- Chaves novas de configuração usadas nesta fase (não sobrescreve se você já editou)
insert into public.game_config (chave, valor, descricao, provisorio) values
  ('xp.ultimo_nivel_com_mais_pontos', '10', 'Até este nível ganha "ate_nivel_10" pontos; depois, "a_partir_nivel_11"', true),
  ('tempo.hora_inicial', '8', 'Hora do relógio do jogo no momento em que o personagem é criado', true)
on conflict (chave) do nothing;

-- Correção da Fase 2: "dias do jogo por hora real" estava 24 (eram HORAS do jogo). O certo é 1
-- (1 hora real = 1 dia do jogo). Só corrige se ainda estiver no valor errado de fábrica.
update public.game_config
   set valor = '1'::jsonb,
       descricao = 'Dias do jogo que passam a cada 1 hora real (1 = uma hora real vale um dia do jogo)'
 where chave = 'tempo.dias_jogo_por_hora_real' and valor = '24'::jsonb;

-- ---------------------------------------------------------------------------
-- Leitura de configuração
-- ---------------------------------------------------------------------------
create or replace function public.cfg(p_chave text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v jsonb;
begin
  select valor into v from public.game_config where chave = p_chave;
  if v is null then
    raise exception 'Configuração ausente: %', p_chave;
  end if;
  return v;
end;
$$;

-- ---------------------------------------------------------------------------
-- Curva de XP e pontos por nível
-- ---------------------------------------------------------------------------

-- XP necessário para ir do nível p_nivel para o próximo
create or replace function public.xp_para_subir(p_nivel int)
returns int
language plpgsql
stable
set search_path = ''
as $$
declare
  v_lista jsonb := public.cfg('xp.para_subir_ate_nivel_10');
  v_inc int := (public.cfg('xp.incremento_apos_nivel_10'))::int;
  v_n int := jsonb_array_length(v_lista);
begin
  if p_nivel < 1 then
    raise exception 'Nível inválido.';
  end if;
  if p_nivel <= v_n then
    return (v_lista->>(p_nivel - 1))::int;
  end if;
  -- Depois da tabela: soma o incremento a cada nível (10→11 = 1350 + 350 = 1700)
  return (v_lista->>(v_n - 1))::int + (p_nivel - v_n) * v_inc;
end;
$$;

-- Pontos de atributo recebidos ao ALCANÇAR o nível p_nivel
create or replace function public.pontos_ao_alcancar(p_nivel int)
returns int
language plpgsql
stable
set search_path = ''
as $$
declare
  v_pontos jsonb := public.cfg('xp.pontos_por_nivel');
  v_limite int := (public.cfg('xp.ultimo_nivel_com_mais_pontos'))::int;
begin
  if p_nivel <= v_limite then
    return (v_pontos->>'ate_nivel_10')::int;
  end if;
  return (v_pontos->>'a_partir_nivel_11')::int;
end;
$$;

-- ---------------------------------------------------------------------------
-- Stamina
-- ---------------------------------------------------------------------------

-- Máximo de stamina do jogador: base × (1 + bônus do abrigo ativo)
create or replace function public.stamina_maxima(p_user uuid)
returns int
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_base int := (public.cfg('stamina.maxima'))::int;
  v_bonus numeric := 0;
begin
  select coalesce((s.vantagens->>'stamina_max_bonus_pct')::numeric, 0)
    into v_bonus
    from public.user_shelters us
    join public.shelters s on s.id = us.shelter_id
   where us.user_id = p_user and us.ativo
   limit 1;
  return floor(v_base * (100 + coalesce(v_bonus, 0)) / 100.0)::int;
end;
$$;

-- Cálculo puro do catch-up: quantos pontos voltaram desde p_desde.
-- Guarda a "sobra" de tempo para o próximo ponto não se perder.
create or replace function public.stamina_regenerada(
  p_atual int, p_desde timestamptz, p_max int, p_agora timestamptz, p_minutos_por_ponto numeric
)
returns table (stamina int, desde timestamptz)
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_seg_por_ponto numeric := p_minutos_por_ponto * 60;
  v_decorrido numeric := greatest(0, extract(epoch from (p_agora - p_desde)));
  v_pontos int;
  v_novo int;
begin
  if p_atual >= p_max then
    -- Já está cheia: o relógio de recarga recomeça agora
    return query select p_atual, p_agora;
    return;
  end if;
  v_pontos := floor(v_decorrido / v_seg_por_ponto)::int;
  v_novo := least(p_max, p_atual + v_pontos);
  if v_novo >= p_max then
    return query select v_novo, p_agora;
  else
    return query select v_novo, p_desde + make_interval(secs => (v_pontos * v_seg_por_ponto)::double precision);
  end if;
end;
$$;

-- Aplica o catch-up de stamina na linha do personagem (precisa estar travada com FOR UPDATE)
create or replace function public.aplicar_catchup_stamina(p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  c public.characters%rowtype;
  r record;
begin
  select * into c from public.characters where user_id = p_user for update;
  if not found then
    return;
  end if;
  select * into r from public.stamina_regenerada(
    c.stamina_atual, c.stamina_atualizada_em, public.stamina_maxima(p_user), now(),
    (public.cfg('stamina.minutos_por_ponto'))::numeric
  );
  update public.characters
     set stamina_atual = r.stamina, stamina_atualizada_em = r.desde, ultimo_tick_em = now()
   where id = c.id;
end;
$$;

-- Gasta stamina (usada pelas expedições na Fase 5). Erro amigável se faltar.
create or replace function public.gastar_stamina(p_user uuid, p_custo int)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_atual int;
  v_max int := public.stamina_maxima(p_user);
begin
  if p_custo < 0 then
    raise exception 'Custo de stamina inválido.';
  end if;
  perform public.aplicar_catchup_stamina(p_user);
  select stamina_atual into v_atual from public.characters where user_id = p_user for update;
  if v_atual is null then
    raise exception 'Personagem não encontrado.';
  end if;
  if v_atual < p_custo then
    raise exception 'Stamina insuficiente.';
  end if;
  -- Se estava cheia, a recarga começa a contar a partir de agora
  update public.characters
     set stamina_atual = v_atual - p_custo,
         stamina_atualizada_em = case when v_atual >= v_max then now() else stamina_atualizada_em end
   where user_id = p_user;
  return v_atual - p_custo;
end;
$$;

-- Recupera stamina (comida/água na Fase 6). Nunca passa do máximo.
create or replace function public.recuperar_stamina(p_user uuid, p_qtd int)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_novo int;
  v_max int := public.stamina_maxima(p_user);
begin
  perform public.aplicar_catchup_stamina(p_user);
  update public.characters
     set stamina_atual = least(v_max, greatest(stamina_atual, 0) + greatest(p_qtd, 0)),
         stamina_atualizada_em = case when least(v_max, stamina_atual + greatest(p_qtd, 0)) >= v_max then now() else stamina_atualizada_em end
   where user_id = p_user
  returning stamina_atual into v_novo;
  return v_novo;
end;
$$;

-- ---------------------------------------------------------------------------
-- Moral e XP (usadas por missões e eventos nas próximas fases)
-- ---------------------------------------------------------------------------

-- Soma (ou subtrai) moral, sempre entre 0 e 100
create or replace function public.ajustar_moral(p_user uuid, p_delta int, p_motivo text default null)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_nova int;
begin
  update public.characters
     set moral = least(100, greatest(0, moral + p_delta))
   where user_id = p_user
  returning moral into v_nova;
  if v_nova is null then
    raise exception 'Personagem não encontrado.';
  end if;
  if p_motivo is not null then
    insert into public.game_log (user_id, tipo, texto, dados)
    values (p_user, 'moral', p_motivo, jsonb_build_object('delta', p_delta, 'moral', v_nova));
  end if;
  return v_nova;
end;
$$;

-- Dá XP (já com o xp_multiplier) e sobe quantos níveis couberem.
-- XP guardado é o do nível atual: ao subir, desconta o necessário e mantém a sobra.
create or replace function public.conceder_xp(p_user uuid, p_xp_base int)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c public.characters%rowtype;
  v_ganho int;
  v_xp int;
  v_nivel int;
  v_pontos int := 0;
  v_niveis int := 0;
  v_necessario int;
begin
  if p_xp_base < 0 then
    raise exception 'XP inválido.';
  end if;
  select * into c from public.characters where user_id = p_user for update;
  if not found then
    raise exception 'Personagem não encontrado.';
  end if;

  -- Gancho futuro: XP final = XP base × xp_multiplier (padrão 1.0, sem interface de boost)
  v_ganho := floor(p_xp_base * c.xp_multiplier)::int;
  v_xp := c.xp + v_ganho;
  v_nivel := c.nivel;

  loop
    v_necessario := public.xp_para_subir(v_nivel);
    exit when v_xp < v_necessario;
    v_xp := v_xp - v_necessario;
    v_nivel := v_nivel + 1;
    v_niveis := v_niveis + 1;
    v_pontos := v_pontos + public.pontos_ao_alcancar(v_nivel);
  end loop;

  update public.characters
     set xp = v_xp, nivel = v_nivel, pontos_disponiveis = pontos_disponiveis + v_pontos
   where id = c.id;

  if v_niveis > 0 then
    insert into public.game_log (user_id, tipo, texto, dados)
    values (p_user, 'nivel', format('Subiu para o nível %s. Ainda vivo, o que já é muito.', v_nivel),
            jsonb_build_object('nivel', v_nivel, 'pontos', v_pontos));
  end if;

  return jsonb_build_object('xp_ganho', v_ganho, 'niveis_ganhos', v_niveis, 'pontos_ganhos', v_pontos, 'nivel', v_nivel, 'xp', v_xp);
end;
$$;

-- ---------------------------------------------------------------------------
-- Estado completo do personagem (o que a tela precisa para desenhar)
-- ---------------------------------------------------------------------------
create or replace function public.estado_personagem(p_user uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c public.characters%rowtype;
  v_nome text;
begin
  select * into c from public.characters where user_id = p_user;
  if not found then
    return null;
  end if;
  select nome_sobrevivente into v_nome from public.profiles where id = p_user;

  return jsonb_build_object(
    'nome', v_nome,
    'nivel', c.nivel,
    'nivel_anunciado', c.nivel_anunciado,
    'xp', c.xp,
    'xp_proximo', public.xp_para_subir(c.nivel),
    'pontos_disponiveis', c.pontos_disponiveis,
    'atributos', jsonb_build_object(
      'forca', c.forca, 'agilidade', c.agilidade, 'percepcao', c.percepcao,
      'medicina', c.medicina, 'engenharia', c.engenharia, 'lideranca', c.lideranca
    ),
    'atributo_maximo', (public.cfg('atributos.maximo'))::int,
    'moral', c.moral,
    'stamina_atual', c.stamina_atual,
    'stamina_maxima', public.stamina_maxima(p_user),
    'stamina_atualizada_em', c.stamina_atualizada_em,
    'segundos_por_ponto', (public.cfg('stamina.minutos_por_ponto'))::numeric * 60,
    'tutorial_etapa', c.tutorial_etapa,
    'stats', c.stats,
    'criado_em', c.criado_em,
    'dias_jogo_por_hora_real', (public.cfg('tempo.dias_jogo_por_hora_real'))::numeric,
    'hora_inicial', (public.cfg('tempo.hora_inicial'))::numeric,
    'moral_divisor', (public.cfg('moral.divisor_modificador'))::numeric,
    'servidor_agora', now()
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Ações que o jogador pode pedir (chamadas pelo site)
-- ---------------------------------------------------------------------------

-- Ao abrir o jogo: aplica o catch-up e devolve o estado. Null = ainda não criou personagem.
create or replace function public.sincronizar_estado()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'Sessão expirada. Entre de novo.';
  end if;
  perform public.aplicar_catchup_stamina(v_user);
  return public.estado_personagem(v_user);
end;
$$;

-- Criação: distribuir os pontos iniciais (padrão: 12 pontos, mínimo 1 e máximo 3 em cada)
create or replace function public.criar_personagem(
  p_forca int, p_agilidade int, p_percepcao int, p_medicina int, p_engenharia int, p_lideranca int
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_total int := (public.cfg('atributos.pontos_na_criacao'))::int;
  v_min int := (public.cfg('atributos.minimo_na_criacao'))::int;
  v_max int := (public.cfg('atributos.maximo_na_criacao'))::int;
  v_valores int[] := array[p_forca, p_agilidade, p_percepcao, p_medicina, p_engenharia, p_lideranca];
  v int;
  v_soma int := 0;
begin
  if v_user is null then
    raise exception 'Sessão expirada. Entre de novo.';
  end if;
  if not exists (select 1 from public.profiles where id = v_user) then
    raise exception 'Perfil não encontrado. Saia e entre de novo.';
  end if;
  if exists (select 1 from public.characters where user_id = v_user) then
    raise exception 'Você já tem um personagem.';
  end if;

  foreach v in array v_valores loop
    if v is null or v < v_min or v > v_max then
      raise exception 'Cada atributo deve ficar entre % e %.', v_min, v_max;
    end if;
    v_soma := v_soma + v;
  end loop;
  if v_soma <> v_total then
    raise exception 'Distribua exatamente % pontos.', v_total;
  end if;

  insert into public.characters (
    user_id, forca, agilidade, percepcao, medicina, engenharia, lideranca,
    moral, stamina_atual, stamina_atualizada_em, stats
  ) values (
    v_user, p_forca, p_agilidade, p_percepcao, p_medicina, p_engenharia, p_lideranca,
    (public.cfg('moral.inicial'))::int, (public.cfg('stamina.inicial'))::int, now(),
    jsonb_build_object('missoes', 0, 'sucessos', 0, 'falhas', 0, 'sobreviventes_salvos', 0, 'zumbis_abatidos', 0)
  )
  on conflict (user_id) do nothing;

  if not found then
    raise exception 'Você já tem um personagem.';
  end if;

  insert into public.game_log (user_id, tipo, texto)
  values (v_user, 'personagem', 'Você abriu os olhos. O mundo acabou. Você, por enquanto, não.');

  return public.estado_personagem(v_user);
end;
$$;

-- Distribuir pontos ganhos ao subir de nível. Recebe quanto SOMAR em cada atributo.
create or replace function public.distribuir_pontos(
  p_forca int, p_agilidade int, p_percepcao int, p_medicina int, p_engenharia int, p_lideranca int
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  c public.characters%rowtype;
  v_max int := (public.cfg('atributos.maximo'))::int;
  v_deltas int[] := array[p_forca, p_agilidade, p_percepcao, p_medicina, p_engenharia, p_lideranca];
  v int;
  v_soma int := 0;
begin
  if v_user is null then
    raise exception 'Sessão expirada. Entre de novo.';
  end if;

  -- Trava a linha: dois cliques ao mesmo tempo não gastam o mesmo ponto duas vezes
  select * into c from public.characters where user_id = v_user for update;
  if not found then
    raise exception 'Personagem não encontrado.';
  end if;

  foreach v in array v_deltas loop
    if v is null or v < 0 then
      raise exception 'Valores inválidos.';
    end if;
    v_soma := v_soma + v;
  end loop;
  if v_soma = 0 then
    raise exception 'Escolha pelo menos 1 ponto.';
  end if;
  if v_soma > c.pontos_disponiveis then
    raise exception 'Você não tem pontos suficientes.';
  end if;
  if c.forca + p_forca > v_max or c.agilidade + p_agilidade > v_max or c.percepcao + p_percepcao > v_max
     or c.medicina + p_medicina > v_max or c.engenharia + p_engenharia > v_max or c.lideranca + p_lideranca > v_max then
    raise exception 'Nenhum atributo pode passar de %.', v_max;
  end if;

  update public.characters
     set forca = forca + p_forca, agilidade = agilidade + p_agilidade, percepcao = percepcao + p_percepcao,
         medicina = medicina + p_medicina, engenharia = engenharia + p_engenharia, lideranca = lideranca + p_lideranca,
         pontos_disponiveis = pontos_disponiveis - v_soma
   where id = c.id;

  insert into public.game_log (user_id, tipo, texto, dados)
  values (v_user, 'pontos', format('Distribuiu %s ponto(s) de atributo.', v_soma),
          jsonb_build_object('forca', p_forca, 'agilidade', p_agilidade, 'percepcao', p_percepcao,
                             'medicina', p_medicina, 'engenharia', p_engenharia, 'lideranca', p_lideranca));

  return public.estado_personagem(v_user);
end;
$$;

-- Marca que o jogador já viu a animação de subida de nível
create or replace function public.marcar_nivel_visto()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Sessão expirada. Entre de novo.';
  end if;
  update public.characters set nivel_anunciado = nivel where user_id = auth.uid();
end;
$$;

-- ---------------------------------------------------------------------------
-- Permissões: o Supabase libera funções novas para todos por padrão. Aqui fechamos tudo
-- e abrimos só as 4 ações do jogador. As funções internas (conceder_xp, gastar_stamina...)
-- só podem ser chamadas por outras funções do banco, nunca direto pelo site.
-- ---------------------------------------------------------------------------
revoke all on function public.cfg(text) from public, anon, authenticated;
revoke all on function public.xp_para_subir(int) from public, anon, authenticated;
revoke all on function public.pontos_ao_alcancar(int) from public, anon, authenticated;
revoke all on function public.stamina_maxima(uuid) from public, anon, authenticated;
revoke all on function public.stamina_regenerada(int, timestamptz, int, timestamptz, numeric) from public, anon, authenticated;
revoke all on function public.aplicar_catchup_stamina(uuid) from public, anon, authenticated;
revoke all on function public.gastar_stamina(uuid, int) from public, anon, authenticated;
revoke all on function public.recuperar_stamina(uuid, int) from public, anon, authenticated;
revoke all on function public.ajustar_moral(uuid, int, text) from public, anon, authenticated;
revoke all on function public.conceder_xp(uuid, int) from public, anon, authenticated;
revoke all on function public.estado_personagem(uuid) from public, anon, authenticated;
revoke all on function public.sincronizar_estado() from public, anon, authenticated;
revoke all on function public.criar_personagem(int, int, int, int, int, int) from public, anon, authenticated;
revoke all on function public.distribuir_pontos(int, int, int, int, int, int) from public, anon, authenticated;
revoke all on function public.marcar_nivel_visto() from public, anon, authenticated;

grant execute on function public.sincronizar_estado() to authenticated;
grant execute on function public.criar_personagem(int, int, int, int, int, int) to authenticated;
grant execute on function public.distribuir_pontos(int, int, int, int, int, int) to authenticated;
grant execute on function public.marcar_nivel_visto() to authenticated;

-- ======== migrations/0007_mundo.sql ========
-- 0007: MUNDO E MISSÕES (Fase 4)
-- Desbloqueio de regiões, requisitos de missão, custo de stamina, chance estimada (só em FAIXA),
-- cooldown (esgotamento) de local e capacidade de carga.
-- Tudo calculado aqui no banco; o site recebe só o resultado. Pode rodar mais de uma vez.

-- Colunas novas no catálogo de missões
alter table public.missions add column if not exists ponto text;                       -- ponto dentro do local (ex.: "Posto de gasolina")
alter table public.missions add column if not exists especial jsonb not null default '{}'::jsonb; -- riscos, ruído, chance de recruta...
alter table public.missions add column if not exists ordem int not null default 0;
create index if not exists idx_location_cooldowns_user on public.location_cooldowns(user_id);

-- Chaves novas de configuração (não sobrescreve se você já editou)
insert into public.game_config (chave, valor, descricao, provisorio) values
  ('missao.faixas_chance', '{"segura":70,"equilibrada":45,"arriscada":25}',
   'Chance mínima (%) de cada faixa mostrada ao jogador. Abaixo de "arriscada" vira "Muito arriscada". O número nunca aparece.', true)
on conflict (chave) do nothing;

-- ---------------------------------------------------------------------------
-- Atributos efetivos: base + bônus percentuais do abrigo ativo
-- (Oficina: +10% Engenharia; Trailer: +5% Agilidade na Periferia).
-- Instalações e equipamento entram nas Fases 6 e 7.
-- ---------------------------------------------------------------------------
create or replace function public.atributos_efetivos(p_user uuid, p_regiao_slug text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c public.characters%rowtype;
  v jsonb := '{}'::jsonb;
  v_eng numeric := 0;
  v_agi numeric := 0;
begin
  select * into c from public.characters where user_id = p_user;
  if not found then
    return null;
  end if;
  select coalesce((s.vantagens->>'engenharia_bonus_pct')::numeric, 0),
         case when p_regiao_slug = 'periferia' then coalesce((s.vantagens->>'agilidade_bonus_pct_periferia')::numeric, 0) else 0 end
    into v_eng, v_agi
    from public.user_shelters us join public.shelters s on s.id = us.shelter_id
   where us.user_id = p_user and us.ativo
   limit 1;

  return jsonb_build_object(
    'forca', c.forca,
    'agilidade', round(c.agilidade * (100 + coalesce(v_agi, 0)) / 100.0, 2),
    'percepcao', c.percepcao,
    'medicina', c.medicina,
    'engenharia', round(c.engenharia * (100 + coalesce(v_eng, 0)) / 100.0, 2),
    'lideranca', c.lideranca
  );
end;
$$;

-- O jogador tem este item (na mochila ou no depósito)?
create or replace function public.tem_item(p_user uuid, p_slug text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.inventory i join public.items it on it.id = i.item_id
     where i.user_id = p_user and it.slug = p_slug and i.quantidade > 0
  );
$$;

-- Motivo de bloqueio da região (null = liberada)
create or replace function public.motivo_regiao_bloqueada(p_user uuid, p_region_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  r public.regions%rowtype;
  v_nivel int;
  v_partes text[] := '{}';
  v_item text;
begin
  select * into r from public.regions where id = p_region_id;
  select nivel into v_nivel from public.characters where user_id = p_user;
  if coalesce(v_nivel, 1) < r.nivel_minimo then
    v_partes := v_partes || format('nível %s', r.nivel_minimo);
  end if;
  if r.item_acesso_slug is not null and not public.tem_item(p_user, r.item_acesso_slug) then
    select nome into v_item from public.items where slug = r.item_acesso_slug;
    v_partes := v_partes || coalesce(v_item, r.item_acesso_slug);
  end if;
  if array_length(v_partes, 1) is null then
    return null;
  end if;
  return 'Requer ' || array_to_string(v_partes, ' e ');
end;
$$;

-- Custo de stamina da missão para este jogador (base + desvantagem do abrigo, se houver)
create or replace function public.custo_stamina_missao(p_user uuid, p_mission_id uuid)
returns int
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  m public.missions%rowtype;
  v_custo int;
  v_extra int := 0;
  v_removido_por text;
begin
  select * into m from public.missions where id = p_mission_id;
  v_custo := coalesce(m.custo_stamina, (public.cfg('stamina.custo_por_dificuldade')->>m.dificuldade)::int);

  -- Porão da mercearia: +1 para sair, até construir a "Saída reforçada"
  select coalesce((s.desvantagens->>'custo_stamina_saida_extra')::int, 0), s.desvantagens->>'removido_por'
    into v_extra, v_removido_por
    from public.user_shelters us join public.shelters s on s.id = us.shelter_id
   where us.user_id = p_user and us.ativo
   limit 1;
  if coalesce(v_extra, 0) > 0 and v_removido_por is not null and exists (
    select 1 from public.user_buildings ub
      join public.user_shelters us on us.id = ub.user_shelter_id
      join public.building_types bt on bt.id = ub.building_type_id
     where us.user_id = p_user and us.ativo and bt.slug = v_removido_por and ub.estado = 'ativo'
  ) then
    v_extra := 0;
  end if;
  return v_custo + coalesce(v_extra, 0);
end;
$$;

-- Chance de sucesso (P) da fórmula 6.5. INTERNA: o número nunca sai do banco.
-- P = min(95, max(5, 50 + (H − D) × 5 + B + M − I + E))
-- Nesta fase B (armas/consumíveis), I (penalidades) e E (eventos) entram como parâmetros (padrão 0).
create or replace function public.chance_missao(p_user uuid, p_mission_id uuid, p_b numeric default 0, p_i numeric default 0, p_e numeric default 0)
returns numeric
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  m public.missions%rowtype;
  v_regiao text;
  v_attr jsonb;
  v_h numeric := 0;
  v_d numeric;
  v_moral int;
  v_m numeric;
  f jsonb := public.cfg('missao.formula');
  k text;
  v_peso numeric;
begin
  select * into m from public.missions where id = p_mission_id;
  select r.slug into v_regiao from public.locations l join public.regions r on r.id = l.region_id where l.id = m.location_id;
  v_attr := public.atributos_efetivos(p_user, v_regiao);
  if v_attr is null then
    return null;
  end if;

  -- H: soma de atributo × peso (pesos em %)
  for k, v_peso in select key, value::numeric from jsonb_each_text(m.pesos) loop
    v_h := v_h + coalesce((v_attr->>k)::numeric, 0) * v_peso / 100.0;
  end loop;

  v_d := (public.cfg('missao.dificuldade_numerica')->>m.dificuldade)::numeric;
  select moral into v_moral from public.characters where user_id = p_user;
  v_m := (v_moral - 50) / (public.cfg('moral.divisor_modificador'))::numeric;

  return least((f->>'maximo')::numeric, greatest((f->>'minimo')::numeric,
    (f->>'base')::numeric + (v_h - v_d) * (f->>'peso_diferenca')::numeric + p_b + v_m - p_i + p_e));
end;
$$;

-- Converte a chance em faixa qualitativa (é só isto que o jogador vê)
create or replace function public.faixa_chance(p_chance numeric)
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  f jsonb := public.cfg('missao.faixas_chance');
begin
  if p_chance is null then return null; end if;
  if p_chance >= (f->>'segura')::numeric then return 'segura'; end if;
  if p_chance >= (f->>'equilibrada')::numeric then return 'equilibrada'; end if;
  if p_chance >= (f->>'arriscada')::numeric then return 'arriscada'; end if;
  return 'muito_arriscada';
end;
$$;

-- Capacidade de carga em expedição: base + Força × por_ponto
create or replace function public.capacidade_carga(p_user uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select (public.cfg('carga.base'))::numeric + c.forca * (public.cfg('carga.por_ponto_forca'))::numeric
    from public.characters c where c.user_id = p_user;
$$;

-- Esgota o local após um saque (usada ao terminar a expedição, Fase 5).
-- Duração em DIAS DO JOGO, convertida para tempo real pela relação do relógio.
create or replace function public.aplicar_cooldown_local(p_user uuid, p_location_id uuid, p_dificuldade text)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_dias numeric;
  v_ate timestamptz;
begin
  select coalesce(l.cooldown_dias::numeric, (public.cfg('missao.cooldown_local_dias')->>p_dificuldade)::numeric)
    into v_dias from public.locations l where l.id = p_location_id;
  if v_dias is null or v_dias <= 0 then
    return null;
  end if;
  v_ate := now() + make_interval(secs => (v_dias / (public.cfg('tempo.dias_jogo_por_hora_real'))::numeric * 3600)::double precision);

  insert into public.location_cooldowns (user_id, location_id, disponivel_em)
  values (p_user, p_location_id, v_ate)
  on conflict (user_id, location_id) do update set disponivel_em = greatest(public.location_cooldowns.disponivel_em, excluded.disponivel_em);
  return v_ate;
end;
$$;

-- ---------------------------------------------------------------------------
-- Ação do jogador: o estado do mundo para ELE (regiões, locais e missões)
-- ---------------------------------------------------------------------------
create or replace function public.estado_mundo()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_nivel int;
  v_dias_hora numeric := (public.cfg('tempo.dias_jogo_por_hora_real'))::numeric;
  v_regioes jsonb;
  v_locais jsonb;
  v_missoes jsonb;
begin
  if v_user is null then
    raise exception 'Sessão expirada. Entre de novo.';
  end if;
  select nivel into v_nivel from public.characters where user_id = v_user;
  if v_nivel is null then
    raise exception 'Personagem não encontrado.';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'slug', r.slug,
           'liberada', public.motivo_regiao_bloqueada(v_user, r.id) is null,
           'motivo', public.motivo_regiao_bloqueada(v_user, r.id)
         ) order by r.ordem), '[]'::jsonb)
    into v_regioes from public.regions r;

  -- Locais esgotados: quando voltam e quantos dias do jogo faltam
  select coalesce(jsonb_agg(jsonb_build_object(
           'slug', l.slug,
           'disponivel_em', lc.disponivel_em,
           'dias_restantes', ceil(extract(epoch from (lc.disponivel_em - now())) / 3600.0 * v_dias_hora)
         )), '[]'::jsonb)
    into v_locais
    from public.location_cooldowns lc join public.locations l on l.id = lc.location_id
   where lc.user_id = v_user and lc.disponivel_em > now();

  select coalesce(jsonb_agg(x.obj order by x.ordem_regiao, x.ordem_local, x.ordem), '[]'::jsonb)
    into v_missoes
    from (
      select r.ordem as ordem_regiao, l.ordem as ordem_local, m.ordem,
        jsonb_build_object(
          'slug', m.slug,
          'custo_stamina', public.custo_stamina_missao(v_user, m.id),
          'duracao_segundos', coalesce(m.duracao_segundos, (public.cfg('missao.duracao_segundos')->>m.dificuldade)::int),
          'xp', coalesce(m.xp_base, (public.cfg('missao.xp_base')->>m.dificuldade)::int),
          'faixa', public.faixa_chance(public.chance_missao(v_user, m.id)),
          'estado', case
             when public.motivo_regiao_bloqueada(v_user, r.id) is not null then 'bloqueada'
             when v_nivel < coalesce((m.requisitos->>'nivel')::int, 1) then 'bloqueada'
             when exists (select 1 from jsonb_array_elements_text(coalesce(m.requisitos->'itens', '[]'::jsonb)) s(slug)
                           where not public.tem_item(v_user, s.slug)) then 'bloqueada'
             when exists (select 1 from public.location_cooldowns lc
                           where lc.user_id = v_user and lc.location_id = l.id and lc.disponivel_em > now()) then 'esgotada'
             else 'disponivel' end,
          'motivo', case
             when public.motivo_regiao_bloqueada(v_user, r.id) is not null then 'Região bloqueada: ' || lower(public.motivo_regiao_bloqueada(v_user, r.id))
             when v_nivel < coalesce((m.requisitos->>'nivel')::int, 1) then format('Requer nível %s', m.requisitos->>'nivel')
             else (select 'Requer ' || string_agg(coalesce(it.nome, s.slug), ' e ')
                     from jsonb_array_elements_text(coalesce(m.requisitos->'itens', '[]'::jsonb)) s(slug)
                     left join public.items it on it.slug = s.slug
                    where not public.tem_item(v_user, s.slug)) end
        ) as obj
      from public.missions m
      join public.locations l on l.id = m.location_id
      join public.regions r on r.id = l.region_id
     where m.ativa
    ) x;

  return jsonb_build_object(
    'nivel', v_nivel,
    'regioes', v_regioes,
    'locais_esgotados', v_locais,
    'missoes', v_missoes,
    'carga_maxima', public.capacidade_carga(v_user),
    'dias_jogo_por_hora_real', v_dias_hora,
    'servidor_agora', now()
  );
end;
$$;

-- Permissões: só estado_mundo pode ser chamada pelo site. O resto é interno.
revoke all on function public.atributos_efetivos(uuid, text) from public, anon, authenticated;
revoke all on function public.tem_item(uuid, text) from public, anon, authenticated;
revoke all on function public.motivo_regiao_bloqueada(uuid, uuid) from public, anon, authenticated;
revoke all on function public.custo_stamina_missao(uuid, uuid) from public, anon, authenticated;
revoke all on function public.chance_missao(uuid, uuid, numeric, numeric, numeric) from public, anon, authenticated;
revoke all on function public.faixa_chance(numeric) from public, anon, authenticated;
revoke all on function public.capacidade_carga(uuid) from public, anon, authenticated;
revoke all on function public.aplicar_cooldown_local(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.estado_mundo() from public, anon, authenticated;
grant execute on function public.estado_mundo() to authenticated;

-- ======== migrations/0008_expedicoes.sql ========
-- 0008: EXPEDIÇÕES E EVENTOS (Fase 5)
-- Iniciar expedição, acompanhar pelo horário do banco, decidir eventos (com pausa e prazo de 24 h),
-- calcular o resultado (fórmula 6.5), loot, XP, moral, ferimentos, desgaste da arma, carga e esgotamento do local.
-- Toda decisão acontece aqui, travando as linhas para evitar duplicação. Pode rodar mais de uma vez.

-- ---------------------------------------------------------------------------
-- Colunas novas
-- ---------------------------------------------------------------------------
alter table public.characters add column if not exists ferimentos int not null default 0;
alter table public.characters add column if not exists ferimento_atualizado_em timestamptz;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'characters_ferimentos_faixa') then
    alter table public.characters add constraint characters_ferimentos_faixa check (ferimentos between 0 and 10);
  end if;
end $$;

-- Eventos podem ser restritos a categorias de missão (ex.: só coleta de combustível). Null = qualquer.
alter table public.events add column if not exists categorias text[];

alter table public.expeditions add column if not exists duracao_seg numeric not null default 0;
alter table public.expeditions add column if not exists custo_stamina int not null default 0;
alter table public.expeditions add column if not exists evento_em numeric;               -- posição do evento na barra (0 a 1)
alter table public.expeditions add column if not exists evento_aberto_em timestamptz;    -- quando a decisão começou a esperar
alter table public.expeditions add column if not exists evento_escolha int;
alter table public.expeditions add column if not exists evento_resultado jsonb;
alter table public.expeditions add column if not exists pausa_seg numeric not null default 0;
alter table public.expeditions add column if not exists log jsonb not null default '[]'::jsonb;
alter table public.expeditions add column if not exists carga_max numeric not null default 0;
alter table public.expeditions add column if not exists peso_levado numeric not null default 0;
alter table public.expeditions add column if not exists bonus_b numeric not null default 0;
alter table public.expeditions add column if not exists loot_entregue boolean not null default false;
alter table public.expeditions add column if not exists finalizada_em timestamptz;
alter table public.expeditions add column if not exists pulou boolean not null default false;

-- No máximo UMA expedição ativa por jogador (barra cliques duplos e abas abertas em paralelo)
create unique index if not exists uq_expedicao_ativa on public.expeditions(user_id)
  where estado in ('em_andamento', 'aguardando_evento');

-- ---------------------------------------------------------------------------
-- Configuração nova (PROVISÓRIA; não sobrescreve o que você editou)
-- ---------------------------------------------------------------------------
insert into public.game_config (chave, valor, descricao, provisorio) values
  ('missao.penalidade_por_ferimento', '5', 'I da fórmula: pontos perdidos por nível de ferimento', true),
  ('ferimento.maximo', '3', 'Níveis máximos de ferimento', true),
  ('ferimento.dias_recuperacao_por_nivel', '2', 'Dias do jogo para curar 1 nível de ferimento sozinho', true),
  ('missao.falha', '{"moral":-3,"ferimento_chance":40}', 'No fracasso: variação de moral e chance (%) de se ferir', true),
  ('missao.reducao_ferimento_pct', '{"bandagem":20,"kit_primeiros_socorros":40}', 'Quanto cada item levado reduz a chance de ferimento no fracasso', true),
  ('armas.desgaste_por_missao', '{"facil":2,"media":3,"dificil":5,"lendaria":8}', 'Durabilidade perdida pela arma por missão (dobra no fracasso)', true),
  ('eventos.ruido', '{"pct_por_nivel":5,"reducao_pct_por_agilidade":0.5}', 'Ruído aumenta a chance de evento; Agilidade reduz', true),
  ('eventos.posicao_pct', '{"min":30,"max":70}', 'Faixa da barra em que o evento acontece', true),
  ('missao.zumbis_abatidos', '{"combate":[3,8],"chefe":[1,1],"outras":[0,2]}', 'Zumbis abatidos contados nas estatísticas (mínimo e máximo)', true),
  ('missao.linhas_log', '6', 'Linhas de log mostradas por expedição', true)
on conflict (chave) do nothing;

-- Bônus de consumíveis levados na expedição (B da fórmula). Mescla com o que já existe.
update public.items set efeitos = efeitos || '{"bonus_missao":4}'::jsonb where slug = 'molotov' and not (efeitos ? 'bonus_missao');
update public.items set efeitos = efeitos || '{"bonus_missao":2}'::jsonb where slug = 'sinalizador' and not (efeitos ? 'bonus_missao');

-- ---------------------------------------------------------------------------
-- Sorteios reproduzíveis: mesma semente + mesma chave = mesmo número (auditoria)
-- ---------------------------------------------------------------------------
create or replace function public.rolar(p_seed bigint, p_chave text)
returns int language sql immutable set search_path = '' as $$
  select (('x' || substr(md5(p_seed::text || ':' || p_chave), 1, 7))::bit(28)::int % 100) + 1;
$$;

create or replace function public.rolar_entre(p_seed bigint, p_chave text, p_min int, p_max int)
returns int language sql immutable set search_path = '' as $$
  select p_min + (('x' || substr(md5(p_seed::text || ':' || p_chave), 1, 7))::bit(28)::int % (greatest(p_max, p_min) - p_min + 1));
$$;

-- ---------------------------------------------------------------------------
-- Ferimentos: curam sozinhos com o tempo do jogo (catch-up)
-- ---------------------------------------------------------------------------
create or replace function public.aplicar_catchup_ferimentos(p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  c public.characters%rowtype;
  v_dias_nivel numeric := (public.cfg('ferimento.dias_recuperacao_por_nivel'))::numeric;
  v_seg_nivel numeric;
  v_niveis int;
begin
  select * into c from public.characters where user_id = p_user for update;
  if not found or c.ferimentos = 0 or c.ferimento_atualizado_em is null then
    return;
  end if;
  v_seg_nivel := v_dias_nivel / (public.cfg('tempo.dias_jogo_por_hora_real'))::numeric * 3600;
  v_niveis := floor(greatest(0, extract(epoch from now() - c.ferimento_atualizado_em)) / v_seg_nivel)::int;
  if v_niveis > 0 then
    update public.characters
       set ferimentos = greatest(0, ferimentos - v_niveis),
           ferimento_atualizado_em = case when ferimentos - v_niveis <= 0 then null
                                          else ferimento_atualizado_em + make_interval(secs => (v_niveis * v_seg_nivel)::double precision) end
     where id = c.id;
  end if;
end;
$$;

create or replace function public.ferir(p_user uuid, p_niveis int default 1)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_novo int;
begin
  update public.characters
     set ferimentos = least((public.cfg('ferimento.maximo'))::int, ferimentos + p_niveis),
         ferimento_atualizado_em = coalesce(ferimento_atualizado_em, now())
   where user_id = p_user
  returning ferimentos into v_novo;
  return v_novo;
end;
$$;

-- ---------------------------------------------------------------------------
-- Itens: entregar na mochila e tirar da mochila
-- ---------------------------------------------------------------------------
create or replace function public.entregar_itens(p_user uuid, p_itens jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  x jsonb;
  it public.items%rowtype;
  v_qtd int;
begin
  for x in select * from jsonb_array_elements(coalesce(p_itens, '[]'::jsonb)) loop
    v_qtd := (x->>'qtd')::int;
    continue when v_qtd is null or v_qtd <= 0;
    select * into it from public.items where slug = x->>'item';
    continue when not found;
    if it.empilhavel then
      update public.inventory set quantidade = quantidade + v_qtd
       where user_id = p_user and item_id = it.id and local = 'mochila' and durabilidade is null;
      if not found then
        insert into public.inventory (user_id, item_id, local, quantidade) values (p_user, it.id, 'mochila', v_qtd);
      end if;
    else
      -- Armas: uma linha por unidade, com durabilidade cheia
      insert into public.inventory (user_id, item_id, local, quantidade, durabilidade)
      select p_user, it.id, 'mochila', 1, coalesce(it.durabilidade_max, 1) from generate_series(1, v_qtd);
    end if;
  end loop;
end;
$$;

create or replace function public.tirar_item(p_user uuid, p_slug text, p_qtd int)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_linha uuid;
  v_tem int;
  v_nome text;
begin
  select i.id, i.quantidade, it.nome into v_linha, v_tem, v_nome
    from public.inventory i join public.items it on it.id = i.item_id
   where i.user_id = p_user and it.slug = p_slug and i.local = 'mochila' and i.durabilidade is null
   for update of i;
  if v_linha is null or v_tem < p_qtd then
    if v_nome is null then select nome into v_nome from public.items where slug = p_slug; end if;
    raise exception 'Você não tem % suficiente na mochila.', coalesce(v_nome, p_slug);
  end if;
  if v_tem = p_qtd then
    delete from public.inventory where id = v_linha;
  else
    update public.inventory set quantidade = quantidade - p_qtd where id = v_linha;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Disponibilidade da missão (mesma regra da tela)
-- ---------------------------------------------------------------------------
create or replace function public.motivo_missao_indisponivel(p_user uuid, p_mission_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  m public.missions%rowtype;
  v_reg uuid;
  v_motivo text;
  v_nivel int;
  v_falta text;
begin
  select * into m from public.missions where id = p_mission_id and ativa;
  if not found then return 'Missão não encontrada.'; end if;
  select region_id into v_reg from public.locations where id = m.location_id;
  v_motivo := public.motivo_regiao_bloqueada(p_user, v_reg);
  if v_motivo is not null then return 'Região bloqueada: ' || lower(v_motivo); end if;
  select nivel into v_nivel from public.characters where user_id = p_user;
  if v_nivel < coalesce((m.requisitos->>'nivel')::int, 1) then
    return format('Requer nível %s', m.requisitos->>'nivel');
  end if;
  select string_agg(coalesce(it.nome, s.slug), ' e ') into v_falta
    from jsonb_array_elements_text(coalesce(m.requisitos->'itens', '[]'::jsonb)) s(slug)
    left join public.items it on it.slug = s.slug
   where not public.tem_item(p_user, s.slug);
  if v_falta is not null then return 'Requer ' || v_falta; end if;
  if exists (select 1 from public.location_cooldowns where user_id = p_user and location_id = m.location_id and disponivel_em > now()) then
    return 'Local esgotado por enquanto.';
  end if;
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Sorteio do evento: 70% regional (inclui eventos do local), 30% geral; sem repetir o último
-- ---------------------------------------------------------------------------
create or replace function public.escolher_evento(p_user uuid, p_mission_id uuid, p_seed bigint)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  m public.missions%rowtype;
  v_reg uuid;
  v_ultimo uuid;
  v_regional boolean;
  v_total int;
  v_alvo int;
  v_soma int := 0;
  ev record;
begin
  select * into m from public.missions where id = p_mission_id;
  select region_id into v_reg from public.locations where id = m.location_id;
  select ultimo_evento_id into v_ultimo from public.characters where user_id = p_user;

  v_regional := public.rolar(p_seed, 'pool') <= (public.cfg('eventos.peso_regional_pct'))::int;

  for i in 1..2 loop
    select coalesce(sum(e.peso), 0) into v_total
      from public.events e
     where e.ativo and e.peso > 0 and e.id is distinct from v_ultimo
       and (e.categorias is null or m.categoria = any (e.categorias))
       and case when v_regional
                then (e.escopo = 'regional' and e.region_id = v_reg) or (e.escopo = 'local' and e.location_id = m.location_id)
                else e.escopo = 'geral' end;
    exit when v_total > 0;
    v_regional := not v_regional;  -- grupo vazio: tenta o outro
  end loop;
  if v_total = 0 then
    return null;
  end if;

  v_alvo := public.rolar_entre(p_seed, 'evento_escolhido', 1, v_total);
  for ev in
    select e.id, e.peso from public.events e
     where e.ativo and e.peso > 0 and e.id is distinct from v_ultimo
       and (e.categorias is null or m.categoria = any (e.categorias))
       and case when v_regional
                then (e.escopo = 'regional' and e.region_id = v_reg) or (e.escopo = 'local' and e.location_id = m.location_id)
                else e.escopo = 'geral' end
     order by e.slug
  loop
    v_soma := v_soma + ev.peso;
    if v_soma >= v_alvo then
      return ev.id;
    end if;
  end loop;
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Estado da expedição para a tela (sem números de cálculo)
-- ---------------------------------------------------------------------------
create or replace function public.montar_estado_expedicao(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  e public.expeditions%rowtype;
  m public.missions%rowtype;
  v_local text;
  v_regiao text;
  v_evento jsonb := null;
  ev public.events%rowtype;
  v_attr jsonb;
begin
  select * into e from public.expeditions where id = p_id;
  select * into m from public.missions where id = e.mission_id;
  select l.nome, r.slug into v_local, v_regiao
    from public.locations l join public.regions r on r.id = l.region_id where l.id = m.location_id;

  if e.estado = 'aguardando_evento' and e.evento_id is not null then
    select * into ev from public.events where id = e.evento_id;
    v_attr := public.atributos_efetivos(e.user_id, v_regiao);
    select jsonb_build_object(
      'titulo', ev.titulo,
      'texto', ev.texto,
      'prazo_em', e.evento_aberto_em + make_interval(hours => (public.cfg('eventos.prazo_decisao_horas'))::int),
      'opcoes', coalesce(jsonb_agg(jsonb_build_object(
          'indice', o.idx - 1,
          'titulo', o.op->>'titulo',
          'descricao', o.op->>'descricao',
          'risco', coalesce((o.op->>'risco')::int, 1),
          'recompensa', coalesce((o.op->>'recompensa')::int, 1),
          'cautelosa', coalesce((o.op->>'cautelosa')::boolean, false),
          'custo', case
             when o.op->'custo' ? 'item' then jsonb_build_object('item', o.op->'custo'->>'item', 'qtd', coalesce((o.op->'custo'->>'qtd')::int, 1),
                    'nome', (select nome from public.items where slug = o.op->'custo'->>'item'),
                    'ok', public.tem_item(e.user_id, o.op->'custo'->>'item'))
             when o.op->'custo' ? 'stamina' then jsonb_build_object('stamina', (o.op->'custo'->>'stamina')::int)
             else null end,
          'requisito', case when o.op ? 'requisito' then jsonb_build_object(
             'atributo', o.op->'requisito'->>'atributo',
             'valor', (o.op->'requisito'->>'valor')::int,
             'ok', coalesce((v_attr->>(o.op->'requisito'->>'atributo'))::numeric, 0) >= (o.op->'requisito'->>'valor')::numeric)
             else null end
        ) order by o.idx), '[]'::jsonb)
    ) into v_evento
    from jsonb_array_elements(ev.opcoes) with ordinality as o(op, idx);
  end if;

  return jsonb_build_object(
    'id', e.id,
    'estado', e.estado,
    'missao', jsonb_build_object('slug', m.slug, 'nome', m.nome, 'dificuldade', m.dificuldade, 'categoria', m.categoria,
                                 'regiao', v_regiao, 'local', v_local, 'ponto', m.ponto),
    'iniciada_em', e.iniciada_em,
    'termina_em', e.termina_em,
    'duracao_seg', e.duracao_seg,
    'pausa_seg', e.pausa_seg,
    'evento_em', e.evento_em,
    'evento_aberto_em', e.evento_aberto_em,
    'evento_resolvido', e.evento_resolvido,
    'tem_evento', e.evento_id is not null,
    'evento', v_evento,
    'log', e.log,
    'custo_stamina', e.custo_stamina,
    'carga_max', e.carga_max,
    'peso_levado', e.peso_levado,
    'resultado', case when e.resultado is null then null else e.resultado - 'auditoria' end,
    'loot_entregue', e.loot_entregue,
    'servidor_agora', now()
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Aplica a opção escolhida no evento (pelo jogador ou automaticamente após o prazo)
-- ---------------------------------------------------------------------------
create or replace function public.aplicar_opcao_evento(p_id uuid, p_indice int, p_auto boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  e public.expeditions%rowtype;
  m public.missions%rowtype;
  ev public.events%rowtype;
  op jsonb;
  ef jsonb;
  v_regiao text;
  v_attr jsonb;
  v_moral int := 0;
  v_ferido boolean := false;
  v_itens jsonb := '[]'::jsonb;
  x jsonb;
  k int := 0;
  v_texto text;
  v_pausa numeric;
begin
  select * into e from public.expeditions where id = p_id for update;
  select * into m from public.missions where id = e.mission_id;
  select * into ev from public.events where id = e.evento_id;
  select r.slug into v_regiao from public.locations l join public.regions r on r.id = l.region_id where l.id = m.location_id;

  -- Atenção: em JSON, índice negativo conta do fim; por isso o teste explícito
  op := case when p_indice between 0 and jsonb_array_length(ev.opcoes) - 1 then ev.opcoes->p_indice else null end;
  if op is null then
    raise exception 'Opção inválida.';
  end if;
  ef := coalesce(op->'efeitos', '{}'::jsonb);

  -- Requisito de atributo
  if op ? 'requisito' then
    v_attr := public.atributos_efetivos(e.user_id, v_regiao);
    if coalesce((v_attr->>(op->'requisito'->>'atributo'))::numeric, 0) < (op->'requisito'->>'valor')::numeric then
      raise exception 'Você não tem o atributo necessário para esta opção.';
    end if;
  end if;
  -- Custo (item da mochila ou stamina)
  if op->'custo' ? 'item' then
    perform public.tirar_item(e.user_id, op->'custo'->>'item', coalesce((op->'custo'->>'qtd')::int, 1));
  elsif op->'custo' ? 'stamina' then
    perform public.gastar_stamina(e.user_id, (op->'custo'->>'stamina')::int);
  end if;

  -- Moral (deixar alguém para trás perde conforme a dificuldade, seção 6.4)
  v_moral := coalesce((ef->>'moral')::int, 0);
  if coalesce((ef->>'moral_nao_ajudar')::boolean, false) then
    v_moral := v_moral - (public.cfg('moral.perda_por_nao_ajudar')->>m.dificuldade)::int;
  end if;
  if v_moral <> 0 then
    perform public.ajustar_moral(e.user_id, v_moral, null);
  end if;

  -- Ferimento
  if coalesce((ef->>'ferimento_chance')::int, 0) > 0 and public.rolar(e.seed, 'evento_ferimento') <= (ef->>'ferimento_chance')::int then
    perform public.ferir(e.user_id, 1);
    v_ferido := true;
  end if;

  -- Itens encontrados no evento (somados ao saque no fim)
  for x in select * from jsonb_array_elements(coalesce(ef->'itens', '[]'::jsonb)) loop
    k := k + 1;
    if public.rolar(e.seed, 'evento_item' || k) <= coalesce((x->>'chance')::int, 100) then
      v_itens := v_itens || jsonb_build_array(jsonb_build_object(
        'item', x->>'item',
        'qtd', public.rolar_entre(e.seed, 'evento_qtd' || k, coalesce((x->>'min')::int, 1), coalesce((x->>'max')::int, 1))));
    end if;
  end loop;

  v_texto := coalesce(ef->>'texto', 'Você segue em frente.');
  if p_auto then
    v_texto := 'Sem resposta sua, você fez o mais cauteloso. ' || v_texto;
  end if;

  -- A barra ficou parada enquanto a decisão esperava: empurra o fim para frente
  v_pausa := greatest(0, extract(epoch from now() - coalesce(e.evento_aberto_em, now())));

  update public.expeditions
     set estado = 'em_andamento',
         evento_resolvido = true,
         evento_escolha = p_indice,
         pausa_seg = pausa_seg + v_pausa,
         termina_em = termina_em + make_interval(secs => v_pausa::double precision),
         evento_resultado = jsonb_build_object(
           'titulo', ev.titulo, 'opcao', op->>'titulo', 'texto', v_texto, 'auto', p_auto,
           'e', coalesce((op->>'e')::numeric, 0), 'moral', v_moral, 'ferido', v_ferido, 'itens', v_itens,
           'xp', coalesce((ef->>'xp')::int, 0), 'perda_loot_pct', coalesce((ef->>'perda_loot_pct')::int, 0),
           'recruta_chance', coalesce((ef->>'recruta_chance')::int, 0), 'zumbis', coalesce((ef->>'zumbis')::int, 0)),
         log = log || jsonb_build_array(jsonb_build_object('pct', e.evento_em, 'texto', v_texto, 'evento', true))
   where id = e.id;
end;
$$;

-- Atualiza a expedição pelo relógio: abre o evento quando chega a hora; aplica a opção cautelosa após o prazo
create or replace function public.atualizar_expedicao(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  e public.expeditions%rowtype;
  v_hora_evento timestamptz;
  v_cautelosa int;
begin
  select * into e from public.expeditions where id = p_id for update;
  if e.estado = 'em_andamento' and e.evento_id is not null and not e.evento_resolvido then
    v_hora_evento := e.iniciada_em + make_interval(secs => (e.evento_em * e.duracao_seg)::double precision);
    if now() >= v_hora_evento then
      update public.expeditions set estado = 'aguardando_evento', evento_aberto_em = v_hora_evento where id = e.id;
      e.estado := 'aguardando_evento';
      e.evento_aberto_em := v_hora_evento;
    end if;
  end if;

  if e.estado = 'aguardando_evento'
     and now() > e.evento_aberto_em + make_interval(hours => (public.cfg('eventos.prazo_decisao_horas'))::int) then
    -- Opção mais cautelosa: a marcada como "cautelosa"; senão a de menor risco sem requisito nem custo
    select o.idx - 1 into v_cautelosa
      from public.events ev, jsonb_array_elements(ev.opcoes) with ordinality as o(op, idx)
     where ev.id = e.evento_id and not (o.op ? 'requisito') and not (o.op ? 'custo')
     order by coalesce((o.op->>'cautelosa')::boolean, false) desc, coalesce((o.op->>'risco')::int, 1), o.idx
     limit 1;
    perform public.aplicar_opcao_evento(e.id, coalesce(v_cautelosa, 0), true);
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- AÇÕES DO JOGADOR
-- ---------------------------------------------------------------------------

-- Iniciar expedição. p_consumiveis: [{"item":"molotov","qtd":1}]
create or replace function public.iniciar_expedicao(p_missao text, p_arma uuid default null, p_consumiveis jsonb default '[]'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  c public.characters%rowtype;
  m public.missions%rowtype;
  v_motivo text;
  v_b numeric := 0;
  v_peso numeric := 0;
  v_carga numeric;
  v_arma record;
  x jsonb;
  it public.items%rowtype;
  v_qtd int;
  v_tem int;
  v_custo int;
  v_dur numeric;
  v_seed bigint := floor(random() * 9000000000000000)::bigint;
  v_prob numeric;
  v_ruido jsonb := public.cfg('eventos.ruido');
  v_evento uuid := null;
  v_pos jsonb := public.cfg('eventos.posicao_pct');
  v_evento_em numeric := null;
  v_linhas jsonb;
  v_n int := (public.cfg('missao.linhas_log'))::int;
  v_log jsonb := '[]'::jsonb;
  v_id uuid;
  v_consumiveis jsonb := '[]'::jsonb;
  v_peso_arma numeric := 0;
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;

  -- Trava o personagem: duas abas não iniciam duas expedições ao mesmo tempo
  select * into c from public.characters where user_id = v_user for update;
  if not found then raise exception 'Personagem não encontrado.'; end if;

  if exists (select 1 from public.expeditions where user_id = v_user and estado in ('em_andamento', 'aguardando_evento')) then
    raise exception 'Você já está numa expedição.';
  end if;
  if exists (select 1 from public.expeditions where user_id = v_user and estado = 'concluida' and not loot_entregue) then
    raise exception 'Decida o que levar da última expedição antes de sair de novo.';
  end if;

  select * into m from public.missions where slug = p_missao and ativa;
  if not found then raise exception 'Missão não encontrada.'; end if;
  v_motivo := public.motivo_missao_indisponivel(v_user, m.id);
  if v_motivo is not null then raise exception '%', v_motivo; end if;

  -- Arma (opcional): precisa ser sua, estar na mochila, inteira e do seu nível
  if p_arma is not null then
    select i.id, i.durabilidade, it2.nome, it2.peso, it2.nivel_requisito, it2.efeitos into v_arma
      from public.inventory i join public.items it2 on it2.id = i.item_id
     where i.id = p_arma and i.user_id = v_user and i.local = 'mochila' and it2.tipo = 'arma'
     for update of i;
    if not found then raise exception 'Arma inválida.'; end if;
    if coalesce(v_arma.durabilidade, 0) <= 0 then raise exception 'Essa arma está quebrada. Repare antes.'; end if;
    if v_arma.nivel_requisito > c.nivel then raise exception 'Essa arma exige nível %.', v_arma.nivel_requisito; end if;
    v_b := v_b + coalesce((v_arma.efeitos->>'bonus_missao')::numeric, 0);
    v_peso_arma := v_arma.peso;
    v_peso := v_peso + v_peso_arma;
  end if;

  -- Consumíveis (opcional): somam bônus e peso, e são gastos na expedição
  if jsonb_typeof(coalesce(p_consumiveis, '[]'::jsonb)) <> 'array' then raise exception 'Dados inválidos.'; end if;
  for x in select * from jsonb_array_elements(coalesce(p_consumiveis, '[]'::jsonb)) loop
    v_qtd := (x->>'qtd')::int;
    if v_qtd is null or v_qtd < 1 or v_qtd > 10 then raise exception 'Quantidade inválida.'; end if;
    select * into it from public.items where slug = x->>'item';
    if not found or it.tipo <> 'consumivel' then raise exception 'Item inválido para levar.'; end if;
    select coalesce(sum(i.quantidade), 0) into v_tem from public.inventory i
     where i.user_id = v_user and i.item_id = it.id and i.local = 'mochila';
    if v_tem < v_qtd then raise exception 'Você não tem % suficiente.', it.nome; end if;
    v_b := v_b + coalesce((it.efeitos->>'bonus_missao')::numeric, 0) * v_qtd;
    v_peso := v_peso + it.peso * v_qtd;
    v_consumiveis := v_consumiveis || jsonb_build_array(jsonb_build_object('item', it.slug, 'qtd', v_qtd));
  end loop;

  v_carga := public.capacidade_carga(v_user);
  if v_peso > v_carga then raise exception 'Peso demais para levar.'; end if;

  -- Paga a stamina (erro "Stamina insuficiente." se faltar) e gasta os consumíveis
  v_custo := public.custo_stamina_missao(v_user, m.id);
  perform public.gastar_stamina(v_user, v_custo);
  for x in select * from jsonb_array_elements(v_consumiveis) loop
    perform public.tirar_item(v_user, x->>'item', (x->>'qtd')::int);
  end loop;

  v_dur := coalesce(m.duracao_segundos, (public.cfg('missao.duracao_segundos')->>m.dificuldade)::int);

  -- Evento: chance por dificuldade + ruído − Agilidade
  v_prob := (public.cfg('eventos.probabilidade_pct')->>m.dificuldade)::numeric
          + coalesce((m.especial->>'ruido')::numeric, 0) * (v_ruido->>'pct_por_nivel')::numeric
          - c.agilidade * (v_ruido->>'reducao_pct_por_agilidade')::numeric;
  if public.rolar(v_seed, 'tem_evento') <= least(100, greatest(0, v_prob)) then
    v_evento := public.escolher_evento(v_user, m.id, v_seed);
    if v_evento is not null then
      v_evento_em := public.rolar_entre(v_seed, 'evento_pos', (v_pos->>'min')::int, (v_pos->>'max')::int) / 100.0;
    end if;
  end if;

  -- Linhas de log: sorteia a ordem e espalha pela barra
  select coalesce(jsonb_agg(t.linha order by md5(v_seed::text || t.linha)), '[]'::jsonb) into v_linhas
    from jsonb_array_elements_text(coalesce(m.textos->'log', '[]'::jsonb)) as t(linha);
  v_n := least(v_n, jsonb_array_length(v_linhas));
  for i in 0..v_n - 1 loop
    v_log := v_log || jsonb_build_array(jsonb_build_object('pct', round((i + 1)::numeric / (v_n + 1), 3), 'texto', v_linhas->>i));
  end loop;
  v_log := jsonb_build_array(jsonb_build_object('pct', 0, 'texto', coalesce(m.textos->>'abertura', 'Você sai do abrigo.'))) || v_log;

  insert into public.expeditions (
    user_id, mission_id, estado, iniciada_em, termina_em, seed, evento_id, evento_em, duracao_seg,
    custo_stamina, arma_id, consumiveis, log, carga_max, peso_levado, bonus_b
  ) values (
    v_user, m.id, 'em_andamento', now(), now() + make_interval(secs => v_dur::double precision), v_seed, v_evento, v_evento_em, v_dur,
    v_custo, p_arma, v_consumiveis, v_log, v_carga, v_peso_arma, v_b
  ) returning id into v_id;

  if v_evento is not null then
    update public.characters set ultimo_evento_id = v_evento where id = c.id;
  end if;

  insert into public.game_log (user_id, tipo, texto, dados)
  values (v_user, 'expedicao', format('Saiu em expedição: %s.', m.nome), jsonb_build_object('expedicao', v_id, 'missao', m.slug));

  return jsonb_build_object('id', v_id);
end;
$$;

-- Ver a expedição (também faz as transições pelo relógio)
create or replace function public.estado_expedicao(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;
  if not exists (select 1 from public.expeditions where id = p_id and user_id = v_user) then
    raise exception 'Expedição não encontrada.';
  end if;
  perform public.atualizar_expedicao(p_id);
  return public.montar_estado_expedicao(p_id);
end;
$$;

-- Escolher uma opção do evento
create or replace function public.resolver_evento(p_id uuid, p_opcao int)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_estado text;
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;
  select estado into v_estado from public.expeditions where id = p_id and user_id = v_user for update;
  if v_estado is null then raise exception 'Expedição não encontrada.'; end if;
  perform public.atualizar_expedicao(p_id);
  select estado into v_estado from public.expeditions where id = p_id;
  if v_estado <> 'aguardando_evento' then
    raise exception 'Não há decisão pendente nesta expedição.';
  end if;
  perform public.aplicar_opcao_evento(p_id, p_opcao, false);
  return public.montar_estado_expedicao(p_id);
end;
$$;

-- Terminar a expedição e calcular o resultado. Seguro contra cliques repetidos:
-- se já terminou, devolve o mesmo resultado sem dar nada de novo.
-- p_pular = true: não espera o tempo acabar (as regras são as mesmas; o evento, se houver, aparece antes).
create or replace function public.finalizar_expedicao(p_id uuid, p_pular boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  e public.expeditions%rowtype;
  m public.missions%rowtype;
  c public.characters%rowtype;
  f jsonb := public.cfg('missao.formula');
  v_falha jsonb := public.cfg('missao.falha');
  er jsonb;
  v_regiao text;
  v_i numeric;
  v_e numeric;
  v_p numeric;
  v_roll int;
  v_desfecho text;
  v_pct_loot numeric;
  v_loot jsonb := '{}'::jsonb;    -- {"slug": qtd}
  x jsonb;
  k int := 0;
  v_qtd int;
  v_lista jsonb := '[]'::jsonb;
  v_peso numeric := 0;
  v_disponivel numeric;
  v_xp_base int;
  v_xp_pct numeric;
  v_xp jsonb;
  v_moral int := 0;
  v_ferido boolean := false;
  v_chance_fer numeric;
  v_red jsonb := public.cfg('missao.reducao_ferimento_pct');
  v_desgaste int;
  v_arma_dur int := null;
  v_zumbis jsonb := public.cfg('missao.zumbis_abatidos');
  v_z jsonb;
  v_abatidos int;
  v_salvos int := 0;
  v_recruta boolean := false;
  v_resultado jsonb;
  v_excesso boolean;
  v_texto text;
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;
  select * into e from public.expeditions where id = p_id and user_id = v_user for update;
  if not found then raise exception 'Expedição não encontrada.'; end if;

  -- Já terminou: devolve o mesmo resultado (idempotente)
  if e.estado in ('concluida', 'expirada') then
    return public.montar_estado_expedicao(p_id);
  end if;

  perform public.atualizar_expedicao(p_id);
  select * into e from public.expeditions where id = p_id;

  if e.estado = 'aguardando_evento' then
    raise exception 'Decida o que fazer no evento primeiro.';
  end if;
  -- Evento ainda não aconteceu
  if e.evento_id is not null and not e.evento_resolvido then
    if p_pular then
      update public.expeditions set estado = 'aguardando_evento', evento_aberto_em = now() where id = e.id;
      return public.montar_estado_expedicao(p_id);
    end if;
    raise exception 'A expedição ainda não terminou.';
  end if;
  if now() < e.termina_em and not p_pular then
    raise exception 'A expedição ainda não terminou.';
  end if;

  perform public.aplicar_catchup_ferimentos(v_user);
  select * into c from public.characters where user_id = v_user for update;
  select * into m from public.missions where id = e.mission_id;
  select r.slug into v_regiao from public.locations l join public.regions r on r.id = l.region_id where l.id = m.location_id;
  er := coalesce(e.evento_resultado, '{}'::jsonb);

  -- Fórmula 6.5 (o número fica só na auditoria)
  v_i := c.ferimentos * (public.cfg('missao.penalidade_por_ferimento'))::numeric;
  v_e := coalesce((er->>'e')::numeric, 0);
  v_p := public.chance_missao(v_user, m.id, e.bonus_b, v_i, v_e);
  v_roll := public.rolar(e.seed, 'resultado');
  v_desfecho := case when v_roll <= v_p then 'total'
                     when v_roll <= v_p + (f->>'margem_parcial')::numeric then 'parcial'
                     else 'fracasso' end;

  -- Saque
  v_pct_loot := case v_desfecho when 'total' then 100 when 'parcial' then (f->>'parcial_loot_pct')::numeric else 0 end;
  if v_pct_loot > 0 then
    for x in select * from jsonb_array_elements(m.loot) loop
      k := k + 1;
      if public.rolar(e.seed, 'loot' || k) <= coalesce((x->>'chance')::int, 100) then
        v_qtd := floor(public.rolar_entre(e.seed, 'qtd' || k, coalesce((x->>'min')::int, 1), coalesce((x->>'max')::int, 1)) * v_pct_loot / 100.0);
        if v_qtd > 0 then
          v_loot := jsonb_set(v_loot, array[x->>'item'], to_jsonb(coalesce((v_loot->>(x->>'item'))::int, 0) + v_qtd));
        end if;
      end if;
    end loop;
    -- Itens achados no evento
    for x in select * from jsonb_array_elements(coalesce(er->'itens', '[]'::jsonb)) loop
      v_loot := jsonb_set(v_loot, array[x->>'item'], to_jsonb(coalesce((v_loot->>(x->>'item'))::int, 0) + (x->>'qtd')::int));
    end loop;
    -- Perda do evento (ex.: vazamento)
    if coalesce((er->>'perda_loot_pct')::int, 0) > 0 then
      select coalesce(jsonb_object_agg(key, floor(value::numeric * (100 - (er->>'perda_loot_pct')::int) / 100.0)), '{}'::jsonb)
        into v_loot from jsonb_each_text(v_loot);
    end if;
  end if;

  -- Lista final com pesos
  select coalesce(jsonb_agg(jsonb_build_object('item', l.key, 'qtd', l.value::int, 'nome', it.nome, 'tipo', it.tipo,
                                               'raridade', it.raridade, 'peso', it.peso) order by it.tipo, it.nome), '[]'::jsonb),
         coalesce(sum(l.value::int * it.peso), 0)
    into v_lista, v_peso
    from jsonb_each_text(v_loot) l join public.items it on it.slug = l.key
   where l.value::int > 0;
  v_disponivel := greatest(0, e.carga_max - e.peso_levado);
  v_excesso := v_peso > v_disponivel;

  -- XP (já com xp_multiplier dentro de conceder_xp)
  v_xp_base := coalesce(m.xp_base, (public.cfg('missao.xp_base')->>m.dificuldade)::int);
  v_xp_pct := case v_desfecho when 'total' then 100 when 'parcial' then (f->>'parcial_xp_pct')::numeric else (f->>'falha_xp_pct')::numeric end;
  v_xp := public.conceder_xp(v_user, floor(v_xp_base * v_xp_pct / 100.0)::int + coalesce((er->>'xp')::int, 0));

  -- Moral
  if v_desfecho = 'total' and m.dificuldade = 'facil' then
    v_moral := (public.cfg('moral.bonus_sucesso_facil'))::int;
  elsif v_desfecho = 'fracasso' then
    v_moral := (v_falha->>'moral')::int;
  end if;
  if v_moral <> 0 then perform public.ajustar_moral(v_user, v_moral, null); end if;

  -- Ferimento no fracasso (bandagem e kit levados reduzem a chance)
  if v_desfecho = 'fracasso' then
    v_chance_fer := (v_falha->>'ferimento_chance')::numeric;
    for x in select * from jsonb_array_elements(e.consumiveis) loop
      v_chance_fer := v_chance_fer - coalesce((v_red->>(x->>'item'))::numeric, 0) * (x->>'qtd')::int;
    end loop;
    if public.rolar(e.seed, 'ferimento') <= v_chance_fer then
      perform public.ferir(v_user, 1);
      v_ferido := true;
    end if;
  end if;

  -- Desgaste da arma levada
  if e.arma_id is not null then
    v_desgaste := (public.cfg('armas.desgaste_por_missao')->>m.dificuldade)::int * case when v_desfecho = 'fracasso' then 2 else 1 end;
    update public.inventory set durabilidade = greatest(0, coalesce(durabilidade, 0) - v_desgaste)
     where id = e.arma_id and user_id = v_user
    returning durabilidade into v_arma_dur;
  end if;

  -- Estatísticas
  v_z := coalesce(v_zumbis->(case when m.categoria in ('combate', 'chefe') then m.categoria else 'outras' end), '[0,0]'::jsonb);
  v_abatidos := case when v_desfecho = 'fracasso' then 0
                     else public.rolar_entre(e.seed, 'zumbis', (v_z->>0)::int, (v_z->>1)::int) + coalesce((er->>'zumbis')::int, 0) end;
  if m.categoria = 'resgate' and v_desfecho <> 'fracasso' then
    v_salvos := 1;
    v_recruta := public.rolar(e.seed, 'recruta') <= coalesce((m.especial->>'recruta_chance')::int, 0);
  end if;
  if v_desfecho <> 'fracasso' and coalesce((er->>'recruta_chance')::int, 0) > 0
     and public.rolar(e.seed, 'recruta_evento') <= (er->>'recruta_chance')::int then
    v_salvos := v_salvos + 1;
    v_recruta := true;
  end if;
  update public.characters set stats = jsonb_build_object(
      'missoes', coalesce((stats->>'missoes')::int, 0) + 1,
      'sucessos', coalesce((stats->>'sucessos')::int, 0) + case when v_desfecho = 'fracasso' then 0 else 1 end,
      'falhas', coalesce((stats->>'falhas')::int, 0) + case when v_desfecho = 'fracasso' then 1 else 0 end,
      'sobreviventes_salvos', coalesce((stats->>'sobreviventes_salvos')::int, 0) + v_salvos,
      'zumbis_abatidos', coalesce((stats->>'zumbis_abatidos')::int, 0) + v_abatidos)
   where id = c.id;

  -- Local esgotado por alguns dias do jogo (todas as missões dele)
  perform public.aplicar_cooldown_local(v_user, m.location_id, m.dificuldade);

  v_texto := case v_desfecho
    when 'total' then 'Você volta com tudo e com todos os dedos.'
    when 'parcial' then 'Deu para trazer alguma coisa. Já é mais do que muita gente.'
    else 'Você volta de mãos vazias, mas volta.' end;

  v_resultado := jsonb_build_object(
    'desfecho', v_desfecho,
    'texto', v_texto,
    'loot', v_lista,
    'peso_loot', v_peso,
    'carga_disponivel', v_disponivel,
    'excesso', v_excesso,
    'xp_ganho', (v_xp->>'xp_ganho')::int,
    'niveis_ganhos', (v_xp->>'niveis_ganhos')::int,
    'moral', v_moral + coalesce((er->>'moral')::int, 0),
    'ferido', v_ferido or coalesce((er->>'ferido')::boolean, false),
    'ferimentos', (select ferimentos from public.characters where id = c.id),
    'stamina_gasta', e.custo_stamina,
    'arma_durabilidade', v_arma_dur,
    'zumbis', v_abatidos,
    'recruta_encontrado', v_recruta,
    'evento', case when e.evento_id is null then null else jsonb_build_object('titulo', er->>'titulo', 'opcao', er->>'opcao', 'texto', er->>'texto') end,
    -- Auditoria: valores usados (NUNCA vai para a tela)
    'auditoria', jsonb_build_object('seed', e.seed, 'rolagem', v_roll, 'p', v_p, 'b', e.bonus_b, 'i', v_i, 'e', v_e,
                                    'm', (c.moral - 50) / (public.cfg('moral.divisor_modificador'))::numeric)
  );

  update public.expeditions
     set estado = 'concluida', resultado = v_resultado, finalizada_em = now(), pulou = p_pular,
         log = log || jsonb_build_array(jsonb_build_object('pct', 1, 'fim', true, 'texto',
                 case v_desfecho when 'total' then 'Sucesso total. ' when 'parcial' then 'Sucesso parcial. ' else 'Fracasso. ' end || v_texto))
   where id = e.id;

  -- Sem excesso de peso: o saque vai direto para a mochila
  if not v_excesso then
    perform public.entregar_itens(v_user, (select coalesce(jsonb_agg(jsonb_build_object('item', l->>'item', 'qtd', (l->>'qtd')::int)), '[]'::jsonb)
                                            from jsonb_array_elements(v_lista) l));
    update public.expeditions set loot_entregue = true where id = e.id;
  end if;

  insert into public.game_log (user_id, tipo, texto, dados)
  values (v_user, 'expedicao',
          format('%s: %s.', m.nome, case v_desfecho when 'total' then 'sucesso total' when 'parcial' then 'sucesso parcial' else 'fracasso' end),
          jsonb_build_object('expedicao', e.id, 'desfecho', v_desfecho));

  return public.montar_estado_expedicao(p_id);
end;
$$;

-- Escolher o que levar quando o saque passa da capacidade. p_escolha: {"madeira": 3, "metal": 1}
create or replace function public.confirmar_loot(p_id uuid, p_escolha jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  e public.expeditions%rowtype;
  v_itens jsonb := '[]'::jsonb;
  v_peso numeric := 0;
  l jsonb;
  v_qtd int;
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;
  select * into e from public.expeditions where id = p_id and user_id = v_user for update;
  if not found then raise exception 'Expedição não encontrada.'; end if;
  if e.estado <> 'concluida' then raise exception 'A expedição ainda não terminou.'; end if;
  if e.loot_entregue then
    return public.montar_estado_expedicao(p_id);  -- já entregue: não entrega de novo
  end if;
  if jsonb_typeof(p_escolha) <> 'object' then raise exception 'Dados inválidos.'; end if;

  for l in select * from jsonb_array_elements(e.resultado->'loot') loop
    v_qtd := coalesce((p_escolha->>(l->>'item'))::int, 0);
    if v_qtd < 0 or v_qtd > (l->>'qtd')::int then raise exception 'Quantidade inválida.'; end if;
    if v_qtd > 0 then
      v_itens := v_itens || jsonb_build_array(jsonb_build_object('item', l->>'item', 'qtd', v_qtd));
      v_peso := v_peso + v_qtd * (l->>'peso')::numeric;
    end if;
  end loop;
  if v_peso > (e.resultado->>'carga_disponivel')::numeric then
    raise exception 'Ainda está pesado demais. Deixe mais coisas para trás.';
  end if;

  perform public.entregar_itens(v_user, v_itens);
  update public.expeditions
     set loot_entregue = true, resultado = resultado || jsonb_build_object('levado', v_itens)
   where id = e.id;
  return public.montar_estado_expedicao(p_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Estado do personagem agora inclui ferimentos e a expedição ativa (para "Retomar")
-- ---------------------------------------------------------------------------
create or replace function public.estado_personagem(p_user uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c public.characters%rowtype;
  v_nome text;
  v_exp jsonb;
begin
  select * into c from public.characters where user_id = p_user;
  if not found then
    return null;
  end if;
  select nome_sobrevivente into v_nome from public.profiles where id = p_user;
  select jsonb_build_object('id', e.id, 'estado', e.estado, 'missao', m.nome, 'termina_em', e.termina_em,
                            'loot_pendente', e.estado = 'concluida' and not e.loot_entregue)
    into v_exp
    from public.expeditions e join public.missions m on m.id = e.mission_id
   where e.user_id = p_user and (e.estado in ('em_andamento', 'aguardando_evento') or (e.estado = 'concluida' and not e.loot_entregue))
   order by e.iniciada_em desc
   limit 1;

  return jsonb_build_object(
    'nome', v_nome,
    'nivel', c.nivel,
    'nivel_anunciado', c.nivel_anunciado,
    'xp', c.xp,
    'xp_proximo', public.xp_para_subir(c.nivel),
    'pontos_disponiveis', c.pontos_disponiveis,
    'atributos', jsonb_build_object(
      'forca', c.forca, 'agilidade', c.agilidade, 'percepcao', c.percepcao,
      'medicina', c.medicina, 'engenharia', c.engenharia, 'lideranca', c.lideranca
    ),
    'atributo_maximo', (public.cfg('atributos.maximo'))::int,
    'moral', c.moral,
    'stamina_atual', c.stamina_atual,
    'stamina_maxima', public.stamina_maxima(p_user),
    'stamina_atualizada_em', c.stamina_atualizada_em,
    'segundos_por_ponto', (public.cfg('stamina.minutos_por_ponto'))::numeric * 60,
    'tutorial_etapa', c.tutorial_etapa,
    'stats', c.stats,
    'criado_em', c.criado_em,
    'dias_jogo_por_hora_real', (public.cfg('tempo.dias_jogo_por_hora_real'))::numeric,
    'hora_inicial', (public.cfg('tempo.hora_inicial'))::numeric,
    'moral_divisor', (public.cfg('moral.divisor_modificador'))::numeric,
    'ferimentos', c.ferimentos,
    'expedicao', v_exp,
    'servidor_agora', now()
  );
end;
$$;

create or replace function public.sincronizar_estado()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'Sessão expirada. Entre de novo.';
  end if;
  perform public.aplicar_catchup_stamina(v_user);
  perform public.aplicar_catchup_ferimentos(v_user);
  return public.estado_personagem(v_user);
end;
$$;

-- ---------------------------------------------------------------------------
-- Permissões: só as 5 ações de expedição (e sincronizar) ficam abertas ao site
-- ---------------------------------------------------------------------------
revoke all on function public.rolar(bigint, text) from public, anon, authenticated;
revoke all on function public.rolar_entre(bigint, text, int, int) from public, anon, authenticated;
revoke all on function public.aplicar_catchup_ferimentos(uuid) from public, anon, authenticated;
revoke all on function public.ferir(uuid, int) from public, anon, authenticated;
revoke all on function public.entregar_itens(uuid, jsonb) from public, anon, authenticated;
revoke all on function public.tirar_item(uuid, text, int) from public, anon, authenticated;
revoke all on function public.motivo_missao_indisponivel(uuid, uuid) from public, anon, authenticated;
revoke all on function public.escolher_evento(uuid, uuid, bigint) from public, anon, authenticated;
revoke all on function public.montar_estado_expedicao(uuid) from public, anon, authenticated;
revoke all on function public.aplicar_opcao_evento(uuid, int, boolean) from public, anon, authenticated;
revoke all on function public.atualizar_expedicao(uuid) from public, anon, authenticated;
revoke all on function public.estado_personagem(uuid) from public, anon, authenticated;
revoke all on function public.iniciar_expedicao(text, uuid, jsonb) from public, anon, authenticated;
revoke all on function public.estado_expedicao(uuid) from public, anon, authenticated;
revoke all on function public.resolver_evento(uuid, int) from public, anon, authenticated;
revoke all on function public.finalizar_expedicao(uuid, boolean) from public, anon, authenticated;
revoke all on function public.confirmar_loot(uuid, jsonb) from public, anon, authenticated;
revoke all on function public.sincronizar_estado() from public, anon, authenticated;

grant execute on function public.iniciar_expedicao(text, uuid, jsonb) to authenticated;
grant execute on function public.estado_expedicao(uuid) to authenticated;
grant execute on function public.resolver_evento(uuid, int) to authenticated;
grant execute on function public.finalizar_expedicao(uuid, boolean) to authenticated;
grant execute on function public.confirmar_loot(uuid, jsonb) to authenticated;
grant execute on function public.sincronizar_estado() to authenticated;

-- ======== migrations/0009_inventario.sql ========
-- 0009: INVENTÁRIO E EQUIPAMENTO (Fase 6)
-- Usar consumíveis (stamina e ferimentos), equipar e desequipar armas (2 slots), descartar itens,
-- marcar itens novos e devolver o estado do inventário para a tela. Tudo conferido aqui, com trava de linha.
-- Pode rodar mais de uma vez.

alter table public.inventory add column if not exists recebido_em timestamptz not null default now();
alter table public.characters add column if not exists inventario_visto_em timestamptz not null default now();

insert into public.game_config (chave, valor, descricao, provisorio) values
  ('itens.cura_ferimento', '{"bandagem":1,"kit_primeiros_socorros":2,"analgesico":1}', 'Níveis de ferimento curados ao usar cada item', true)
on conflict (chave) do nothing;

-- Bônus de molotov e sinalizador também no catálogo (para instalações novas pelo setup completo)
update public.items set efeitos = efeitos || '{"bonus_missao":4}'::jsonb where slug = 'molotov' and not (efeitos ? 'bonus_missao');
update public.items set efeitos = efeitos || '{"bonus_missao":2}'::jsonb where slug = 'sinalizador' and not (efeitos ? 'bonus_missao');

-- ---------------------------------------------------------------------------
-- Entregar itens agora marca a hora de chegada (para o brilho de "novo")
-- ---------------------------------------------------------------------------
create or replace function public.entregar_itens(p_user uuid, p_itens jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  x jsonb;
  it public.items%rowtype;
  v_qtd int;
begin
  for x in select * from jsonb_array_elements(coalesce(p_itens, '[]'::jsonb)) loop
    v_qtd := (x->>'qtd')::int;
    continue when v_qtd is null or v_qtd <= 0;
    select * into it from public.items where slug = x->>'item';
    continue when not found;
    if it.empilhavel then
      update public.inventory set quantidade = quantidade + v_qtd, recebido_em = now()
       where user_id = p_user and item_id = it.id and local = 'mochila' and durabilidade is null;
      if not found then
        insert into public.inventory (user_id, item_id, local, quantidade, recebido_em) values (p_user, it.id, 'mochila', v_qtd, now());
      end if;
    else
      insert into public.inventory (user_id, item_id, local, quantidade, durabilidade, recebido_em)
      select p_user, it.id, 'mochila', 1, coalesce(it.durabilidade_max, 1), now() from generate_series(1, v_qtd);
    end if;
  end loop;
end;
$$;

-- Slot de uma arma: corpo a corpo vai no slot próprio; o resto é arma principal
create or replace function public.slot_da_arma(p_subtipo text)
returns text language sql immutable set search_path = '' as $$
  select case when p_subtipo = 'corpo_a_corpo' then 'arma_corpo_a_corpo' else 'arma_principal' end;
$$;

-- Por que este item não pode ser usado agora? (null = pode)
create or replace function public.motivo_nao_usar(p_user uuid, p_slug text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  it public.items%rowtype;
  c public.characters%rowtype;
begin
  select * into it from public.items where slug = p_slug;
  if not found then return 'Item inválido.'; end if;
  select * into c from public.characters where user_id = p_user;
  if it.tipo = 'recurso' then return 'Recursos servem para construir e fabricar.'; end if;
  if it.tipo = 'arma' then return 'Armas são equipadas, não usadas.'; end if;
  if it.tipo = 'item_chave' then return 'Itens-chave funcionam sozinhos enquanto estiverem com você.'; end if;

  if public.cfg('stamina.recupera_por_item') ? p_slug then
    if c.stamina_atual >= public.stamina_maxima(p_user) then return 'Sua stamina já está cheia.'; end if;
    return null;
  end if;
  if public.cfg('itens.cura_ferimento') ? p_slug then
    if c.ferimentos <= 0 then return 'Você não está ferido.'; end if;
    return null;
  end if;
  return case p_slug
    when 'molotov' then 'Leve numa expedição: ajuda na missão e em alguns eventos.'
    when 'sinalizador' then 'Leve numa expedição: ajuda na missão e em alguns eventos.'
    when 'kit_reparo' then 'Repara armas na Fabricação (Fase 9).'
    when 'antibiotico' then 'Trata doenças dos recrutas (Fase 8).'
    when 'antidoto' then 'Trata doenças dos recrutas (Fase 8).'
    else 'Este item não pode ser usado agora.' end;
end;
$$;

-- ---------------------------------------------------------------------------
-- Estado do inventário para a tela
-- ---------------------------------------------------------------------------
create or replace function public.estado_inventario()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  c public.characters%rowtype;
  v_itens jsonb;
  v_peso numeric;
  v_abrigo uuid;
  v_dep_usado numeric := 0;
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;
  perform public.aplicar_catchup_stamina(v_user);
  perform public.aplicar_catchup_ferimentos(v_user);
  select * into c from public.characters where user_id = v_user;
  if not found then raise exception 'Personagem não encontrado.'; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
      'id', i.id, 'slug', it.slug, 'nome', it.nome, 'tipo', it.tipo, 'subtipo', it.subtipo, 'raridade', it.raridade,
      'peso', it.peso, 'descricao', it.descricao, 'efeitos', it.efeitos, 'quantidade', i.quantidade,
      'durabilidade', i.durabilidade, 'durabilidade_max', it.durabilidade_max, 'nivel_requisito', it.nivel_requisito,
      'local', i.local, 'equipado', eq.slot,
      'em_expedicao', exists (select 1 from public.expeditions e where e.arma_id = i.id and e.estado in ('em_andamento', 'aguardando_evento')),
      'novo', i.recebido_em > c.inventario_visto_em,
      'motivo_nao_usar', public.motivo_nao_usar(v_user, it.slug),
      'recupera_stamina', (public.cfg('stamina.recupera_por_item')->>it.slug)::int,
      'cura_ferimento', (public.cfg('itens.cura_ferimento')->>it.slug)::int
    ) order by case it.tipo when 'arma' then 1 when 'consumivel' then 2 when 'recurso' then 3 else 4 end, it.nome), '[]'::jsonb),
    coalesce(sum(it.peso * i.quantidade) filter (where i.local = 'mochila'), 0)
    into v_itens, v_peso
    from public.inventory i
    join public.items it on it.id = i.item_id
    left join public.equipment eq on eq.inventory_id = i.id
   where i.user_id = v_user and i.quantidade > 0;

  select id into v_abrigo from public.user_shelters where user_id = v_user and ativo limit 1;
  if v_abrigo is not null then
    select coalesce(sum(it.peso * i.quantidade), 0) into v_dep_usado
      from public.inventory i join public.items it on it.id = i.item_id
     where i.user_id = v_user and i.local = 'deposito' and i.user_shelter_id = v_abrigo;
  end if;

  return jsonb_build_object(
    'itens', v_itens,
    'peso_mochila', v_peso,
    'carga_max', public.capacidade_carga(v_user),
    'deposito', jsonb_build_object('tem_abrigo', v_abrigo is not null,
                                   'capacidade', (public.cfg('deposito.capacidade_inicial'))::numeric, 'usado', v_dep_usado),
    'visto_em', c.inventario_visto_em
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Ações do jogador
-- ---------------------------------------------------------------------------

-- Usar 1 unidade de um consumível
create or replace function public.usar_item(p_inventory_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_slug text;
  v_nome text;
  v_motivo text;
  v_ganho int;
  v_texto text;
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;
  -- Trava personagem e a linha do item: dois cliques não gastam duas unidades
  perform 1 from public.characters where user_id = v_user for update;
  select it.slug, it.nome into v_slug, v_nome
    from public.inventory i join public.items it on it.id = i.item_id
   where i.id = p_inventory_id and i.user_id = v_user and i.local = 'mochila' and i.quantidade > 0
   for update of i;
  if v_slug is null then raise exception 'Item não encontrado na mochila.'; end if;

  perform public.aplicar_catchup_stamina(v_user);
  perform public.aplicar_catchup_ferimentos(v_user);
  v_motivo := public.motivo_nao_usar(v_user, v_slug);
  if v_motivo is not null then raise exception '%', v_motivo; end if;

  if public.cfg('stamina.recupera_por_item') ? v_slug then
    v_ganho := (public.cfg('stamina.recupera_por_item')->>v_slug)::int;
    perform public.recuperar_stamina(v_user, v_ganho);
    v_texto := format('Usou %s. Um pouco de energia voltou.', lower(v_nome));
  else
    v_ganho := (public.cfg('itens.cura_ferimento')->>v_slug)::int;
    update public.characters
       set ferimentos = greatest(0, ferimentos - v_ganho),
           ferimento_atualizado_em = case when ferimentos - v_ganho <= 0 then null else ferimento_atualizado_em end
     where user_id = v_user;
    v_texto := format('Usou %s. Dói menos. Um pouco.', lower(v_nome));
  end if;

  perform public.tirar_item(v_user, v_slug, 1);
  insert into public.game_log (user_id, tipo, texto, dados) values (v_user, 'item', v_texto, jsonb_build_object('item', v_slug));
  return jsonb_build_object('mensagem', v_texto, 'inventario', public.estado_inventario());
end;
$$;

-- Equipar arma no slot certo (troca a que estava lá)
create or replace function public.equipar(p_inventory_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  r record;
  v_nivel int;
  v_slot text;
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;
  select nivel into v_nivel from public.characters where user_id = v_user for update;
  select i.id, i.durabilidade, it.tipo, it.subtipo, it.nome, it.nivel_requisito into r
    from public.inventory i join public.items it on it.id = i.item_id
   where i.id = p_inventory_id and i.user_id = v_user and i.local = 'mochila'
   for update of i;
  if not found then raise exception 'Item não encontrado na mochila.'; end if;
  if r.tipo <> 'arma' then raise exception 'Só armas podem ser equipadas.'; end if;
  if coalesce(r.durabilidade, 0) <= 0 then raise exception 'Essa arma está quebrada. Repare antes.'; end if;
  if r.nivel_requisito > v_nivel then raise exception 'Essa arma exige nível %.', r.nivel_requisito; end if;

  v_slot := public.slot_da_arma(r.subtipo);
  insert into public.equipment (user_id, slot, inventory_id) values (v_user, v_slot, r.id)
  on conflict (user_id, slot) do update set inventory_id = excluded.inventory_id, atualizado_em = now();
  return jsonb_build_object('mensagem', format('Equipado: %s.', r.nome), 'inventario', public.estado_inventario());
end;
$$;

create or replace function public.desequipar(p_slot text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;
  if p_slot not in ('arma_principal', 'arma_corpo_a_corpo') then raise exception 'Slot inválido.'; end if;
  delete from public.equipment where user_id = v_user and slot = p_slot;
  return jsonb_build_object('mensagem', 'Arma guardada na mochila.', 'inventario', public.estado_inventario());
end;
$$;

-- Descartar uma quantidade (itens-chave e armas equipadas ou em expedição não podem)
create or replace function public.descartar_item(p_inventory_id uuid, p_qtd int)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  r record;
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;
  select i.id, i.quantidade, it.tipo, it.nome, it.slug into r
    from public.inventory i join public.items it on it.id = i.item_id
   where i.id = p_inventory_id and i.user_id = v_user
   for update of i;
  if not found then raise exception 'Item não encontrado.'; end if;
  if r.tipo = 'item_chave' then raise exception 'Itens-chave não podem ser descartados.'; end if;
  if exists (select 1 from public.equipment where inventory_id = r.id) then
    raise exception 'Desequipe a arma antes de descartar.';
  end if;
  if exists (select 1 from public.expeditions where arma_id = r.id and estado in ('em_andamento', 'aguardando_evento')) then
    raise exception 'Essa arma está numa expedição.';
  end if;
  if p_qtd is null or p_qtd < 1 or p_qtd > r.quantidade then raise exception 'Quantidade inválida.'; end if;

  if p_qtd = r.quantidade then
    delete from public.inventory where id = r.id;
  else
    update public.inventory set quantidade = quantidade - p_qtd where id = r.id;
  end if;
  insert into public.game_log (user_id, tipo, texto, dados)
  values (v_user, 'item', format('Descartou %s × %s.', p_qtd, r.nome), jsonb_build_object('item', r.slug, 'qtd', p_qtd));
  return jsonb_build_object('mensagem', format('Descartado: %s × %s.', r.nome, p_qtd), 'inventario', public.estado_inventario());
end;
$$;

create or replace function public.marcar_inventario_visto()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Sessão expirada. Entre de novo.'; end if;
  update public.characters set inventario_visto_em = now() where user_id = auth.uid();
end;
$$;

-- ---------------------------------------------------------------------------
-- Estado do personagem agora inclui o equipamento e itens novos (bolinha no menu)
-- ---------------------------------------------------------------------------
create or replace function public.estado_personagem(p_user uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c public.characters%rowtype;
  v_nome text;
  v_exp jsonb;
  v_equip jsonb;
begin
  select * into c from public.characters where user_id = p_user;
  if not found then
    return null;
  end if;
  select nome_sobrevivente into v_nome from public.profiles where id = p_user;
  select jsonb_build_object('id', e.id, 'estado', e.estado, 'missao', m.nome, 'termina_em', e.termina_em,
                            'loot_pendente', e.estado = 'concluida' and not e.loot_entregue)
    into v_exp
    from public.expeditions e join public.missions m on m.id = e.mission_id
   where e.user_id = p_user and (e.estado in ('em_andamento', 'aguardando_evento') or (e.estado = 'concluida' and not e.loot_entregue))
   order by e.iniciada_em desc
   limit 1;
  select coalesce(jsonb_object_agg(eq.slot, jsonb_build_object(
           'inventory_id', i.id, 'slug', it.slug, 'nome', it.nome, 'raridade', it.raridade,
           'durabilidade', i.durabilidade, 'durabilidade_max', it.durabilidade_max,
           'bonus', coalesce((it.efeitos->>'bonus_missao')::numeric, 0))), '{}'::jsonb)
    into v_equip
    from public.equipment eq join public.inventory i on i.id = eq.inventory_id join public.items it on it.id = i.item_id
   where eq.user_id = p_user;

  return jsonb_build_object(
    'nome', v_nome,
    'nivel', c.nivel,
    'nivel_anunciado', c.nivel_anunciado,
    'xp', c.xp,
    'xp_proximo', public.xp_para_subir(c.nivel),
    'pontos_disponiveis', c.pontos_disponiveis,
    'atributos', jsonb_build_object(
      'forca', c.forca, 'agilidade', c.agilidade, 'percepcao', c.percepcao,
      'medicina', c.medicina, 'engenharia', c.engenharia, 'lideranca', c.lideranca
    ),
    'atributo_maximo', (public.cfg('atributos.maximo'))::int,
    'moral', c.moral,
    'stamina_atual', c.stamina_atual,
    'stamina_maxima', public.stamina_maxima(p_user),
    'stamina_atualizada_em', c.stamina_atualizada_em,
    'segundos_por_ponto', (public.cfg('stamina.minutos_por_ponto'))::numeric * 60,
    'tutorial_etapa', c.tutorial_etapa,
    'stats', c.stats,
    'criado_em', c.criado_em,
    'dias_jogo_por_hora_real', (public.cfg('tempo.dias_jogo_por_hora_real'))::numeric,
    'hora_inicial', (public.cfg('tempo.hora_inicial'))::numeric,
    'moral_divisor', (public.cfg('moral.divisor_modificador'))::numeric,
    'ferimentos', c.ferimentos,
    'ferimento_maximo', (public.cfg('ferimento.maximo'))::int,
    'expedicao', v_exp,
    'equipamento', v_equip,
    'itens_novos', exists (select 1 from public.inventory where user_id = p_user and recebido_em > c.inventario_visto_em),
    'servidor_agora', now()
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Permissões
-- ---------------------------------------------------------------------------
revoke all on function public.entregar_itens(uuid, jsonb) from public, anon, authenticated;
revoke all on function public.slot_da_arma(text) from public, anon, authenticated;
revoke all on function public.motivo_nao_usar(uuid, text) from public, anon, authenticated;
revoke all on function public.estado_personagem(uuid) from public, anon, authenticated;
revoke all on function public.estado_inventario() from public, anon, authenticated;
revoke all on function public.usar_item(uuid) from public, anon, authenticated;
revoke all on function public.equipar(uuid) from public, anon, authenticated;
revoke all on function public.desequipar(text) from public, anon, authenticated;
revoke all on function public.descartar_item(uuid, int) from public, anon, authenticated;
revoke all on function public.marcar_inventario_visto() from public, anon, authenticated;

grant execute on function public.estado_inventario() to authenticated;
grant execute on function public.usar_item(uuid) to authenticated;
grant execute on function public.equipar(uuid) to authenticated;
grant execute on function public.desequipar(text) to authenticated;
grant execute on function public.descartar_item(uuid, int) to authenticated;
grant execute on function public.marcar_inventario_visto() to authenticated;

-- ======== migrations/0010_abrigo.sql ========
-- 0010: ABRIGO (Fase 7)
-- Escolha do abrigo inicial, slots, depósito, instalações (construir, melhorar, coletar, reparar, desmontar),
-- produção passiva, manutenção, gerador e energia, combustível, oficina de reciclagem e "catch-up" do tempo.
-- O saque das expedições passa a ir para o depósito do abrigo (armas continuam na mochila).
-- Tudo calculado aqui, com trava de linha. Pode rodar mais de uma vez.

-- ---------------------------------------------------------------------------
-- Colunas novas
-- ---------------------------------------------------------------------------
alter table public.user_shelters add column if not exists ultimo_tick_em timestamptz not null default now();
alter table public.user_shelters add column if not exists combustivel_progresso numeric not null default 0;  -- dias do jogo desde o último consumo do gerador
alter table public.user_shelters add column if not exists energia_ok boolean not null default true;

alter table public.user_buildings add column if not exists slot int;
alter table public.user_buildings add column if not exists progresso_dias numeric not null default 0;  -- dias do jogo dentro do ciclo atual
alter table public.user_buildings add column if not exists ciclos int not null default 0;              -- ciclos completos (para a manutenção)
create unique index if not exists uq_user_buildings_tipo on public.user_buildings(user_shelter_id, building_type_id);
create unique index if not exists uq_user_buildings_slot on public.user_buildings(user_shelter_id, slot);

insert into public.game_config (chave, valor, descricao, provisorio) values
  ('abrigo.recursos_basicos', '["madeira","sucata","metal","tecido","pecas_mecanicas","vidro","plastico","fios_cabos"]',
   'Recursos que contam como "básicos" (bônus inicial do Porão da mercearia)', true),
  ('abrigo.desmontar_reembolso_pct', '50', '% do custo devolvido ao desmontar uma instalação desmontável', true),
  ('abrigo.reparo_custo_pct', '25', '% do custo de construção para reparar uma instalação danificada', true),
  ('abrigo.alerta_combustivel_dias', '3', 'Avisar quando o combustível durar menos que estes dias do jogo', true),
  ('abrigo.alerta_deposito_pct', '90', 'Avisar quando o depósito passar desta % de ocupação', true),
  ('abrigo.max_dias_catchup_consumo', '3650', 'Limite de segurança de dias simulados por consulta (consumo)', true)
on conflict (chave) do nothing;

-- ---------------------------------------------------------------------------
-- Depósito
-- ---------------------------------------------------------------------------
create or replace function public.abrigo_ativo(p_user uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select id from public.user_shelters where user_id = p_user and ativo limit 1;
$$;

create or replace function public.capacidade_deposito(p_us uuid)
returns numeric language sql stable security definer set search_path = '' as $$
  select (public.cfg('deposito.capacidade_inicial'))::numeric
       + coalesce((select sum(coalesce((bt.efeitos->>'capacidade_deposito_bonus')::numeric, 0))
                     from public.user_buildings ub join public.building_types bt on bt.id = ub.building_type_id
                    where ub.user_shelter_id = p_us and ub.estado in ('ativo', 'parado')), 0);
$$;

create or replace function public.uso_deposito(p_us uuid)
returns numeric language sql stable security definer set search_path = '' as $$
  select coalesce(sum(it.peso * i.quantidade), 0)
    from public.inventory i join public.items it on it.id = i.item_id
   where i.user_shelter_id = p_us and i.local = 'deposito';
$$;

create or replace function public.dados_nivel(p_bt uuid, p_nivel int)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'producao', coalesce(bt.niveis->(p_nivel - 1)->'producao', bt.producao),
    'manutencao', coalesce(bt.niveis->(p_nivel - 1)->'manutencao', bt.manutencao),
    'efeitos', coalesce(bt.efeitos, '{}'::jsonb) || coalesce(bt.niveis->(p_nivel - 1)->'efeitos', '{}'::jsonb),
    'nome_nivel', coalesce(bt.niveis->(p_nivel - 1)->>'nome', bt.nome),
    'max_nivel', greatest(1, jsonb_array_length(bt.niveis))
  )
  from public.building_types bt where bt.id = p_bt;
$$;

create or replace function public.item_produzido(p_bt uuid, p_nivel int)
returns text
language sql
stable
set search_path = ''
as $$
  select k from jsonb_object_keys(coalesce((public.dados_nivel(p_bt, p_nivel))->'producao', '{}'::jsonb)) k
   where k not in ('ciclo_dias', 'extra', 'chance_extra_pct', 'conversoes', 'modo')
   limit 1;
$$;

create or replace function public.qtd_deposito(p_us uuid, p_slug text)
returns int language sql stable security definer set search_path = '' as $$
  select coalesce(sum(i.quantidade), 0)::int from public.inventory i join public.items it on it.id = i.item_id
   where i.user_shelter_id = p_us and i.local = 'deposito' and it.slug = p_slug and i.durabilidade is null;
$$;

-- Produção acumulada nas instalações também ocupa espaço (vai para o depósito ao coletar)
create or replace function public.uso_acumulado(p_us uuid)
returns numeric language sql stable security definer set search_path = '' as $$
  select coalesce(sum(floor(ub.producao_acumulada) * coalesce(it.peso, 1)), 0)
    from public.user_buildings ub
    join public.building_types bt on bt.id = ub.building_type_id
    left join public.items it on it.slug = public.item_produzido(bt.id, ub.nivel)
   where ub.user_shelter_id = p_us;
$$;

-- Guarda no depósito o que couber; devolve quanto foi guardado
create or replace function public.por_deposito(p_user uuid, p_us uuid, p_slug text, p_qtd int)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  it public.items%rowtype;
  v_livre numeric;
  v_cabe int;
begin
  if p_qtd is null or p_qtd <= 0 then return 0; end if;
  select * into it from public.items where slug = p_slug;
  if not found then return 0; end if;
  v_livre := public.capacidade_deposito(p_us) - public.uso_deposito(p_us);
  v_cabe := case when it.peso <= 0 then p_qtd else least(p_qtd, floor(v_livre / it.peso)::int) end;
  if v_cabe <= 0 then return 0; end if;
  if it.empilhavel then
    update public.inventory set quantidade = quantidade + v_cabe, recebido_em = now()
     where user_id = p_user and item_id = it.id and local = 'deposito' and user_shelter_id = p_us and durabilidade is null;
    if not found then
      insert into public.inventory (user_id, item_id, local, user_shelter_id, quantidade, recebido_em)
      values (p_user, it.id, 'deposito', p_us, v_cabe, now());
    end if;
  else
    insert into public.inventory (user_id, item_id, local, user_shelter_id, quantidade, durabilidade, recebido_em)
    select p_user, it.id, 'deposito', p_us, 1, coalesce(it.durabilidade_max, 1), now() from generate_series(1, v_cabe);
  end if;
  return v_cabe;
end;
$$;

-- Tira do depósito (sem erro). Devolve true se tinha
create or replace function public.tirar_deposito(p_us uuid, p_slug text, p_qtd int)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_linha uuid;
  v_tem int;
begin
  if p_qtd <= 0 then return true; end if;
  select i.id, i.quantidade into v_linha, v_tem
    from public.inventory i join public.items it on it.id = i.item_id
   where i.user_shelter_id = p_us and i.local = 'deposito' and it.slug = p_slug and i.durabilidade is null
   for update of i;
  if v_linha is null or v_tem < p_qtd then return false; end if;
  if v_tem = p_qtd then delete from public.inventory where id = v_linha;
  else update public.inventory set quantidade = quantidade - p_qtd where id = v_linha; end if;
  return true;
end;
$$;

-- Quanto o jogador tem de um item empilhável (mochila + depósito do abrigo ativo)
create or replace function public.qtd_total(p_user uuid, p_slug text)
returns int language sql stable security definer set search_path = '' as $$
  select coalesce(sum(i.quantidade), 0)::int
    from public.inventory i join public.items it on it.id = i.item_id
   where i.user_id = p_user and it.slug = p_slug and i.durabilidade is null
     and (i.local = 'mochila' or i.user_shelter_id = public.abrigo_ativo(p_user));
$$;

-- Tira primeiro do depósito e depois da mochila. Erro amigável se não tiver o bastante.
create or replace function public.tirar_item_qualquer(p_user uuid, p_slug text, p_qtd int)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_us uuid := public.abrigo_ativo(p_user);
  r record;
  v_falta int := p_qtd;
  v_nome text;
begin
  if p_qtd <= 0 then return; end if;
  if public.qtd_total(p_user, p_slug) < p_qtd then
    select nome into v_nome from public.items where slug = p_slug;
    raise exception 'Você não tem % suficiente.', coalesce(v_nome, p_slug);
  end if;
  for r in
    select i.id, i.quantidade from public.inventory i join public.items it on it.id = i.item_id
     where i.user_id = p_user and it.slug = p_slug and i.durabilidade is null
       and (i.local = 'mochila' or i.user_shelter_id = v_us)
     order by case when i.local = 'deposito' then 0 else 1 end
     for update of i
  loop
    exit when v_falta <= 0;
    if r.quantidade <= v_falta then
      delete from public.inventory where id = r.id;
      v_falta := v_falta - r.quantidade;
    else
      update public.inventory set quantidade = quantidade - v_falta where id = r.id;
      v_falta := 0;
    end if;
  end loop;
end;
$$;

-- Entregar itens (saque, bônus): armas vão para a mochila; o resto para o depósito, se houver abrigo e espaço.
-- O que não couber fica na mochila.
create or replace function public.entregar_itens(p_user uuid, p_itens jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  x jsonb;
  it public.items%rowtype;
  v_qtd int;
  v_us uuid := public.abrigo_ativo(p_user);
  v_guardado int := 0;
begin
  for x in select * from jsonb_array_elements(coalesce(p_itens, '[]'::jsonb)) loop
    v_qtd := (x->>'qtd')::int;
    continue when v_qtd is null or v_qtd <= 0;
    select * into it from public.items where slug = x->>'item';
    continue when not found;
    v_guardado := 0;
    if v_us is not null and it.tipo <> 'arma' then
      v_guardado := public.por_deposito(p_user, v_us, it.slug, v_qtd);
    end if;
    v_qtd := v_qtd - v_guardado;
    continue when v_qtd <= 0;
    if it.empilhavel then
      update public.inventory set quantidade = quantidade + v_qtd, recebido_em = now()
       where user_id = p_user and item_id = it.id and local = 'mochila' and durabilidade is null;
      if not found then
        insert into public.inventory (user_id, item_id, local, quantidade, recebido_em) values (p_user, it.id, 'mochila', v_qtd, now());
      end if;
    else
      insert into public.inventory (user_id, item_id, local, quantidade, durabilidade, recebido_em)
      select p_user, it.id, 'mochila', 1, coalesce(it.durabilidade_max, 1), now() from generate_series(1, v_qtd);
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Dados da instalação no nível atual (instalações com "niveis" trocam produção e manutenção)
-- ---------------------------------------------------------------------------

-- Qual item a instalação produz (a chave da produção que não é parâmetro)

-- ---------------------------------------------------------------------------
-- Energia: oferta (geradores com combustível + painel) e demanda (instalações + recrutas)
-- ---------------------------------------------------------------------------
create or replace function public.demanda_energia(p_us uuid)
returns numeric language sql stable security definer set search_path = '' as $$
  select coalesce((select sum(bt.consumo_energia) from public.user_buildings ub join public.building_types bt on bt.id = ub.building_type_id
                    where ub.user_shelter_id = p_us and ub.estado in ('ativo', 'parado')), 0)
       + coalesce((select count(*) from public.recruits r where r.user_shelter_id = p_us and r.estado <> 'inativo'), 0);
$$;

-- ---------------------------------------------------------------------------
-- CATCH-UP: simula os dias do jogo que passaram desde a última visita.
-- Produção: no máximo tempo.max_catchup_dias_producao dias por consulta.
-- Consumo (combustível e manutenção): aplicado integralmente.
-- ---------------------------------------------------------------------------
create or replace function public.sincronizar_abrigo(p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  us public.user_shelters%rowtype;
  v_dph numeric := (public.cfg('tempo.dias_jogo_por_hora_real'))::numeric;
  v_max_prod int := (public.cfg('tempo.max_catchup_dias_producao'))::int;
  v_max_cons int := (public.cfg('abrigo.max_dias_catchup_consumo'))::int;
  v_n int;
  d int;
  b record;
  dn jsonb;
  v_item text;
  v_qtd numeric;
  v_ciclo numeric;
  v_cada int;
  k text;
  v_ok boolean;
  v_oferta numeric;
  v_demanda numeric;
  v_energia boolean := true;
  v_sem_comb boolean := false;
  v_gerador record;
  v_livre numeric;
  v_peso numeric;
begin
  select * into us from public.user_shelters where user_id = p_user and ativo for update;
  if not found then return; end if;

  -- Construções que terminaram: começam a produzir a partir do dia em que ficaram prontas
  update public.user_buildings
     set estado = 'ativo',
         progresso_dias = - greatest(0, extract(epoch from (concluido_em - us.ultimo_tick_em)) / 3600.0 * v_dph)
   where user_shelter_id = us.id and estado = 'construindo' and concluido_em <= now();

  v_n := floor(greatest(0, extract(epoch from (now() - us.ultimo_tick_em))) / 3600.0 * v_dph)::int;
  if v_n < 1 then return; end if;
  v_n := least(v_n, v_max_cons);

  for d in 1..v_n loop
    -- Energia do dia
    select ub.id, (bt.efeitos->>'cobre_recrutas')::numeric as cobre, (bt.efeitos->>'dias_por_combustivel')::numeric as dpc
      into v_gerador
      from public.user_buildings ub join public.building_types bt on bt.id = ub.building_type_id
     where ub.user_shelter_id = us.id and ub.estado = 'ativo' and bt.slug in ('gerador_basico', 'gerador_avancado')
     limit 1;
    v_oferta := 0;
    if v_gerador.id is not null and not v_sem_comb then
      us.combustivel_progresso := us.combustivel_progresso + 1;
      if us.combustivel_progresso >= v_gerador.dpc then
        if public.tirar_deposito(us.id, 'combustivel', 1) then
          us.combustivel_progresso := us.combustivel_progresso - v_gerador.dpc;
        else
          v_sem_comb := true;  -- acabou o combustível: gerador para
        end if;
      end if;
      if not v_sem_comb then v_oferta := v_oferta + v_gerador.cobre; end if;
    end if;
    v_oferta := v_oferta + coalesce((select sum((bt.efeitos->>'cobre_recrutas')::numeric)
                                       from public.user_buildings ub join public.building_types bt on bt.id = ub.building_type_id
                                      where ub.user_shelter_id = us.id and ub.estado = 'ativo' and bt.slug = 'painel_solar'), 0);
    v_demanda := public.demanda_energia(us.id);
    v_energia := v_oferta >= v_demanda;

    -- Produção do dia (só nos primeiros dias permitidos)
    if d <= v_max_prod then
      for b in
        select ub.*, bt.slug as tipo_slug, bt.consumo_energia
          from public.user_buildings ub join public.building_types bt on bt.id = ub.building_type_id
         where ub.user_shelter_id = us.id and ub.estado in ('ativo', 'parado') and bt.categoria = 'producao'
         order by ub.slot
      loop
        dn := public.dados_nivel(b.building_type_id, b.nivel);
        v_ciclo := (dn->'producao'->>'ciclo_dias')::numeric;
        continue when v_ciclo is null;                                -- reciclagem é manual
        continue when b.consumo_energia > 0 and not v_energia;        -- sem energia, não anda

        update public.user_buildings set progresso_dias = progresso_dias + 1 where id = b.id returning progresso_dias into b.progresso_dias;
        continue when b.progresso_dias < v_ciclo;

        update public.user_buildings set progresso_dias = progresso_dias - v_ciclo, ciclos = ciclos + 1 where id = b.id
          returning ciclos into b.ciclos;

        -- Manutenção a cada N ciclos
        v_ok := true;
        v_cada := (dn->'manutencao'->>'a_cada_ciclos')::int;
        if v_cada is not null and b.ciclos % v_cada = 0 then
          for k, v_qtd in select key, value::numeric from jsonb_each_text(dn->'manutencao') where key <> 'a_cada_ciclos' loop
            if public.qtd_deposito(us.id, k) < v_qtd then v_ok := false; end if;
          end loop;
          if v_ok then
            for k, v_qtd in select key, value::numeric from jsonb_each_text(dn->'manutencao') where key <> 'a_cada_ciclos' loop
              perform public.tirar_deposito(us.id, k, v_qtd::int);
            end loop;
          end if;
        end if;
        if not v_ok then
          update public.user_buildings set estado = 'parado', manutencao_ok = false where id = b.id;
          continue;
        end if;
        update public.user_buildings set estado = 'ativo', manutencao_ok = true, ultimo_ciclo_em = now() where id = b.id;

        -- Produz o que couber no depósito (contando o que já está acumulado)
        v_item := public.item_produzido(b.building_type_id, b.nivel);
        v_qtd := (dn->'producao'->>v_item)::numeric;
        if (dn->'producao'->>'chance_extra_pct') is not null
           and public.rolar(abs(hashtext(b.id::text))::bigint, 'extra' || b.ciclos) <= (dn->'producao'->>'chance_extra_pct')::int then
          v_qtd := v_qtd + coalesce((dn->'producao'->>'extra')::numeric, 0);
        end if;
        select coalesce(peso, 1) into v_peso from public.items where slug = v_item;
        v_livre := public.capacidade_deposito(us.id) - public.uso_deposito(us.id) - public.uso_acumulado(us.id);
        if v_peso > 0 then v_qtd := least(v_qtd, floor(greatest(0, v_livre) / v_peso)); end if;
        if v_qtd > 0 then
          update public.user_buildings set producao_acumulada = producao_acumulada + v_qtd where id = b.id;
        end if;
      end loop;
    end if;
  end loop;

  update public.user_shelters
     set ultimo_tick_em = ultimo_tick_em + make_interval(secs => (v_n / v_dph * 3600)::double precision),
         combustivel_progresso = us.combustivel_progresso,
         energia_ok = v_energia
   where id = us.id;
end;
$$;


-- ---------------------------------------------------------------------------
-- Bônus das instalações nos atributos (Treinamento, Oficina, Enfermaria com energia)
-- ---------------------------------------------------------------------------
create or replace function public.bonus_atributos_abrigo(p_user uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v jsonb := '{"forca":0,"agilidade":0,"percepcao":0,"medicina":0,"engenharia":0,"lideranca":0}'::jsonb;
  b record;
  k text;
  n numeric;
  v_energia boolean;
begin
  select energia_ok into v_energia from public.user_shelters where user_id = p_user and ativo;
  for b in
    select bt.efeitos, bt.consumo_energia from public.user_buildings ub
      join public.user_shelters us on us.id = ub.user_shelter_id
      join public.building_types bt on bt.id = ub.building_type_id
     where us.user_id = p_user and us.ativo and ub.estado = 'ativo' and bt.efeitos ? 'atributo_bonus'
  loop
    continue when b.consumo_energia > 0 and not coalesce(v_energia, false);
    for k, n in select key, value::numeric from jsonb_each_text(b.efeitos->'atributo_bonus') loop
      v := jsonb_set(v, array[k], to_jsonb(coalesce((v->>k)::numeric, 0) + n));
    end loop;
  end loop;
  return v;
end;
$$;

-- Atributos efetivos: (base + instalações) × bônus percentual do abrigo
create or replace function public.atributos_efetivos(p_user uuid, p_regiao_slug text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c public.characters%rowtype;
  v_eng numeric := 0;
  v_agi numeric := 0;
  bi jsonb;
begin
  select * into c from public.characters where user_id = p_user;
  if not found then
    return null;
  end if;
  select coalesce((s.vantagens->>'engenharia_bonus_pct')::numeric, 0),
         case when p_regiao_slug = 'periferia' then coalesce((s.vantagens->>'agilidade_bonus_pct_periferia')::numeric, 0) else 0 end
    into v_eng, v_agi
    from public.user_shelters us join public.shelters s on s.id = us.shelter_id
   where us.user_id = p_user and us.ativo
   limit 1;
  bi := public.bonus_atributos_abrigo(p_user);

  return jsonb_build_object(
    'forca', c.forca + (bi->>'forca')::numeric,
    'agilidade', round((c.agilidade + (bi->>'agilidade')::numeric) * (100 + coalesce(v_agi, 0)) / 100.0, 2),
    'percepcao', c.percepcao + (bi->>'percepcao')::numeric,
    'medicina', c.medicina + (bi->>'medicina')::numeric,
    'engenharia', round((c.engenharia + (bi->>'engenharia')::numeric) * (100 + coalesce(v_eng, 0)) / 100.0, 2),
    'lideranca', c.lideranca + (bi->>'lideranca')::numeric
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Regras de construção
-- ---------------------------------------------------------------------------
create or replace function public.texto_custo(p_custo jsonb)
returns text language sql stable set search_path = '' as $$
  select coalesce(string_agg(format('%s %s', c.value, coalesce(it.nome, c.key)), ', ' order by c.key), 'grátis')
    from jsonb_each_text(coalesce(p_custo, '{}'::jsonb)) c left join public.items it on it.slug = c.key;
$$;

create or replace function public.falta_custo(p_user uuid, p_custo jsonb)
returns text language sql stable security definer set search_path = '' as $$
  select string_agg(format('%s %s', c.value::int - public.qtd_total(p_user, c.key), coalesce(it.nome, c.key)), ', ' order by c.key)
    from jsonb_each_text(coalesce(p_custo, '{}'::jsonb)) c left join public.items it on it.slug = c.key
   where public.qtd_total(p_user, c.key) < c.value::int;
$$;

create or replace function public.motivo_requisitos(p_user uuid, p_us uuid, p_req jsonb)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_attr jsonb := public.atributos_efetivos(p_user, null);
  k text;
  v text;
  v_nomes jsonb := '{"forca":"Força","agilidade":"Agilidade","percepcao":"Percepção","medicina":"Medicina","engenharia":"Engenharia","lideranca":"Liderança"}';
begin
  for k, v in select key, value from jsonb_each_text(coalesce(p_req, '{}'::jsonb)) loop
    if v_nomes ? k and coalesce((v_attr->>k)::numeric, 0) < v::numeric then
      return format('Requer %s %s', v_nomes->>k, v);
    end if;
    if k = 'instalacao' and not exists (
      select 1 from public.user_buildings ub join public.building_types bt on bt.id = ub.building_type_id
       where ub.user_shelter_id = p_us and bt.slug = v and ub.estado in ('ativo', 'parado')) then
      return format('Requer a instalação %s', (select nome from public.building_types where slug = v));
    end if;
    if k = 'item_chave' and not public.tem_item(p_user, v) then
      return format('Requer o item %s', (select nome from public.items where slug = v));
    end if;
    if k = 'melhora' and not exists (
      select 1 from public.user_buildings ub join public.building_types bt on bt.id = ub.building_type_id
       where ub.user_shelter_id = p_us and bt.slug = v and ub.estado = 'ativo') then
      return format('Melhoria de %s: construa antes', (select nome from public.building_types where slug = v));
    end if;
    -- espaco_externo, agua e chuva: sem clima/terreno no MVP, sempre atendidos
  end loop;
  return null;
end;
$$;

create or replace function public.motivo_nao_construir(p_user uuid, p_us uuid, p_bt uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  bt public.building_types%rowtype;
  v_slots int;
  v_usados int;
  v_motivo text;
  v_falta text;
begin
  select * into bt from public.building_types where id = p_bt;
  if exists (select 1 from public.user_buildings where user_shelter_id = p_us and building_type_id = p_bt) then
    return 'Já construída neste abrigo';
  end if;
  -- Gerador avançado substitui o básico no mesmo espaço
  if bt.slug = 'gerador_avancado' and exists (
      select 1 from public.user_buildings ub join public.building_types t on t.id = ub.building_type_id
       where ub.user_shelter_id = p_us and t.slug = 'gerador_avancado') then
    return 'Já construída neste abrigo';
  end if;
  select slots into v_slots from public.user_shelters where id = p_us;
  select count(*) into v_usados from public.user_buildings where user_shelter_id = p_us;
  if not (bt.requisitos ? 'melhora') and v_usados >= v_slots then
    return 'Sem espaço livre no abrigo';
  end if;
  v_motivo := public.motivo_requisitos(p_user, p_us, bt.requisitos);
  if v_motivo is not null then return v_motivo; end if;
  v_falta := public.falta_custo(p_user, coalesce(bt.niveis->0->'custo', bt.custo));
  if v_falta is not null then return 'Faltam ' || v_falta; end if;
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Estado do abrigo para a tela
-- ---------------------------------------------------------------------------
create or replace function public.estado_abrigo()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  us public.user_shelters%rowtype;
  s public.shelters%rowtype;
  v_regiao text;
  v_regiao_nome text;
  v_local text;
  v_cap numeric;
  v_uso numeric;
  v_dep jsonb;
  v_inst jsonb;
  v_cat jsonb;
  v_oferta numeric := 0;
  v_demanda numeric;
  v_comb int;
  v_dpc numeric;
  v_dias_comb numeric;
  v_energia text;
  v_defesa numeric;
  v_alertas jsonb := '[]'::jsonb;
  v_dph numeric := (public.cfg('tempo.dias_jogo_por_hora_real'))::numeric;
  v_ameaca numeric;
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;
  if not exists (select 1 from public.characters where user_id = v_user) then raise exception 'Personagem não encontrado.'; end if;

  select * into us from public.user_shelters where user_id = v_user and ativo;
  if not found then
    -- Sem abrigo: devolve as opções iniciais
    return jsonb_build_object(
      'tem_abrigo', false,
      'escolha', (select coalesce(jsonb_agg(jsonb_build_object(
          'slug', sh.slug, 'nome', sh.nome, 'descricao', sh.descricao, 'slots', sh.slots_iniciais,
          'vantagens', sh.vantagens, 'desvantagens', sh.desvantagens, 'local', l.nome, 'regiao', r.nome) order by sh.ordem), '[]'::jsonb)
         from public.shelters sh left join public.locations l on l.id = sh.location_id left join public.regions r on r.id = sh.region_id
        where sh.tipo = 'inicial' and sh.ativo),
      'servidor_agora', now());
  end if;

  perform public.sincronizar_abrigo(v_user);
  select * into us from public.user_shelters where id = us.id;
  select * into s from public.shelters where id = us.shelter_id;
  select r.slug, r.nome into v_regiao, v_regiao_nome from public.regions r where r.id = s.region_id;
  select nome into v_local from public.locations where id = s.location_id;

  v_cap := public.capacidade_deposito(us.id);
  v_uso := public.uso_deposito(us.id);

  select coalesce(jsonb_agg(jsonb_build_object('id', i.id, 'slug', it.slug, 'nome', it.nome, 'tipo', it.tipo, 'raridade', it.raridade,
                                               'quantidade', i.quantidade, 'peso', it.peso) order by it.tipo, it.nome), '[]'::jsonb)
    into v_dep
    from public.inventory i join public.items it on it.id = i.item_id
   where i.user_shelter_id = us.id and i.local = 'deposito';

  -- Energia
  select coalesce(sum((bt.efeitos->>'cobre_recrutas')::numeric), 0), max((bt.efeitos->>'dias_por_combustivel')::numeric)
    into v_oferta, v_dpc
    from public.user_buildings ub join public.building_types bt on bt.id = ub.building_type_id
   where ub.user_shelter_id = us.id and ub.estado = 'ativo' and bt.categoria = 'energia';
  v_demanda := public.demanda_energia(us.id);
  v_comb := public.qtd_deposito(us.id, 'combustivel');
  -- Gerador parado por falta de combustível não oferece energia (o painel solar continua)
  if not us.energia_ok and v_dpc is not null then
    select coalesce(sum((bt.efeitos->>'cobre_recrutas')::numeric), 0) into v_oferta
      from public.user_buildings ub join public.building_types bt on bt.id = ub.building_type_id
     where ub.user_shelter_id = us.id and ub.estado = 'ativo' and bt.slug = 'painel_solar';
  end if;
  v_dias_comb := case when v_dpc is null then null else greatest(0, v_comb * v_dpc + (v_dpc - us.combustivel_progresso)) end;
  v_energia := case
    when v_oferta = 0 and v_demanda = 0 then 'sem_gerador'
    when not us.energia_ok or v_oferta = 0 then 'sem_energia'
    when v_oferta - v_demanda <= 1 then 'apertado'
    else 'ok' end;

  -- Instalações
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', ub.id, 'slug', bt.slug, 'nome', bt.nome, 'categoria', bt.categoria, 'descricao', bt.descricao,
      'nivel', ub.nivel, 'nome_nivel', dn->>'nome_nivel', 'max_nivel', (dn->>'max_nivel')::int,
      'estado', ub.estado, 'slot', ub.slot, 'concluido_em', ub.concluido_em, 'criado_em', ub.criado_em,
      'producao', dn->'producao', 'manutencao', dn->'manutencao', 'efeitos', dn->'efeitos',
      'item_produzido', public.item_produzido(bt.id, ub.nivel),
      'item_produzido_nome', (select nome from public.items where slug = public.item_produzido(bt.id, ub.nivel)),
      'acumulada', floor(ub.producao_acumulada),
      'progresso_dias', greatest(0, ub.progresso_dias),
      'consumo_energia', bt.consumo_energia,
      'tempo_dias', bt.tempo_construcao_dias,
      'sem_energia', bt.consumo_energia > 0 and not us.energia_ok,
      'desmontavel', bt.desmontavel,
      'melhoria', case when (dn->>'max_nivel')::int > ub.nivel then jsonb_build_object(
          'nome', bt.niveis->(ub.nivel)->>'nome',
          'custo', bt.niveis->(ub.nivel)->'custo',
          'custo_texto', public.texto_custo(bt.niveis->(ub.nivel)->'custo'),
          'motivo', case when ub.estado <> 'ativo' then 'Só dá para melhorar quando estiver ativa'
                         else coalesce(public.motivo_requisitos(v_user, us.id, (bt.niveis->(ub.nivel)->'requisitos') - 'requer_nivel_anterior'),
                                       'Faltam ' || public.falta_custo(v_user, bt.niveis->(ub.nivel)->'custo')) end)
        else null end,
      'reparo_custo', case when ub.estado = 'danificado' then public.texto_custo((select jsonb_object_agg(c.key, ceil(c.value::numeric * (public.cfg('abrigo.reparo_custo_pct'))::numeric / 100))
                                                                                   from jsonb_each_text(bt.custo) c)) else null end
    ) order by ub.slot), '[]'::jsonb)
    into v_inst
    from public.user_buildings ub
    join public.building_types bt on bt.id = ub.building_type_id
    cross join lateral (select public.dados_nivel(bt.id, ub.nivel) as dn) x
   where ub.user_shelter_id = us.id;

  -- Catálogo "Construir"
  select coalesce(jsonb_agg(jsonb_build_object(
      'slug', bt.slug, 'nome', bt.nome, 'categoria', bt.categoria, 'descricao', bt.descricao,
      'custo', coalesce(bt.niveis->0->'custo', bt.custo),
      'custo_itens', (select coalesce(jsonb_agg(jsonb_build_object('item', c.key, 'nome', coalesce(it.nome, c.key), 'qtd', c.value::int,
                                                                   'tem', public.qtd_total(v_user, c.key)) order by c.key), '[]'::jsonb)
                        from jsonb_each_text(coalesce(bt.niveis->0->'custo', bt.custo)) c left join public.items it on it.slug = c.key),
      'tempo_dias', bt.tempo_construcao_dias,
      'efeitos', bt.efeitos, 'producao', coalesce(bt.niveis->0->'producao', bt.producao),
      'consumo_energia', bt.consumo_energia,
      'nome_nivel', bt.niveis->0->>'nome',
      'motivo', public.motivo_nao_construir(v_user, us.id, bt.id)
    ) order by bt.ordem), '[]'::jsonb)
    into v_cat
    from public.building_types bt;

  -- Defesa e ameaça (qualitativas na tela)
  select coalesce(sum((bt.efeitos->>'defesa')::numeric), 0) into v_defesa
    from public.user_buildings ub join public.building_types bt on bt.id = ub.building_type_id
   where ub.user_shelter_id = us.id and ub.estado = 'ativo';
  v_ameaca := coalesce((public.cfg('ataques.chance_base_por_regiao_pct')->>v_regiao)::numeric, 0) * us.ameaca_mult
              * coalesce((s.desvantagens->>'ruido_ataque_mult')::numeric, 1);

  -- Alertas
  if v_cap > 0 and v_uso / v_cap * 100 >= (public.cfg('abrigo.alerta_deposito_pct'))::numeric then
    v_alertas := v_alertas || jsonb_build_array(jsonb_build_object('tipo', 'deposito', 'texto', 'Depósito quase cheio: a produção vai parar.'));
  end if;
  if v_energia = 'sem_energia' then
    v_alertas := v_alertas || jsonb_build_array(jsonb_build_object('tipo', 'energia', 'texto', 'Sem energia: instalações elétricas pararam.'));
  end if;
  if v_dias_comb is not null and v_dias_comb < (public.cfg('abrigo.alerta_combustivel_dias'))::numeric then
    v_alertas := v_alertas || jsonb_build_array(jsonb_build_object('tipo', 'combustivel', 'texto', 'Combustível acabando: o gerador vai parar.'));
  end if;
  if exists (select 1 from public.user_buildings where user_shelter_id = us.id and estado = 'parado') then
    v_alertas := v_alertas || jsonb_build_array(jsonb_build_object('tipo', 'manutencao', 'texto', 'Instalação parada por falta de manutenção.'));
  end if;
  if exists (select 1 from public.user_buildings where user_shelter_id = us.id and estado = 'danificado') then
    v_alertas := v_alertas || jsonb_build_array(jsonb_build_object('tipo', 'dano', 'texto', 'Instalação danificada: precisa de reparo.'));
  end if;
  if public.qtd_deposito(us.id, 'comida_enlatada') = 0 then
    v_alertas := v_alertas || jsonb_build_array(jsonb_build_object('tipo', 'comida', 'texto', 'Sem comida no depósito.'));
  end if;
  if public.qtd_deposito(us.id, 'agua_potavel') = 0 then
    v_alertas := v_alertas || jsonb_build_array(jsonb_build_object('tipo', 'agua', 'texto', 'Sem água no depósito.'));
  end if;

  return jsonb_build_object(
    'tem_abrigo', true,
    'abrigo', jsonb_build_object('id', us.id, 'slug', s.slug, 'nome', s.nome, 'descricao', s.descricao, 'local', v_local,
                                 'regiao', v_regiao, 'regiao_nome', v_regiao_nome, 'slots', us.slots,
                                 'vantagens', s.vantagens, 'desvantagens', s.desvantagens, 'criado_em', us.criado_em),
    'deposito', jsonb_build_object('capacidade', v_cap, 'usado', v_uso, 'itens', v_dep),
    'energia', jsonb_build_object('oferta', v_oferta, 'demanda', v_demanda, 'estado', v_energia,
                                  'combustivel', v_comb, 'dias_combustivel', v_dias_comb),
    'defesa', case when v_defesa >= 5 then 'forte' when v_defesa >= 2 then 'razoavel' when v_defesa > 0 then 'fraca' else 'nenhuma' end,
    'ameaca', case when v_ameaca >= 8 then 'alta' when v_ameaca >= 5 then 'media' else 'baixa' end,
    'instalacoes', v_inst,
    'catalogo', v_cat,
    'alertas', v_alertas,
    'dias_jogo_por_hora_real', v_dph,
    'servidor_agora', now()
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Ações do jogador
-- ---------------------------------------------------------------------------

-- Escolher o abrigo inicial (uma vez só). Aplica o bônus inicial do Porão da mercearia.
create or replace function public.escolher_abrigo_inicial(p_slug text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  s public.shelters%rowtype;
  v_us uuid;
  k text;
  v_itens jsonb := '[]'::jsonb;
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;
  perform 1 from public.characters where user_id = v_user for update;
  if not found then raise exception 'Personagem não encontrado.'; end if;
  if exists (select 1 from public.user_shelters where user_id = v_user) then
    raise exception 'Você já escolheu um abrigo.';
  end if;
  select * into s from public.shelters where slug = p_slug and tipo = 'inicial' and ativo;
  if not found then raise exception 'Abrigo inválido.'; end if;

  insert into public.user_shelters (user_id, shelter_id, ativo, slots) values (v_user, s.id, true, s.slots_iniciais) returning id into v_us;

  if s.vantagens ? 'recursos_basicos_iniciais' then
    for k in select jsonb_array_elements_text(public.cfg('abrigo.recursos_basicos')) loop
      v_itens := v_itens || jsonb_build_array(jsonb_build_object('item', k, 'qtd', (s.vantagens->>'recursos_basicos_iniciais')::int));
    end loop;
  end if;
  if s.vantagens ? 'comida_inicial' then
    v_itens := v_itens || jsonb_build_array(jsonb_build_object('item', 'comida_enlatada', 'qtd', (s.vantagens->>'comida_inicial')::int));
  end if;
  if s.vantagens ? 'agua_inicial' then
    v_itens := v_itens || jsonb_build_array(jsonb_build_object('item', 'agua_potavel', 'qtd', (s.vantagens->>'agua_inicial')::int));
  end if;
  perform public.entregar_itens(v_user, v_itens);

  insert into public.game_log (user_id, tipo, texto, dados)
  values (v_user, 'abrigo', format('Você se instalou: %s. Não é muito, mas tem porta.', s.nome), jsonb_build_object('abrigo', s.slug));
  return public.estado_abrigo();
end;
$$;

-- Construir uma instalação num slot (ou no primeiro livre)
create or replace function public.construir(p_tipo text, p_slot int default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  us public.user_shelters%rowtype;
  bt public.building_types%rowtype;
  v_motivo text;
  v_slot int := p_slot;
  v_custo jsonb;
  k text;
  v int;
  v_fim timestamptz;
  v_basico uuid;
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;
  perform public.sincronizar_abrigo(v_user);
  select * into us from public.user_shelters where user_id = v_user and ativo for update;
  if not found then raise exception 'Escolha um abrigo primeiro.'; end if;
  select * into bt from public.building_types where slug = p_tipo;
  if not found then raise exception 'Instalação inválida.'; end if;

  v_motivo := public.motivo_nao_construir(v_user, us.id, bt.id);
  if v_motivo is not null then raise exception '%.', v_motivo; end if;

  v_custo := coalesce(bt.niveis->0->'custo', bt.custo);
  for k, v in select key, value::int from jsonb_each_text(v_custo) loop
    perform public.tirar_item_qualquer(v_user, k, v);
  end loop;
  if bt.requisitos ? 'item_chave' then
    perform public.tirar_item_qualquer(v_user, bt.requisitos->>'item_chave', 1);  -- o painel solar vira a instalação
  end if;

  v_fim := now() + make_interval(secs => (bt.tempo_construcao_dias / (public.cfg('tempo.dias_jogo_por_hora_real'))::numeric * 3600)::double precision);

  if bt.requisitos ? 'melhora' then
    -- Melhoria de gerador: troca o básico pelo avançado no mesmo espaço
    select ub.id into v_basico from public.user_buildings ub join public.building_types t on t.id = ub.building_type_id
     where ub.user_shelter_id = us.id and t.slug = bt.requisitos->>'melhora';
    update public.user_buildings set building_type_id = bt.id, nivel = 1, estado = 'construindo', concluido_em = v_fim,
           progresso_dias = 0, ciclos = 0 where id = v_basico;
  else
    if v_slot is null then
      select min(g) into v_slot from generate_series(0, us.slots - 1) g
       where not exists (select 1 from public.user_buildings where user_shelter_id = us.id and slot = g);
    end if;
    if v_slot is null or v_slot < 0 or v_slot >= us.slots then raise exception 'Espaço inválido.'; end if;
    if exists (select 1 from public.user_buildings where user_shelter_id = us.id and slot = v_slot) then
      raise exception 'Esse espaço já está ocupado.';
    end if;
    insert into public.user_buildings (user_shelter_id, building_type_id, nivel, estado, slot, concluido_em, ultimo_ciclo_em)
    values (us.id, bt.id, 1, 'construindo', v_slot, v_fim, v_fim);
  end if;

  insert into public.game_log (user_id, tipo, texto, dados)
  values (v_user, 'abrigo', format('Começou a construir: %s.', coalesce(bt.niveis->0->>'nome', bt.nome)), jsonb_build_object('instalacao', bt.slug));
  return public.estado_abrigo();
end;
$$;

-- Melhorar (próximo nível de instalações com níveis, como Residência e Horta)
create or replace function public.melhorar(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  r record;
  v_prox jsonb;
  v_motivo text;
  k text;
  v int;
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;
  perform public.sincronizar_abrigo(v_user);
  select ub.*, bt.niveis, bt.tempo_construcao_dias, bt.nome as tipo_nome into r
    from public.user_buildings ub
    join public.user_shelters us on us.id = ub.user_shelter_id
    join public.building_types bt on bt.id = ub.building_type_id
   where ub.id = p_id and us.user_id = v_user and us.ativo
   for update of ub;
  if not found then raise exception 'Instalação não encontrada.'; end if;
  if r.estado <> 'ativo' then raise exception 'Só dá para melhorar quando estiver ativa.'; end if;
  v_prox := r.niveis->(r.nivel);
  if v_prox is null then raise exception 'Já está no nível máximo.'; end if;
  v_motivo := public.motivo_requisitos(v_user, r.user_shelter_id, (v_prox->'requisitos') - 'requer_nivel_anterior');
  if v_motivo is not null then raise exception '%.', v_motivo; end if;
  if public.falta_custo(v_user, v_prox->'custo') is not null then
    raise exception 'Faltam %.', public.falta_custo(v_user, v_prox->'custo');
  end if;
  for k, v in select key, value::int from jsonb_each_text(v_prox->'custo') loop
    perform public.tirar_item_qualquer(v_user, k, v);
  end loop;
  update public.user_buildings
     set nivel = nivel + 1, estado = 'construindo', progresso_dias = 0,
         concluido_em = now() + make_interval(secs => (r.tempo_construcao_dias / (public.cfg('tempo.dias_jogo_por_hora_real'))::numeric * 3600)::double precision)
   where id = r.id;
  insert into public.game_log (user_id, tipo, texto) values (v_user, 'abrigo', format('Melhorando: %s.', v_prox->>'nome'));
  return public.estado_abrigo();
end;
$$;

-- Coletar a produção de uma instalação (ou de todas, com p_id nulo) para o depósito
create or replace function public.coletar_producao(p_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  us public.user_shelters%rowtype;
  b record;
  v_item text;
  v_guardado int;
  v_total int := 0;
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;
  perform public.sincronizar_abrigo(v_user);
  select * into us from public.user_shelters where user_id = v_user and ativo for update;
  if not found then raise exception 'Escolha um abrigo primeiro.'; end if;

  for b in
    select ub.* from public.user_buildings ub
     where ub.user_shelter_id = us.id and floor(ub.producao_acumulada) >= 1 and (p_id is null or ub.id = p_id)
     for update
  loop
    v_item := public.item_produzido(b.building_type_id, b.nivel);
    -- A produção acumulada já tinha espaço reservado; tira da conta antes de guardar
    update public.user_buildings set producao_acumulada = producao_acumulada - floor(b.producao_acumulada) where id = b.id;
    v_guardado := public.por_deposito(v_user, us.id, v_item, floor(b.producao_acumulada)::int);
    if v_guardado < floor(b.producao_acumulada) then
      update public.user_buildings set producao_acumulada = producao_acumulada + (floor(b.producao_acumulada) - v_guardado) where id = b.id;
    end if;
    v_total := v_total + v_guardado;
  end loop;
  if v_total = 0 and p_id is not null and not exists (select 1 from public.user_buildings where id = p_id and user_shelter_id = us.id) then
    raise exception 'Instalação não encontrada.';
  end if;
  if v_total > 0 then
    insert into public.game_log (user_id, tipo, texto) values (v_user, 'abrigo', format('Coletou %s item(ns) da produção.', v_total));
  end if;
  return public.estado_abrigo() || jsonb_build_object('coletado', v_total);
end;
$$;

-- Desmontar (só gerador, rádio e painel solar): devolve parte do custo e libera o espaço
create or replace function public.desmontar(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  r record;
  k text;
  v numeric;
  v_pct numeric := (public.cfg('abrigo.desmontar_reembolso_pct'))::numeric;
  v_itens jsonb := '[]'::jsonb;
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;
  perform public.sincronizar_abrigo(v_user);
  select ub.id, bt.slug, bt.nome, bt.custo, bt.desmontavel, bt.requisitos into r
    from public.user_buildings ub
    join public.user_shelters us on us.id = ub.user_shelter_id
    join public.building_types bt on bt.id = ub.building_type_id
   where ub.id = p_id and us.user_id = v_user and us.ativo
   for update of ub;
  if not found then raise exception 'Instalação não encontrada.'; end if;
  if not r.desmontavel then raise exception 'Esta instalação não pode ser desmontada.'; end if;

  for k, v in select key, value::numeric from jsonb_each_text(r.custo) loop
    if floor(v * v_pct / 100) > 0 then
      v_itens := v_itens || jsonb_build_array(jsonb_build_object('item', k, 'qtd', floor(v * v_pct / 100)));
    end if;
  end loop;
  if r.requisitos ? 'item_chave' then
    v_itens := v_itens || jsonb_build_array(jsonb_build_object('item', r.requisitos->>'item_chave', 'qtd', 1));
  end if;
  delete from public.user_buildings where id = r.id;
  perform public.entregar_itens(v_user, v_itens);
  insert into public.game_log (user_id, tipo, texto) values (v_user, 'abrigo', format('Desmontou: %s.', r.nome));
  return public.estado_abrigo();
end;
$$;

-- Reparar instalação danificada (os danos vêm dos ataques, na Fase 10)
create or replace function public.reparar_instalacao(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  r record;
  v_custo jsonb;
  k text;
  v int;
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;
  select ub.id, ub.estado, bt.custo, bt.nome into r
    from public.user_buildings ub
    join public.user_shelters us on us.id = ub.user_shelter_id
    join public.building_types bt on bt.id = ub.building_type_id
   where ub.id = p_id and us.user_id = v_user and us.ativo
   for update of ub;
  if not found then raise exception 'Instalação não encontrada.'; end if;
  if r.estado <> 'danificado' then raise exception 'Esta instalação não está danificada.'; end if;
  select coalesce(jsonb_object_agg(c.key, ceil(c.value::numeric * (public.cfg('abrigo.reparo_custo_pct'))::numeric / 100)), '{}'::jsonb)
    into v_custo from jsonb_each_text(r.custo) c;
  if public.falta_custo(v_user, v_custo) is not null then
    raise exception 'Faltam %.', public.falta_custo(v_user, v_custo);
  end if;
  for k, v in select key, value::int from jsonb_each_text(v_custo) loop
    perform public.tirar_item_qualquer(v_user, k, v);
  end loop;
  update public.user_buildings set estado = 'ativo', dano = 0 where id = r.id;
  insert into public.game_log (user_id, tipo, texto) values (v_user, 'abrigo', format('Reparou: %s.', r.nome));
  return public.estado_abrigo();
end;
$$;

-- Oficina de reciclagem: converte sucata em metal (3:1) ou componentes (5:1), na hora, com energia
create or replace function public.reciclar(p_produto text, p_vezes int)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  us public.user_shelters%rowtype;
  v_conv jsonb;
  v_taxa int;
  v_slug text;
  v_guardado int;
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;
  perform public.sincronizar_abrigo(v_user);
  select * into us from public.user_shelters where user_id = v_user and ativo for update;
  if not found then raise exception 'Escolha um abrigo primeiro.'; end if;
  select bt.producao->'conversoes' into v_conv
    from public.user_buildings ub join public.building_types bt on bt.id = ub.building_type_id
   where ub.user_shelter_id = us.id and bt.slug = 'oficina_reciclagem' and ub.estado = 'ativo';
  if v_conv is null then raise exception 'Você precisa de uma Oficina de reciclagem pronta.'; end if;
  if not us.energia_ok then raise exception 'A oficina de reciclagem precisa de energia.'; end if;
  if p_vezes is null or p_vezes < 1 or p_vezes > 50 then raise exception 'Quantidade inválida.'; end if;
  if p_produto = 'metal' then v_taxa := (v_conv->>'sucata_para_metal')::int; v_slug := 'metal';
  elsif p_produto = 'componentes' then v_taxa := (v_conv->>'sucata_para_componentes')::int; v_slug := 'componentes_eletronicos';
  else raise exception 'Conversão inválida.'; end if;

  perform public.tirar_item_qualquer(v_user, 'sucata', v_taxa * p_vezes);
  v_guardado := public.por_deposito(v_user, us.id, v_slug, p_vezes);
  if v_guardado < p_vezes then
    perform public.entregar_itens(v_user, jsonb_build_array(jsonb_build_object('item', v_slug, 'qtd', p_vezes - v_guardado)));
  end if;
  insert into public.game_log (user_id, tipo, texto)
  values (v_user, 'abrigo', format('Reciclou %s sucata em %s %s.', v_taxa * p_vezes, p_vezes, (select nome from public.items where slug = v_slug)));
  return public.estado_abrigo();
end;
$$;

-- Mover itens entre mochila e depósito
create or replace function public.transferir_item(p_inventory_id uuid, p_qtd int, p_destino text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_us uuid;
  r record;
  v_guardado int;
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;
  v_us := public.abrigo_ativo(v_user);
  if v_us is null then raise exception 'Você ainda não tem abrigo.'; end if;
  if p_destino not in ('mochila', 'deposito') then raise exception 'Destino inválido.'; end if;
  select i.id, i.local, i.quantidade, i.durabilidade, i.user_shelter_id, it.slug, it.empilhavel, it.nome into r
    from public.inventory i join public.items it on it.id = i.item_id
   where i.id = p_inventory_id and i.user_id = v_user
   for update of i;
  if not found then raise exception 'Item não encontrado.'; end if;
  if r.local = p_destino then raise exception 'O item já está aí.'; end if;
  if r.local = 'deposito' and r.user_shelter_id <> v_us then raise exception 'Item não encontrado.'; end if;
  if p_qtd is null or p_qtd < 1 or p_qtd > r.quantidade then raise exception 'Quantidade inválida.'; end if;
  if exists (select 1 from public.equipment where inventory_id = r.id) then raise exception 'Desequipe a arma antes de guardar.'; end if;
  if exists (select 1 from public.expeditions where arma_id = r.id and estado in ('em_andamento', 'aguardando_evento')) then
    raise exception 'Essa arma está numa expedição.';
  end if;

  if not r.empilhavel then
    -- Armas: muda a linha de lugar (mantém a durabilidade)
    if p_destino = 'deposito' and public.capacidade_deposito(v_us) - public.uso_deposito(v_us) < (select peso from public.items where slug = r.slug) then
      raise exception 'Não cabe no depósito.';
    end if;
    update public.inventory set local = p_destino, user_shelter_id = case when p_destino = 'deposito' then v_us else null end where id = r.id;
  elsif p_destino = 'deposito' then
    v_guardado := public.por_deposito(v_user, v_us, r.slug, p_qtd);
    if v_guardado = 0 then raise exception 'Não cabe no depósito.'; end if;
    if v_guardado = r.quantidade then delete from public.inventory where id = r.id;
    else update public.inventory set quantidade = quantidade - v_guardado where id = r.id; end if;
  else
    if r.quantidade = p_qtd then delete from public.inventory where id = r.id;
    else update public.inventory set quantidade = quantidade - p_qtd where id = r.id; end if;
    update public.inventory set quantidade = quantidade + p_qtd
     where user_id = v_user and item_id = (select id from public.items where slug = r.slug) and local = 'mochila' and durabilidade is null;
    if not found then
      insert into public.inventory (user_id, item_id, local, quantidade) values (v_user, (select id from public.items where slug = r.slug), 'mochila', p_qtd);
    end if;
  end if;
  return jsonb_build_object('mensagem', case when p_destino = 'deposito' then format('Guardado no depósito: %s.', r.nome)
                                             else format('Na mochila: %s.', r.nome) end,
                            'inventario', public.estado_inventario());
end;
$$;

-- ---------------------------------------------------------------------------
-- (custo da missão: a Saída reforçada vale assim que fica pronta)
-- Funções atualizadas das fases anteriores
-- (consumíveis podem vir do depósito; o estado do personagem traz o resumo do abrigo)
-- ---------------------------------------------------------------------------
create or replace function public.iniciar_expedicao(p_missao text, p_arma uuid default null, p_consumiveis jsonb default '[]'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  c public.characters%rowtype;
  m public.missions%rowtype;
  v_motivo text;
  v_b numeric := 0;
  v_peso numeric := 0;
  v_carga numeric;
  v_arma record;
  x jsonb;
  it public.items%rowtype;
  v_qtd int;
  v_tem int;
  v_custo int;
  v_dur numeric;
  v_seed bigint := floor(random() * 9000000000000000)::bigint;
  v_prob numeric;
  v_ruido jsonb := public.cfg('eventos.ruido');
  v_evento uuid := null;
  v_pos jsonb := public.cfg('eventos.posicao_pct');
  v_evento_em numeric := null;
  v_linhas jsonb;
  v_n int := (public.cfg('missao.linhas_log'))::int;
  v_log jsonb := '[]'::jsonb;
  v_id uuid;
  v_consumiveis jsonb := '[]'::jsonb;
  v_peso_arma numeric := 0;
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;

  -- Trava o personagem: duas abas não iniciam duas expedições ao mesmo tempo
  select * into c from public.characters where user_id = v_user for update;
  if not found then raise exception 'Personagem não encontrado.'; end if;

  if exists (select 1 from public.expeditions where user_id = v_user and estado in ('em_andamento', 'aguardando_evento')) then
    raise exception 'Você já está numa expedição.';
  end if;
  if exists (select 1 from public.expeditions where user_id = v_user and estado = 'concluida' and not loot_entregue) then
    raise exception 'Decida o que levar da última expedição antes de sair de novo.';
  end if;

  select * into m from public.missions where slug = p_missao and ativa;
  if not found then raise exception 'Missão não encontrada.'; end if;
  v_motivo := public.motivo_missao_indisponivel(v_user, m.id);
  if v_motivo is not null then raise exception '%', v_motivo; end if;

  -- Arma (opcional): precisa ser sua, estar na mochila, inteira e do seu nível
  if p_arma is not null then
    select i.id, i.durabilidade, it2.nome, it2.peso, it2.nivel_requisito, it2.efeitos into v_arma
      from public.inventory i join public.items it2 on it2.id = i.item_id
     where i.id = p_arma and i.user_id = v_user and i.local = 'mochila' and it2.tipo = 'arma'
     for update of i;
    if not found then raise exception 'Arma inválida.'; end if;
    if coalesce(v_arma.durabilidade, 0) <= 0 then raise exception 'Essa arma está quebrada. Repare antes.'; end if;
    if v_arma.nivel_requisito > c.nivel then raise exception 'Essa arma exige nível %.', v_arma.nivel_requisito; end if;
    v_b := v_b + coalesce((v_arma.efeitos->>'bonus_missao')::numeric, 0);
    v_peso_arma := v_arma.peso;
    v_peso := v_peso + v_peso_arma;
  end if;

  -- Consumíveis (opcional, da mochila ou do depósito): somam bônus e peso, e são gastos na expedição
  if jsonb_typeof(coalesce(p_consumiveis, '[]'::jsonb)) <> 'array' then raise exception 'Dados inválidos.'; end if;
  for x in select * from jsonb_array_elements(coalesce(p_consumiveis, '[]'::jsonb)) loop
    v_qtd := (x->>'qtd')::int;
    if v_qtd is null or v_qtd < 1 or v_qtd > 10 then raise exception 'Quantidade inválida.'; end if;
    select * into it from public.items where slug = x->>'item';
    if not found or it.tipo <> 'consumivel' then raise exception 'Item inválido para levar.'; end if;
    select coalesce(sum(i.quantidade), 0) into v_tem from public.inventory i
     where i.user_id = v_user and i.item_id = it.id and (i.local = 'mochila' or i.user_shelter_id = public.abrigo_ativo(v_user));
    if v_tem < v_qtd then raise exception 'Você não tem % suficiente.', it.nome; end if;
    v_b := v_b + coalesce((it.efeitos->>'bonus_missao')::numeric, 0) * v_qtd;
    v_peso := v_peso + it.peso * v_qtd;
    v_consumiveis := v_consumiveis || jsonb_build_array(jsonb_build_object('item', it.slug, 'qtd', v_qtd));
  end loop;

  v_carga := public.capacidade_carga(v_user);
  if v_peso > v_carga then raise exception 'Peso demais para levar.'; end if;

  -- Paga a stamina (erro "Stamina insuficiente." se faltar) e gasta os consumíveis
  v_custo := public.custo_stamina_missao(v_user, m.id);
  perform public.gastar_stamina(v_user, v_custo);
  for x in select * from jsonb_array_elements(v_consumiveis) loop
    perform public.tirar_item_qualquer(v_user, x->>'item', (x->>'qtd')::int);
  end loop;

  v_dur := coalesce(m.duracao_segundos, (public.cfg('missao.duracao_segundos')->>m.dificuldade)::int);

  -- Evento: chance por dificuldade + ruído − Agilidade
  v_prob := (public.cfg('eventos.probabilidade_pct')->>m.dificuldade)::numeric
          + coalesce((m.especial->>'ruido')::numeric, 0) * (v_ruido->>'pct_por_nivel')::numeric
          - c.agilidade * (v_ruido->>'reducao_pct_por_agilidade')::numeric;
  if public.rolar(v_seed, 'tem_evento') <= least(100, greatest(0, v_prob)) then
    v_evento := public.escolher_evento(v_user, m.id, v_seed);
    if v_evento is not null then
      v_evento_em := public.rolar_entre(v_seed, 'evento_pos', (v_pos->>'min')::int, (v_pos->>'max')::int) / 100.0;
    end if;
  end if;

  -- Linhas de log: sorteia a ordem e espalha pela barra
  select coalesce(jsonb_agg(t.linha order by md5(v_seed::text || t.linha)), '[]'::jsonb) into v_linhas
    from jsonb_array_elements_text(coalesce(m.textos->'log', '[]'::jsonb)) as t(linha);
  v_n := least(v_n, jsonb_array_length(v_linhas));
  for i in 0..v_n - 1 loop
    v_log := v_log || jsonb_build_array(jsonb_build_object('pct', round((i + 1)::numeric / (v_n + 1), 3), 'texto', v_linhas->>i));
  end loop;
  v_log := jsonb_build_array(jsonb_build_object('pct', 0, 'texto', coalesce(m.textos->>'abertura', 'Você sai do abrigo.'))) || v_log;

  insert into public.expeditions (
    user_id, mission_id, estado, iniciada_em, termina_em, seed, evento_id, evento_em, duracao_seg,
    custo_stamina, arma_id, consumiveis, log, carga_max, peso_levado, bonus_b
  ) values (
    v_user, m.id, 'em_andamento', now(), now() + make_interval(secs => v_dur::double precision), v_seed, v_evento, v_evento_em, v_dur,
    v_custo, p_arma, v_consumiveis, v_log, v_carga, v_peso_arma, v_b
  ) returning id into v_id;

  if v_evento is not null then
    update public.characters set ultimo_evento_id = v_evento where id = c.id;
  end if;

  insert into public.game_log (user_id, tipo, texto, dados)
  values (v_user, 'expedicao', format('Saiu em expedição: %s.', m.nome), jsonb_build_object('expedicao', v_id, 'missao', m.slug));

  return jsonb_build_object('id', v_id);
end;
$$;

create or replace function public.usar_item(p_inventory_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_slug text;
  v_nome text;
  v_motivo text;
  v_ganho int;
  v_texto text;
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;
  -- Trava personagem e a linha do item: dois cliques não gastam duas unidades
  perform 1 from public.characters where user_id = v_user for update;
  select it.slug, it.nome into v_slug, v_nome
    from public.inventory i join public.items it on it.id = i.item_id
   where i.id = p_inventory_id and i.user_id = v_user and i.quantidade > 0
     and (i.local = 'mochila' or i.user_shelter_id = public.abrigo_ativo(v_user))
   for update of i;
  if v_slug is null then raise exception 'Item não encontrado.'; end if;

  perform public.aplicar_catchup_stamina(v_user);
  perform public.aplicar_catchup_ferimentos(v_user);
  v_motivo := public.motivo_nao_usar(v_user, v_slug);
  if v_motivo is not null then raise exception '%', v_motivo; end if;

  if public.cfg('stamina.recupera_por_item') ? v_slug then
    v_ganho := (public.cfg('stamina.recupera_por_item')->>v_slug)::int;
    perform public.recuperar_stamina(v_user, v_ganho);
    v_texto := format('Usou %s. Um pouco de energia voltou.', lower(v_nome));
  else
    v_ganho := (public.cfg('itens.cura_ferimento')->>v_slug)::int;
    update public.characters
       set ferimentos = greatest(0, ferimentos - v_ganho),
           ferimento_atualizado_em = case when ferimentos - v_ganho <= 0 then null else ferimento_atualizado_em end
     where user_id = v_user;
    v_texto := format('Usou %s. Dói menos. Um pouco.', lower(v_nome));
  end if;

  perform public.tirar_item_qualquer(v_user, v_slug, 1);
  insert into public.game_log (user_id, tipo, texto, dados) values (v_user, 'item', v_texto, jsonb_build_object('item', v_slug));
  return jsonb_build_object('mensagem', v_texto, 'inventario', public.estado_inventario());
end;
$$;

create or replace function public.estado_personagem(p_user uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c public.characters%rowtype;
  v_nome text;
  v_exp jsonb;
  v_equip jsonb;
  v_abrigo jsonb := null;
  v_us uuid;
begin
  select * into c from public.characters where user_id = p_user;
  if not found then
    return null;
  end if;
  select nome_sobrevivente into v_nome from public.profiles where id = p_user;
  select jsonb_build_object('id', e.id, 'estado', e.estado, 'missao', m.nome, 'termina_em', e.termina_em,
                            'loot_pendente', e.estado = 'concluida' and not e.loot_entregue)
    into v_exp
    from public.expeditions e join public.missions m on m.id = e.mission_id
   where e.user_id = p_user and (e.estado in ('em_andamento', 'aguardando_evento') or (e.estado = 'concluida' and not e.loot_entregue))
   order by e.iniciada_em desc
   limit 1;
  select coalesce(jsonb_object_agg(eq.slot, jsonb_build_object(
           'inventory_id', i.id, 'slug', it.slug, 'nome', it.nome, 'raridade', it.raridade,
           'durabilidade', i.durabilidade, 'durabilidade_max', it.durabilidade_max,
           'bonus', coalesce((it.efeitos->>'bonus_missao')::numeric, 0))), '{}'::jsonb)
    into v_equip
    from public.equipment eq join public.inventory i on i.id = eq.inventory_id join public.items it on it.id = i.item_id
   where eq.user_id = p_user;

  -- Resumo do abrigo para a barra lateral e o Início
  v_us := public.abrigo_ativo(p_user);
  if v_us is not null then
    select jsonb_build_object(
      'nome', s.nome,
      'comida', public.qtd_deposito(v_us, 'comida_enlatada'),
      'agua', public.qtd_deposito(v_us, 'agua_potavel'),
      'combustivel', public.qtd_deposito(v_us, 'combustivel'),
      'energia_ok', us.energia_ok,
      'tem_energia', exists (select 1 from public.user_buildings ub join public.building_types bt on bt.id = ub.building_type_id
                              where ub.user_shelter_id = v_us and bt.categoria = 'energia' and ub.estado = 'ativo'),
      'producao_pronta', (select count(*) from public.user_buildings where user_shelter_id = v_us and floor(producao_acumulada) >= 1),
      'construindo', (select count(*) from public.user_buildings where user_shelter_id = v_us and estado = 'construindo'),
      'alertas', (select count(*) from public.user_buildings where user_shelter_id = v_us and estado in ('parado', 'danificado'))
                 + case when not us.energia_ok then 1 else 0 end)
      into v_abrigo
      from public.user_shelters us join public.shelters s on s.id = us.shelter_id where us.id = v_us;
  end if;

  return jsonb_build_object(
    'nome', v_nome,
    'nivel', c.nivel,
    'nivel_anunciado', c.nivel_anunciado,
    'xp', c.xp,
    'xp_proximo', public.xp_para_subir(c.nivel),
    'pontos_disponiveis', c.pontos_disponiveis,
    'atributos', jsonb_build_object(
      'forca', c.forca, 'agilidade', c.agilidade, 'percepcao', c.percepcao,
      'medicina', c.medicina, 'engenharia', c.engenharia, 'lideranca', c.lideranca
    ),
    'atributo_maximo', (public.cfg('atributos.maximo'))::int,
    'moral', c.moral,
    'stamina_atual', c.stamina_atual,
    'stamina_maxima', public.stamina_maxima(p_user),
    'stamina_atualizada_em', c.stamina_atualizada_em,
    'segundos_por_ponto', (public.cfg('stamina.minutos_por_ponto'))::numeric * 60,
    'tutorial_etapa', c.tutorial_etapa,
    'stats', c.stats,
    'criado_em', c.criado_em,
    'dias_jogo_por_hora_real', (public.cfg('tempo.dias_jogo_por_hora_real'))::numeric,
    'hora_inicial', (public.cfg('tempo.hora_inicial'))::numeric,
    'moral_divisor', (public.cfg('moral.divisor_modificador'))::numeric,
    'ferimentos', c.ferimentos,
    'ferimento_maximo', (public.cfg('ferimento.maximo'))::int,
    'expedicao', v_exp,
    'equipamento', v_equip,
    'abrigo', v_abrigo,
    'bonus_abrigo', public.bonus_atributos_abrigo(p_user),
    'itens_novos', exists (select 1 from public.inventory where user_id = p_user and recebido_em > c.inventario_visto_em),
    'servidor_agora', now()
  );
end;
$$;

create or replace function public.custo_stamina_missao(p_user uuid, p_mission_id uuid)
returns int
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  m public.missions%rowtype;
  v_custo int;
  v_extra int := 0;
  v_removido_por text;
begin
  select * into m from public.missions where id = p_mission_id;
  v_custo := coalesce(m.custo_stamina, (public.cfg('stamina.custo_por_dificuldade')->>m.dificuldade)::int);

  -- Porão da mercearia: +1 para sair, até construir a "Saída reforçada"
  select coalesce((s.desvantagens->>'custo_stamina_saida_extra')::int, 0), s.desvantagens->>'removido_por'
    into v_extra, v_removido_por
    from public.user_shelters us join public.shelters s on s.id = us.shelter_id
   where us.user_id = p_user and us.ativo
   limit 1;
  if coalesce(v_extra, 0) > 0 and v_removido_por is not null and exists (
    select 1 from public.user_buildings ub
      join public.user_shelters us on us.id = ub.user_shelter_id
      join public.building_types bt on bt.id = ub.building_type_id
     where us.user_id = p_user and us.ativo and bt.slug = v_removido_por
       and (ub.estado = 'ativo' or (ub.estado = 'construindo' and ub.concluido_em <= now()))
  ) then
    v_extra := 0;
  end if;
  return v_custo + coalesce(v_extra, 0);
end;
$$;

create or replace function public.sincronizar_estado()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'Sessão expirada. Entre de novo.';
  end if;
  perform public.aplicar_catchup_stamina(v_user);
  perform public.aplicar_catchup_ferimentos(v_user);
  perform public.sincronizar_abrigo(v_user);
  return public.estado_personagem(v_user);
end;
$$;

-- Inventário (cópia da 0009): capacidade real do depósito (com a instalação Depósito) e catch-up do abrigo
create or replace function public.estado_inventario()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  c public.characters%rowtype;
  v_itens jsonb;
  v_peso numeric;
  v_abrigo uuid;
  v_dep_usado numeric := 0;
begin
  if v_user is null then raise exception 'Sessão expirada. Entre de novo.'; end if;
  perform public.aplicar_catchup_stamina(v_user);
  perform public.aplicar_catchup_ferimentos(v_user);
  perform public.sincronizar_abrigo(v_user);
  select * into c from public.characters where user_id = v_user;
  if not found then raise exception 'Personagem não encontrado.'; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
      'id', i.id, 'slug', it.slug, 'nome', it.nome, 'tipo', it.tipo, 'subtipo', it.subtipo, 'raridade', it.raridade,
      'peso', it.peso, 'descricao', it.descricao, 'efeitos', it.efeitos, 'quantidade', i.quantidade,
      'durabilidade', i.durabilidade, 'durabilidade_max', it.durabilidade_max, 'nivel_requisito', it.nivel_requisito,
      'local', i.local, 'equipado', eq.slot,
      'em_expedicao', exists (select 1 from public.expeditions e where e.arma_id = i.id and e.estado in ('em_andamento', 'aguardando_evento')),
      'novo', i.recebido_em > c.inventario_visto_em,
      'motivo_nao_usar', public.motivo_nao_usar(v_user, it.slug),
      'recupera_stamina', (public.cfg('stamina.recupera_por_item')->>it.slug)::int,
      'cura_ferimento', (public.cfg('itens.cura_ferimento')->>it.slug)::int
    ) order by case it.tipo when 'arma' then 1 when 'consumivel' then 2 when 'recurso' then 3 else 4 end, it.nome), '[]'::jsonb),
    coalesce(sum(it.peso * i.quantidade) filter (where i.local = 'mochila'), 0)
    into v_itens, v_peso
    from public.inventory i
    join public.items it on it.id = i.item_id
    left join public.equipment eq on eq.inventory_id = i.id
   where i.user_id = v_user and i.quantidade > 0;

  select id into v_abrigo from public.user_shelters where user_id = v_user and ativo limit 1;
  if v_abrigo is not null then
    v_dep_usado := public.uso_deposito(v_abrigo);
  end if;

  return jsonb_build_object(
    'itens', v_itens,
    'peso_mochila', v_peso,
    'carga_max', public.capacidade_carga(v_user),
    'deposito', jsonb_build_object('tem_abrigo', v_abrigo is not null,
                                   'capacidade', case when v_abrigo is null then 0 else public.capacidade_deposito(v_abrigo) end, 'usado', v_dep_usado),
    'visto_em', c.inventario_visto_em
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Permissões
-- ---------------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array[
    'abrigo_ativo(uuid)', 'capacidade_deposito(uuid)', 'uso_deposito(uuid)', 'dados_nivel(uuid, int)', 'item_produzido(uuid, int)',
    'qtd_deposito(uuid, text)', 'uso_acumulado(uuid)', 'por_deposito(uuid, uuid, text, int)', 'tirar_deposito(uuid, text, int)',
    'qtd_total(uuid, text)', 'tirar_item_qualquer(uuid, text, int)', 'entregar_itens(uuid, jsonb)', 'demanda_energia(uuid)',
    'sincronizar_abrigo(uuid)', 'bonus_atributos_abrigo(uuid)', 'atributos_efetivos(uuid, text)', 'texto_custo(jsonb)',
    'falta_custo(uuid, jsonb)', 'motivo_requisitos(uuid, uuid, jsonb)', 'motivo_nao_construir(uuid, uuid, uuid)',
    'estado_personagem(uuid)',
    'estado_abrigo()', 'escolher_abrigo_inicial(text)', 'construir(text, int)', 'melhorar(uuid)', 'coletar_producao(uuid)',
    'desmontar(uuid)', 'reparar_instalacao(uuid)', 'reciclar(text, int)', 'transferir_item(uuid, int, text)',
    'iniciar_expedicao(text, uuid, jsonb)', 'usar_item(uuid)', 'sincronizar_estado()', 'custo_stamina_missao(uuid, uuid)'
  ] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
  -- Ações que o site pode pedir
  foreach f in array array[
    'estado_abrigo()', 'escolher_abrigo_inicial(text)', 'construir(text, int)', 'melhorar(uuid)', 'coletar_producao(uuid)',
    'desmontar(uuid)', 'reparar_instalacao(uuid)', 'reciclar(text, int)', 'transferir_item(uuid, int, text)',
    'iniciar_expedicao(text, uuid, jsonb)', 'usar_item(uuid)', 'sincronizar_estado()'
  ] loop
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ======== seed/seed_game_config.sql ========
-- Constantes de balanceamento. TODAS provisórias (marcadas como provisorio = true).
-- "do nothing": rodar de novo NÃO apaga valores que você já editou.

insert into public.game_config (chave, valor, descricao, provisorio) values
  ('tempo.dias_jogo_por_hora_real', '1', 'Dias do jogo que passam a cada 1 hora real (1 = uma hora real vale um dia do jogo)', true),
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
  ('molotov', 'Molotov', 'consumivel', null, 'incomum', 1, 'Garrafa, pano e combustível. Arremessar de longe.', '{"bonus_missao":4}', null, 1, true),
  ('sinalizador', 'Sinalizador', 'consumivel', null, 'incomum', 1, 'Chama a atenção. Escolha bem de quem.', '{"bonus_missao":2}', null, 1, true),

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
-- Produção e manutenção usam os slugs dos itens (comida_enlatada, agua_potavel, combustivel...).
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
   '[{"nivel":1,"nome":"Horta pequena","custo":{"madeira":4},"requisitos":{"espaco_externo":true,"agua":true},"producao":{"comida_enlatada":1,"ciclo_dias":2},"manutencao":{"agua_potavel":1,"a_cada_ciclos":3}},
     {"nivel":2,"nome":"Horta grande","custo":{"madeira":6,"metal":2},"requisitos":{"engenharia":4},"producao":{"comida_enlatada":2,"ciclo_dias":2,"extra":1,"chance_extra_pct":25},"manutencao":{"agua_potavel":1,"a_cada_ciclos":2}}]',
   '{"comida_enlatada":1,"ciclo_dias":2}', '{"agua_potavel":1,"a_cada_ciclos":3}', 0, '{}', false, 14),
  ('captacao_agua', 'Captação de água', 'producao', 'Calhas, funil e fé na chuva.',
   '{"plastico":3,"sucata":2}', '{"chuva":true}', 1, '[]',
   '{"agua_potavel":1,"ciclo_dias":1}', '{}', 0, '{}', false, 15),
  ('galinheiro', 'Galinheiro', 'producao', 'Ovos como moeda, penas como consequência.',
   '{"madeira":2}', '{}', 1, '[]',
   '{"comida_enlatada":1,"ciclo_dias":1}', '{"comida_enlatada":1,"a_cada_ciclos":5}', 0, '{}', false, 16),
  ('armadilha_caca', 'Armadilha de caça', 'producao', 'Cordas, arame e um pouco de crueldade necessária.',
   '{"sucata":3,"madeira":2}', '{"percepcao":3}', 1, '[]',
   '{"comida_enlatada":1,"ciclo_dias":3}', '{"sucata":1,"a_cada_ciclos":4}', 0, '{}', false, 17),
  ('oficina_reciclagem', 'Oficina de reciclagem', 'producao', 'Transforma lixo em coisas menos lixo.',
   '{"metal":6,"pecas_mecanicas":4}', '{"instalacao":"oficina","engenharia":5}', 2, '[]',
   '{"conversoes":{"sucata_para_metal":3,"sucata_para_componentes":5},"modo":"manual_instantaneo"}', '{}', 1, '{}', false, 18),
  ('destilaria', 'Destilaria improvisada', 'producao', 'Cheiro péssimo, resultado inflamável.',
   '{"metal":8,"pecas_mecanicas":4,"vidro":4}', '{"engenharia":6}', 3, '[]',
   '{"combustivel":1,"ciclo_dias":5}', '{"comida_enlatada":2,"agua_potavel":2,"a_cada_ciclos":1}', 1, '{}', false, 19)
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

-- ======== seed/seed_missions.sql ========
-- Catálogo de missões (65 missões, pelo menos 2 por local). Pode rodar de novo (atualiza os textos).
-- Custo de stamina, duração e XP ficam vazios (null) = usam os valores por dificuldade da tabela game_config.
-- Para dar um valor só a uma missão, preencha custo_stamina, duracao_segundos ou xp_base dela.
--
-- pesos:     % de cada atributo na habilidade H (somam 100)
-- loot:      lista de {item, chance %, min, max}. "alta_qualidade": combustível de alta qualidade
-- requisitos: {"nivel": N, "itens": ["slug"]} (além do requisito da região)
-- especial:  riscos (vazamento, incendio, explosao), ruido (atrai eventos hostis), recruta_chance (%)
-- textos:    abertura + linhas de log (8 por missão; a expedição sorteia a ordem na Fase 5)

insert into public.missions (slug, nome, location_id, ponto, categoria, dificuldade, pesos, loot, requisitos, especial, textos, ordem)
select v.slug, v.nome, l.id, v.ponto, v.categoria, v.dificuldade, v.pesos, v.loot, v.requisitos, v.especial, v.textos, v.ordem
from (values
  ('coletar_madeira_praca', 'Coletar madeira', 'praca_do_lotus', null, 'coleta_materiais', 'facil', '{"forca": 50, "percepcao": 25, "agilidade": 25}'::jsonb, '[{"item": "madeira", "chance": 100, "min": 2, "max": 4}, {"item": "sucata", "chance": 40, "min": 1, "max": 2}, {"item": "tecido", "chance": 20, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "Os bancos da praça não vão mais servir para ninguém sentar. Já para uma fogueira ou uma barricada...", "log": ["Você arranca a primeira tábua. O barulho é alto demais para o seu gosto.", "Um pombo te encara como se você estivesse depredando patrimônio público. Está.", "Os pregos resistem mais que os antigos moradores.", "A pilha de madeira cresce. A sensação de estar sendo observado também.", "Um cachorro magro observa de longe e decide que você não vale o esforço.", "Um portão range sozinho. Você finge que não ouviu.", "Você separa o útil do inútil. O inútil é maioria.", "A mochila pesa mais a cada achado, e as costas reclamam."]}'::jsonb, 1),
  ('revirar_feira_lotus', 'Revirar as barracas da feira', 'praca_do_lotus', null, 'exploracao', 'facil', '{"percepcao": 50, "agilidade": 30, "forca": 20}'::jsonb, '[{"item": "comida_enlatada", "chance": 60, "min": 1, "max": 2}, {"item": "agua_potavel", "chance": 50, "min": 1, "max": 2}, {"item": "plastico", "chance": 50, "min": 1, "max": 3}, {"item": "tecido", "chance": 30, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "A feira de domingo nunca desmontou. As lonas ainda cobrem o que sobrou da última xepa.", "log": ["Uma barraca de pastel. O óleo virou pedra, o cheiro não.", "Você encontra uma caixa de enlatados atrás do caixote de laranjas.", "Um feirante ainda está de avental. Ainda está \"trabalhando\". Você desvia.", "Lonas balançam ao vento como se alguém passasse por baixo.", "O vento arrasta um saco plástico pela rua como se fosse a última notícia do dia.", "Alguém escreveu \"VOLTO JÁ\" numa porta. Faz meses.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 2),
  ('vasculhar_estoque_joaquim', 'Vasculhar o estoque dos fundos', 'mercearia_do_joaquim', null, 'exploracao', 'facil', '{"percepcao": 60, "agilidade": 20, "forca": 20}'::jsonb, '[{"item": "comida_enlatada", "chance": 80, "min": 1, "max": 3}, {"item": "agua_potavel", "chance": 70, "min": 1, "max": 3}, {"item": "plastico", "chance": 30, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "O Joaquim jurava que o estoque dos fundos estava vazio. O Joaquim mentia para o fiscal, não para você.", "log": ["A porta do estoque está emperrada com um saco de feijão.", "Prateleiras altas, escuras e cheias de caixas com promessas.", "Ratos fugiram com metade do arroz. Deixaram as latas, por falta de abridor.", "Um caderno de fiado no chão. Ninguém vai pagar, ninguém vai cobrar.", "Um portão range sozinho. Você finge que não ouviu.", "Um cachorro magro observa de longe e decide que você não vale o esforço.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 1),
  ('limpar_deposito_joaquim', 'Limpar o depósito infestado', 'mercearia_do_joaquim', null, 'combate', 'media', '{"forca": 50, "agilidade": 30, "percepcao": 20}'::jsonb, '[{"item": "comida_enlatada", "chance": 90, "min": 2, "max": 4}, {"item": "agua_potavel", "chance": 80, "min": 2, "max": 3}, {"item": "madeira", "chance": 40, "min": 1, "max": 3}, {"item": "pe_de_cabra", "chance": 10, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "O depósito tem comida para semanas e um problema: os antigos clientes ainda estão lá dentro, em fila.", "log": ["Você bate na porta. Algo do outro lado bate de volta.", "O primeiro cai sem cerimônia. O segundo traz amigos.", "Entre as prateleiras, o espaço é apertado demais para errar.", "Silêncio. Só o zumbido da geladeira desligada na sua cabeça.", "Alguém escreveu \"VOLTO JÁ\" numa porta. Faz meses.", "O vento arrasta um saco plástico pela rua como se fosse a última notícia do dia.", "Você aperta a arma com força. Eles não sabem o que é medo, você sabe por dois.", "Gemidos se aproximam em ritmo de procissão."]}'::jsonb, 2),
  ('galoes_oficina', 'Vasculhar a oficina por galões', 'oficina_dois_irmaos', null, 'coleta_combustivel', 'facil', '{"percepcao": 60, "forca": 40}'::jsonb, '[{"item": "combustivel", "chance": 100, "min": 1, "max": 2}, {"item": "pecas_mecanicas", "chance": 40, "min": 1, "max": 2}, {"item": "sucata", "chance": 40, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{"riscos": ["vazamento", "incendio"], "ruido": 1}'::jsonb, '{"abertura": "Os dois irmãos guardavam galões em todo canto: atrás do compressor, embaixo da bancada, dentro de um pneu.", "log": ["Você chacoalha um galão: vazio. O próximo também. O terceiro responde com um som promissor.", "Um elevador de carro range quando você passa por baixo. Você passa rápido.", "Cheiro de graxa e gasolina velha. O perfume da sobrevivência.", "Atrás do armário de ferramentas, dois galões e um calendário de 2019.", "Um cachorro magro observa de longe e decide que você não vale o esforço.", "Um portão range sozinho. Você finge que não ouviu.", "O cheiro de gasolina avisa que você está perto, e que qualquer faísca é má ideia.", "Você enche o galão devagar. Pressa e combustível não combinam."]}'::jsonb, 1),
  ('desmontar_carros_oficina', 'Desmontar carros na garagem', 'oficina_dois_irmaos', null, 'coleta_materiais', 'facil', '{"engenharia": 50, "forca": 30, "percepcao": 20}'::jsonb, '[{"item": "pecas_mecanicas", "chance": 90, "min": 1, "max": 3}, {"item": "sucata", "chance": 80, "min": 2, "max": 4}, {"item": "fios_cabos", "chance": 40, "min": 1, "max": 2}, {"item": "metal", "chance": 40, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "Três carros esperando conserto. O conserto não vem, então eles viram peça.", "log": ["A chave de roda escapa e cai com um estrondo. Você congela por alguns segundos.", "O alternador sai inteiro. Pequenas vitórias.", "Um rádio de carro liga sozinho com estática. Você desliga com força.", "Fios descascados, porcas espalhadas, dedos sujos. Trabalho honesto.", "O vento arrasta um saco plástico pela rua como se fosse a última notícia do dia.", "Alguém escreveu \"VOLTO JÁ\" numa porta. Faz meses.", "Você separa o útil do inútil. O inútil é maioria.", "A mochila pesa mais a cada achado, e as costas reclamam."]}'::jsonb, 2),
  ('recolher_tecidos_lavanderia', 'Recolher tecidos limpos', 'lavanderia_brisa_limpa', null, 'coleta_materiais', 'facil', '{"percepcao": 40, "agilidade": 40, "forca": 20}'::jsonb, '[{"item": "tecido", "chance": 100, "min": 2, "max": 4}, {"item": "plastico", "chance": 40, "min": 1, "max": 2}, {"item": "agua_potavel", "chance": 20, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "Pilhas de roupa lavada e passada que nunca foram buscadas. O serviço foi impecável; o cliente, não.", "log": ["Lençóis dobrados com perfeição militar. Uma pena desmanchar.", "Uma máquina de lavar abre a porta sozinha. Só o eco dentro dela.", "Você enche a mochila de panos que ainda cheiram a amaciante.", "Um tíquete de retirada no balcão: \"pronto quinta-feira\". Qual quinta?", "Um portão range sozinho. Você finge que não ouviu.", "Um cachorro magro observa de longe e decide que você não vale o esforço.", "Você separa o útil do inútil. O inútil é maioria.", "A mochila pesa mais a cada achado, e as costas reclamam."]}'::jsonb, 1),
  ('resgate_lavanderia', 'Resgatar quem se trancou na lavanderia', 'lavanderia_brisa_limpa', null, 'resgate', 'media', '{"agilidade": 30, "lideranca": 30, "medicina": 20, "forca": 20}'::jsonb, '[{"item": "tecido", "chance": 70, "min": 1, "max": 3}, {"item": "bandagem", "chance": 40, "min": 1, "max": 1}, {"item": "agua_potavel", "chance": 40, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{"recruta_chance": 50}'::jsonb, '{"abertura": "Alguém escreveu \"SOCORRO\" com sabão na vitrine. Por dentro. E o sabão ainda está fresco.", "log": ["Você bate três vezes na porta dos fundos. Alguém responde com duas.", "A pessoa lá dentro empurrou secadoras contra a porta. Esperta.", "Do lado de fora, curiosos sem pulso começam a se juntar.", "Você conversa baixo pela fresta. Confiança se ganha devagar.", "Alguém escreveu \"VOLTO JÁ\" numa porta. Faz meses.", "O vento arrasta um saco plástico pela rua como se fosse a última notícia do dia.", "Uma voz fraca responde ao seu chamado. Pode ser gente. Pode ser eco.", "Você marca o caminho de volta. Desta vez não vai voltar sozinho."]}'::jsonb, 2),
  ('explorar_rua_residencial', 'Explorar rua residencial', 'conjunto_primavera', null, 'exploracao', 'facil', '{"percepcao": 50, "agilidade": 25, "forca": 15, "medicina": 10}'::jsonb, '[{"item": "comida_enlatada", "chance": 50, "min": 1, "max": 2}, {"item": "agua_potavel", "chance": 50, "min": 1, "max": 2}, {"item": "madeira", "chance": 40, "min": 1, "max": 2}, {"item": "tecido", "chance": 30, "min": 1, "max": 2}, {"item": "bandagem", "chance": 20, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "A rua atrás do Conjunto Primavera: casas iguais, portões abertos e caixas de correio lotadas de contas que ninguém vai pagar.", "log": ["Uma bicicleta infantil caída no meio da calçada. Você contorna sem olhar demais.", "A primeira casa tem a porta escancarada e a geladeira também.", "No varal, roupas secando há meses. Já devem estar secas.", "Um gato atravessa a rua sem pressa. Pelo menos alguém está tranquilo.", "Um cachorro magro observa de longe e decide que você não vale o esforço.", "Um portão range sozinho. Você finge que não ouviu.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 1),
  ('despejar_bloco_c', 'Despejar os moradores do bloco C', 'conjunto_primavera', null, 'combate', 'media', '{"forca": 45, "agilidade": 35, "percepcao": 20}'::jsonb, '[{"item": "comida_enlatada", "chance": 70, "min": 1, "max": 3}, {"item": "madeira", "chance": 60, "min": 2, "max": 3}, {"item": "kit_primeiros_socorros", "chance": 15, "min": 1, "max": 1}, {"item": "bastao_de_beisebol", "chance": 10, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "O bloco C nunca pagou o condomínio. Agora não paga e ainda morde. Hora de uma assembleia.", "log": ["A escada está escura. Cada degrau range uma ameaça.", "O síndico ainda está de crachá. Continua sem resolver nada.", "Um apartamento inteiro trancado por dentro. O que está lá não saiu.", "O corredor fica em silêncio. O condomínio, enfim, em dia.", "O vento arrasta um saco plástico pela rua como se fosse a última notícia do dia.", "Alguém escreveu \"VOLTO JÁ\" numa porta. Faz meses.", "Você aperta a arma com força. Eles não sabem o que é medo, você sabe por dois.", "Gemidos se aproximam em ritmo de procissão."]}'::jsonb, 2),
  ('combustivel_onibus_terminal', 'Recuperar combustível dos ônibus', 'terminal_do_bairro_novo', null, 'coleta_combustivel', 'media', '{"engenharia": 40, "percepcao": 30, "agilidade": 30}'::jsonb, '[{"item": "combustivel", "chance": 100, "min": 2, "max": 4}, {"item": "pecas_mecanicas", "chance": 40, "min": 1, "max": 2}, {"item": "plastico", "chance": 30, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{"riscos": ["vazamento", "incendio"], "ruido": 1}'::jsonb, '{"abertura": "Uma fila de ônibus parada desde o último dia. Os tanques de diesel são grandes, e alguns ainda estão cheios.", "log": ["A mangueira improvisada funciona na segunda tentativa. O gosto de diesel, na primeira.", "Dentro de um ônibus, passageiros que nunca desceram no ponto.", "O catraca range quando você esbarra. Todos os passageiros viram a cabeça.", "O galão enche devagar. A paciência esvazia rápido.", "Um portão range sozinho. Você finge que não ouviu.", "Um cachorro magro observa de longe e decide que você não vale o esforço.", "O cheiro de gasolina avisa que você está perto, e que qualquer faísca é má ideia.", "Você enche o galão devagar. Pressa e combustível não combinam."]}'::jsonb, 1),
  ('saquear_posto_bairro_novo', 'Saquear as bombas do posto', 'terminal_do_bairro_novo', 'Posto de gasolina', 'coleta_combustivel', 'media', '{"engenharia": 45, "percepcao": 30, "forca": 25}'::jsonb, '[{"item": "combustivel", "chance": 100, "min": 2, "max": 4}, {"item": "comida_enlatada", "chance": 40, "min": 1, "max": 2}, {"item": "agua_potavel", "chance": 40, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{"riscos": ["vazamento", "incendio"], "ruido": 1}'::jsonb, '{"abertura": "O posto de gasolina ao lado do terminal ainda tem combustível nos tanques subterrâneos. As bombas, porém, não funcionam sem energia.", "log": ["A loja de conveniência foi saqueada, mas esqueceram a geladeira de bebidas.", "Você abre a tampa do tanque subterrâneo. O cheiro sobe como um aviso.", "Uma placa de \"proibido fumar\" nunca fez tanto sentido.", "A bomba manual improvisada range a cada puxada. Lá fora, alguma coisa responde.", "Alguém escreveu \"VOLTO JÁ\" numa porta. Faz meses.", "O vento arrasta um saco plástico pela rua como se fosse a última notícia do dia.", "O cheiro de gasolina avisa que você está perto, e que qualquer faísca é má ideia.", "Você enche o galão devagar. Pressa e combustível não combinam."]}'::jsonb, 2),
  ('revistar_guiches_terminal', 'Revistar os guichês', 'terminal_do_bairro_novo', null, 'exploracao', 'facil', '{"percepcao": 50, "agilidade": 30, "forca": 20}'::jsonb, '[{"item": "plastico", "chance": 60, "min": 1, "max": 3}, {"item": "fios_cabos", "chance": 40, "min": 1, "max": 2}, {"item": "agua_potavel", "chance": 40, "min": 1, "max": 1}, {"item": "componentes_eletronicos", "chance": 20, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "Os guichês de passagem ainda têm cofres, máquinas e lanches esquecidos. Passagem para lugar nenhum, só ida.", "log": ["A máquina de cartão ainda pisca. Pede senha.", "Um quadro de horários anuncia partidas que nunca vão acontecer.", "Você força a gaveta do caixa. Dinheiro não serve, os clipes servem.", "Atrás do balcão, alguém dormia. Ainda dorme. Tomara.", "Um cachorro magro observa de longe e decide que você não vale o esforço.", "Um portão range sozinho. Você finge que não ouviu.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 3),
  ('tabuas_arquibancada', 'Coletar tábuas da arquibancada', 'campo_do_uniao', null, 'coleta_materiais', 'facil', '{"forca": 55, "agilidade": 25, "percepcao": 20}'::jsonb, '[{"item": "madeira", "chance": 100, "min": 2, "max": 5}, {"item": "metal", "chance": 30, "min": 1, "max": 2}, {"item": "tecido", "chance": 20, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "A arquibancada de madeira do União aguentou décadas de torcida. Vai aguentar mais um saque.", "log": ["Uma bandeira do time ainda tremula no alambrado. Você bate continência sem querer.", "As tábuas soltam com facilidade. A manutenção nunca foi o forte do clube.", "Do vestiário vem um barulho de chuteira arrastando.", "No placar enferrujado: União 0, Fim do Mundo 1.", "O vento arrasta um saco plástico pela rua como se fosse a última notícia do dia.", "Alguém escreveu \"VOLTO JÁ\" numa porta. Faz meses.", "Você separa o útil do inútil. O inútil é maioria.", "A mochila pesa mais a cada achado, e as costas reclamam."]}'::jsonb, 1),
  ('resgatar_time_varzea', 'Resgatar o time de várzea', 'campo_do_uniao', null, 'resgate', 'media', '{"lideranca": 40, "agilidade": 30, "forca": 30}'::jsonb, '[{"item": "agua_potavel", "chance": 60, "min": 1, "max": 3}, {"item": "bandagem", "chance": 40, "min": 1, "max": 2}, {"item": "bastao_de_beisebol", "chance": 15, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{"recruta_chance": 60}'::jsonb, '{"abertura": "O time do União se trancou no vestiário durante o jogo de domingo. Faz alguns domingos.", "log": ["Você ouve alguém discutir a escalação do lado de dentro. Bom sinal: estão vivos e teimosos.", "O gramado está alto. Algo se move devagar perto da pequena área.", "O goleiro abre a porta. Ainda de luvas.", "Vocês saem em fila. Desta vez a defesa precisa funcionar.", "Um portão range sozinho. Você finge que não ouviu.", "Um cachorro magro observa de longe e decide que você não vale o esforço.", "Uma voz fraca responde ao seu chamado. Pode ser gente. Pode ser eco.", "Você marca o caminho de volta. Desta vez não vai voltar sozinho."]}'::jsonb, 2),
  ('farmacia_clinica_sao_bento', 'Revirar a farmácia da clínica', 'clinica_sao_bento', null, 'exploracao', 'media', '{"medicina": 40, "percepcao": 40, "agilidade": 20}'::jsonb, '[{"item": "bandagem", "chance": 80, "min": 1, "max": 3}, {"item": "analgesico", "chance": 60, "min": 1, "max": 2}, {"item": "antibiotico", "chance": 30, "min": 1, "max": 1}, {"item": "kit_primeiros_socorros", "chance": 20, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "A Clínica São Bento atendia o bairro inteiro. O estoque da farmácia interna nunca foi contado.", "log": ["A sala de espera tem senha no painel: 47. Ninguém vai chamar.", "Prontuários espalhados pelo chão. Diagnósticos que não importam mais.", "O armário de remédios está trancado. Nada que um pé de cabra não negocie.", "Você lê rótulos à luz da lanterna. Validade é um conceito flexível agora.", "Alguém escreveu \"VOLTO JÁ\" numa porta. Faz meses.", "O vento arrasta um saco plástico pela rua como se fosse a última notícia do dia.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 1),
  ('limpar_sala_espera', 'Limpar a sala de espera', 'clinica_sao_bento', null, 'combate', 'media', '{"forca": 40, "agilidade": 35, "medicina": 25}'::jsonb, '[{"item": "bandagem", "chance": 70, "min": 1, "max": 2}, {"item": "analgesico", "chance": 40, "min": 1, "max": 1}, {"item": "kit_primeiros_socorros", "chance": 25, "min": 1, "max": 1}, {"item": "faca_de_caca", "chance": 10, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "A sala de espera está lotada. Ninguém foi atendido, e ninguém mais tem pressa.", "log": ["As cadeiras de plástico estão viradas. Os pacientes, de pé.", "Um deles ainda segura a pulseira de triagem: \"pouco urgente\".", "A recepção vira barricada no meio da confusão.", "Quando acaba, o silêncio é de hospital de verdade.", "Um cachorro magro observa de longe e decide que você não vale o esforço.", "Um portão range sozinho. Você finge que não ouviu.", "Você aperta a arma com força. Eles não sabem o que é medo, você sabe por dois.", "Gemidos se aproximam em ritmo de procissão."]}'::jsonb, 2),
  ('saquear_farmacia_drogalina', 'Saquear a farmácia', 'farmacia_drogalina', null, 'exploracao', 'media', '{"medicina": 45, "percepcao": 35, "agilidade": 20}'::jsonb, '[{"item": "analgesico", "chance": 80, "min": 1, "max": 3}, {"item": "antibiotico", "chance": 50, "min": 1, "max": 2}, {"item": "bandagem", "chance": 70, "min": 1, "max": 3}, {"item": "antidoto", "chance": 15, "min": 1, "max": 1}, {"item": "kit_primeiros_socorros", "chance": 30, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "A Drogalina tinha de tudo, inclusive promoção de \"leve 3, pague 2\". Agora é \"leve o que der\".", "log": ["As portas de vidro estão rachadas, mas inteiras. Alguém tentou e desistiu.", "Você ignora a prateleira de cosméticos. Quase toda.", "Atrás do balcão, o estoque controlado. Controle nenhum agora.", "Uma voz gravada deseja \"volte sempre\". Você não pretende.", "Carros engavetados formam um labirinto de lataria e paciência.", "Do alto de um prédio, algo cai. Melhor não olhar o que era.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 1),
  ('defender_drogalina', 'Defender a farmácia de uma horda', 'farmacia_drogalina', null, 'combate', 'dificil', '{"forca": 40, "agilidade": 30, "percepcao": 20, "medicina": 10}'::jsonb, '[{"item": "antibiotico", "chance": 70, "min": 1, "max": 2}, {"item": "antidoto", "chance": 40, "min": 1, "max": 1}, {"item": "kit_primeiros_socorros", "chance": 50, "min": 1, "max": 2}, {"item": "glock_17", "chance": 12, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "Você não é o único que lembrou da farmácia. A diferença é que os outros vêm em bando, e não pensam.", "log": ["O primeiro grupo chega pela avenida. O segundo, pelo estacionamento.", "As prateleiras viram barricada. Os remédios, munição de arremesso.", "O vidro da frente finalmente cede.", "Quando a horda rareia, sobra um corredor de caos e caixas de remédio.", "Um alarme de carro tenta, sem sucesso, chamar a atenção de alguém vivo.", "Um letreiro pisca uma promoção que ninguém vai aproveitar.", "Você aperta a arma com força. Eles não sabem o que é medo, você sabe por dois.", "Gemidos se aproximam em ritmo de procissão."]}'::jsonb, 2),
  ('drenar_tanques_estacionamento', 'Drenar tanques de carros abandonados', 'estacionamento_do_ze', null, 'coleta_combustivel', 'facil', '{"engenharia": 55, "percepcao": 45}'::jsonb, '[{"item": "combustivel", "chance": 100, "min": 1, "max": 2}, {"item": "fios_cabos", "chance": 30, "min": 1, "max": 1}, {"item": "plastico", "chance": 30, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{"riscos": ["vazamento", "incendio"], "ruido": 1}'::jsonb, '{"abertura": "Seis andares de carros parados. O Zé cobrava por hora; agora é você que cobra o tanque.", "log": ["A primeira tampa de tanque está trancada. A segunda, não.", "Uma rampa escura leva aos andares de baixo. Você fica no térreo, por enquanto.", "Alarmes antigos disparam com qualquer toque. Tato é tudo.", "O cheiro de gasolina e de borracha queimada enche a garagem.", "Do alto de um prédio, algo cai. Melhor não olhar o que era.", "Carros engavetados formam um labirinto de lataria e paciência.", "O cheiro de gasolina avisa que você está perto, e que qualquer faísca é má ideia.", "Você enche o galão devagar. Pressa e combustível não combinam."]}'::jsonb, 1),
  ('desmanchar_subsolo', 'Desmanchar carros do subsolo', 'estacionamento_do_ze', null, 'coleta_materiais', 'media', '{"engenharia": 45, "forca": 35, "percepcao": 20}'::jsonb, '[{"item": "pecas_mecanicas", "chance": 90, "min": 2, "max": 4}, {"item": "componentes_eletronicos", "chance": 50, "min": 1, "max": 2}, {"item": "fios_cabos", "chance": 60, "min": 1, "max": 3}, {"item": "vidro", "chance": 40, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "No subsolo do Estacionamento do Zé estão os carros bons. E a escuridão boa para esconder coisa ruim.", "log": ["A lanterna ilumina fileiras de carros e um silêncio pesado.", "Um carro importado com a chave no contato. Bateria morta, peças vivas.", "Você trabalha rápido e escuta mais rápido ainda.", "Algo se arrasta entre as colunas. Hora de terminar.", "Um letreiro pisca uma promoção que ninguém vai aproveitar.", "Um alarme de carro tenta, sem sucesso, chamar a atenção de alguém vivo.", "Você separa o útil do inútil. O inútil é maioria.", "A mochila pesa mais a cada achado, e as costas reclamam."]}'::jsonb, 2),
  ('resgatar_professora_jujuba', 'Resgatar a professora', 'escola_infantil_jujuba', null, 'resgate', 'media', '{"lideranca": 40, "agilidade": 30, "medicina": 30}'::jsonb, '[{"item": "comida_enlatada", "chance": 50, "min": 1, "max": 2}, {"item": "agua_potavel", "chance": 60, "min": 1, "max": 2}, {"item": "kit_primeiros_socorros", "chance": 20, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{"recruta_chance": 60}'::jsonb, '{"abertura": "A professora da Escola Jujuba ficou para trás garantindo que todas as crianças saíssem. Todas saíram. Ela não.", "log": ["Desenhos coloridos na parede mostram o que era um dia comum.", "Você encontra a sala trancada com uma cadeirinha minúscula na maçaneta.", "Ela tem um apito e coragem. Os dois ajudam.", "Vocês saem pelo parquinho. O escorregador nunca pareceu tão sinistro.", "Carros engavetados formam um labirinto de lataria e paciência.", "Do alto de um prédio, algo cai. Melhor não olhar o que era.", "Uma voz fraca responde ao seu chamado. Pode ser gente. Pode ser eco.", "Você marca o caminho de volta. Desta vez não vai voltar sozinho."]}'::jsonb, 1),
  ('cozinha_escola_jujuba', 'Explorar a cozinha da escola', 'escola_infantil_jujuba', null, 'exploracao', 'media', '{"percepcao": 50, "agilidade": 30, "forca": 20}'::jsonb, '[{"item": "comida_enlatada", "chance": 80, "min": 2, "max": 3}, {"item": "agua_potavel", "chance": 70, "min": 1, "max": 3}, {"item": "plastico", "chance": 40, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "A merenda era servida às dez. A despensa da escola ainda guarda o cardápio do mês inteiro.", "log": ["Gelatina em pó, leite em pó, tudo em pó. Mas também enlatados.", "Uma panela gigante no fogão. Você não abre a tampa.", "Os corredores são baixos demais e silenciosos demais.", "Você sai com a mochila cheia e a consciência leve.", "Um alarme de carro tenta, sem sucesso, chamar a atenção de alguém vivo.", "Um letreiro pisca uma promoção que ninguém vai aproveitar.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 2),
  ('garimpar_eletronicos_aurora', 'Garimpar eletrônicos', 'galeria_aurora', null, 'coleta_materiais', 'media', '{"engenharia": 50, "percepcao": 30, "agilidade": 20}'::jsonb, '[{"item": "componentes_eletronicos", "chance": 90, "min": 1, "max": 3}, {"item": "fios_cabos", "chance": 80, "min": 1, "max": 3}, {"item": "plastico", "chance": 50, "min": 1, "max": 2}, {"item": "vidro", "chance": 30, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "A Galeria Aurora vendia celulares, capinhas e consertos \"na hora\". A hora passou, os componentes ficaram.", "log": ["Vitrines quebradas e telas apagadas por todos os lados.", "Uma loja de assistência técnica: o paraíso das peças soltas.", "Um televisor de demonstração ainda mostra um logotipo girando.", "Você enrola cabos com a paciência de quem não sabe se vai ter amanhã.", "Do alto de um prédio, algo cai. Melhor não olhar o que era.", "Carros engavetados formam um labirinto de lataria e paciência.", "Você separa o útil do inútil. O inútil é maioria.", "A mochila pesa mais a cada achado, e as costas reclamam."]}'::jsonb, 1),
  ('praca_alimentacao_aurora', 'Atravessar a praça de alimentação', 'galeria_aurora', null, 'combate', 'dificil', '{"agilidade": 40, "forca": 35, "percepcao": 25}'::jsonb, '[{"item": "comida_enlatada", "chance": 70, "min": 2, "max": 4}, {"item": "agua_potavel", "chance": 70, "min": 2, "max": 3}, {"item": "componentes_eletronicos", "chance": 40, "min": 1, "max": 2}, {"item": "beretta_92fs", "chance": 10, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "A praça de alimentação da galeria está cheia. Todos querem comer. Ninguém quer hambúrguer.", "log": ["Bandejas espalhadas, cadeiras derrubadas e uma multidão que se vira para você.", "Você corre entre as mesas. O piso escorrega de óleo antigo.", "Um quiosque de sorvete vira trincheira.", "Do outro lado, a saída de serviço. E silêncio, enfim.", "Um letreiro pisca uma promoção que ninguém vai aproveitar.", "Um alarme de carro tenta, sem sucesso, chamar a atenção de alguém vivo.", "Você aperta a arma com força. Eles não sabem o que é medo, você sabe por dois.", "Gemidos se aproximam em ritmo de procissão."]}'::jsonb, 2),
  ('explorar_hotel_imperial', 'Explorar os andares do hotel', 'hotel_imperial', null, 'exploracao', 'media', '{"percepcao": 45, "agilidade": 35, "forca": 20}'::jsonb, '[{"item": "tecido", "chance": 70, "min": 2, "max": 3}, {"item": "agua_potavel", "chance": 60, "min": 1, "max": 3}, {"item": "comida_enlatada", "chance": 50, "min": 1, "max": 2}, {"item": "analgesico", "chance": 30, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "O Hotel Imperial prometia luxo em cinco estrelas. Hoje entrega frigobares e corredores intermináveis.", "log": ["O carpete abafa os passos. Os seus e os dos outros.", "O frigobar do quarto 304 ainda tem duas águas e um amendoim caro.", "Plaquinhas de \"não perturbe\" em todas as portas. Você respeita.", "O elevador para entre andares desde o primeiro dia. Alguém ainda bate lá dentro.", "Carros engavetados formam um labirinto de lataria e paciência.", "Do alto de um prédio, algo cai. Melhor não olhar o que era.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 1),
  ('resgatar_cobertura_hotel', 'Resgatar hóspedes da cobertura', 'hotel_imperial', null, 'resgate', 'dificil', '{"lideranca": 35, "agilidade": 30, "forca": 20, "medicina": 15}'::jsonb, '[{"item": "agua_potavel", "chance": 70, "min": 2, "max": 3}, {"item": "kit_primeiros_socorros", "chance": 40, "min": 1, "max": 1}, {"item": "sinalizador", "chance": 30, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{"recruta_chance": 70}'::jsonb, '{"abertura": "Luzes piscam na cobertura do Imperial toda noite. Alguém lá em cima ainda pede ajuda em código Morse.", "log": ["Trinta andares de escada. A academia do hotel nunca foi tão útil.", "Cada andar tem sua própria surpresa e nenhuma é boa.", "Na cobertura, um grupo pálido e aliviado.", "Descer é pior que subir. Agora você tem gente para proteger.", "Um alarme de carro tenta, sem sucesso, chamar a atenção de alguém vivo.", "Um letreiro pisca uma promoção que ninguém vai aproveitar.", "Uma voz fraca responde ao seu chamado. Pode ser gente. Pode ser eco.", "Você marca o caminho de volta. Desta vez não vai voltar sozinho."]}'::jsonb, 2),
  ('atacar_horda_estacao', 'Atacar horda', 'estacao_central', null, 'combate', 'dificil', '{"forca": 45, "agilidade": 30, "percepcao": 15, "lideranca": 10}'::jsonb, '[{"item": "metal", "chance": 70, "min": 2, "max": 4}, {"item": "sucata", "chance": 80, "min": 2, "max": 4}, {"item": "kit_reparo", "chance": 30, "min": 1, "max": 1}, {"item": "machado", "chance": 15, "min": 1, "max": 1}, {"item": "ak_47", "chance": 6, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "A plataforma da Estação Central virou ponto de encontro de centenas deles. Diminuir esse número abre caminho para o resto da cidade.", "log": ["O eco da estação multiplica cada gemido por dez.", "Você atrai o primeiro grupo para o corredor estreito. Estratégia de cinema.", "Os trilhos estão cheios. O trem não vem e eles não vão embora.", "Quando a poeira assenta, a plataforma está quase vazia. Quase.", "Do alto de um prédio, algo cai. Melhor não olhar o que era.", "Carros engavetados formam um labirinto de lataria e paciência.", "Você aperta a arma com força. Eles não sabem o que é medo, você sabe por dois.", "Gemidos se aproximam em ritmo de procissão."]}'::jsonb, 1),
  ('explorar_tuneis_metro', 'Explorar os túneis do metrô', 'estacao_central', null, 'exploracao', 'dificil', '{"percepcao": 45, "agilidade": 35, "forca": 20}'::jsonb, '[{"item": "fios_cabos", "chance": 80, "min": 2, "max": 4}, {"item": "componentes_eletronicos", "chance": 50, "min": 1, "max": 2}, {"item": "kit_reparo", "chance": 30, "min": 1, "max": 1}, {"item": "racao_militar", "chance": 20, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "Os túneis do metrô ligam metade da cidade. Escuros, úmidos, e cheios de coisas que a luz incomoda.", "log": ["A lanterna mostra três metros à frente. O resto é imaginação.", "Um trem parado no túnel. As portas, abertas.", "Ratos correm na direção contrária. Eles sabem de algo.", "Uma sala de manutenção com cadeado. Seu dia de sorte.", "Um letreiro pisca uma promoção que ninguém vai aproveitar.", "Um alarme de carro tenta, sem sucesso, chamar a atenção de alguém vivo.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 2),
  ('credencial_engenheiro', 'Recuperar a credencial do engenheiro', 'edificio_horizonte', null, 'exploracao', 'dificil', '{"percepcao": 45, "agilidade": 30, "engenharia": 25}'::jsonb, '[{"item": "credencial_industrial", "chance": 60, "min": 1, "max": 1}, {"item": "componentes_eletronicos", "chance": 60, "min": 1, "max": 2}, {"item": "fios_cabos", "chance": 50, "min": 1, "max": 2}]'::jsonb, '{"nivel": 6}'::jsonb, '{}'::jsonb, '{"abertura": "O Edifício Horizonte abrigava a administração das fábricas. Um engenheiro de lá tinha acesso à Zona Industrial. A credencial dele ainda deve estar no 12º andar.", "log": ["Os crachás no chão mostram rostos que não sorriem mais.", "O 12º andar é um labirinto de baias e telefones mudos.", "Na sala do engenheiro, um porta-retratos e uma gaveta trancada.", "O elevador de serviço range. Você vai de escada, por precaução.", "Carros engavetados formam um labirinto de lataria e paciência.", "Do alto de um prédio, algo cai. Melhor não olhar o que era.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 1),
  ('varrer_edificio_horizonte', 'Varrer o edifício andar por andar', 'edificio_horizonte', null, 'combate', 'media', '{"forca": 40, "agilidade": 35, "percepcao": 25}'::jsonb, '[{"item": "componentes_eletronicos", "chance": 50, "min": 1, "max": 2}, {"item": "vidro", "chance": 60, "min": 1, "max": 3}, {"item": "plastico", "chance": 50, "min": 1, "max": 3}, {"item": "pe_de_cabra", "chance": 15, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "Escritórios em plano aberto. Ninguém mais tem reunião, mas todos ainda estão no expediente.", "log": ["Você limpa o térreo. Faltam só vinte andares.", "A copa tem café vencido e um gerente que ainda morde.", "As escadas de emergência fazem jus ao nome.", "No fim do dia, mais um andar seguro. Sem hora extra.", "Um alarme de carro tenta, sem sucesso, chamar a atenção de alguém vivo.", "Um letreiro pisca uma promoção que ninguém vai aproveitar.", "Você aperta a arma com força. Eles não sabem o que é medo, você sabe por dois.", "Gemidos se aproximam em ritmo de procissão."]}'::jsonb, 2),
  ('saquear_mercado_bom_vizinho', 'Saquear mercado', 'mercado_bom_vizinho', null, 'exploracao', 'media', '{"percepcao": 45, "agilidade": 30, "forca": 25}'::jsonb, '[{"item": "comida_enlatada", "chance": 90, "min": 2, "max": 4}, {"item": "agua_potavel", "chance": 90, "min": 2, "max": 4}, {"item": "racao_militar", "chance": 15, "min": 1, "max": 1}, {"item": "plastico", "chance": 40, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "O Mercado Bom Vizinho é o maior da região. As gôndolas foram reviradas, mas o estoque do depósito é outra história.", "log": ["Carrinhos abandonados formam barricadas no estacionamento.", "O corredor de enlatados está quase intacto. Quase.", "O alto-falante ainda chama \"atendente no caixa 4\". Ninguém vai.", "Você empurra um carrinho com cuidado. Uma roda faz barulho. Sempre faz.", "Do alto de um prédio, algo cai. Melhor não olhar o que era.", "Carros engavetados formam um labirinto de lataria e paciência.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 1),
  ('resgatar_sobrevivente_acougue', 'Resgatar sobrevivente', 'mercado_bom_vizinho', null, 'resgate', 'media', '{"lideranca": 35, "agilidade": 30, "medicina": 20, "forca": 15}'::jsonb, '[{"item": "comida_enlatada", "chance": 60, "min": 1, "max": 2}, {"item": "agua_potavel", "chance": 60, "min": 1, "max": 2}, {"item": "bandagem", "chance": 40, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{"recruta_chance": 70}'::jsonb, '{"abertura": "Há uma semana, alguém se trancou na câmara fria do açougue do Bom Vizinho. Ainda bate na porta ao amanhecer.", "log": ["A câmara fria não é mais fria. O cheiro confirma.", "Você bate. Uma voz rouca pede a senha. Você não tem senha.", "Negociação feita, a porta abre devagar.", "O sobrevivente agradece com as mãos tremendo. Agora é sair.", "Um letreiro pisca uma promoção que ninguém vai aproveitar.", "Um alarme de carro tenta, sem sucesso, chamar a atenção de alguém vivo.", "Uma voz fraca responde ao seu chamado. Pode ser gente. Pode ser eco.", "Você marca o caminho de volta. Desta vez não vai voltar sozinho."]}'::jsonb, 2),
  ('rolos_tecido_fio_norte', 'Recolher rolos de tecido', 'fabrica_textil_fio_norte', null, 'coleta_materiais', 'media', '{"forca": 45, "percepcao": 30, "agilidade": 25}'::jsonb, '[{"item": "tecido", "chance": 100, "min": 3, "max": 6}, {"item": "fios_cabos", "chance": 40, "min": 1, "max": 2}, {"item": "plastico", "chance": 30, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "A Fio Norte produzia tecido para o país inteiro. O galpão ainda guarda rolos para uma cidade.", "log": ["Teares parados no meio de um padrão xadrez.", "Os rolos pesam. A mochila reclama.", "Fiapos voam com qualquer passo, como neve suja.", "Uma sirene de fim de turno toca sozinha. Coisas acordam.", "O cheiro de óleo queimado gruda na roupa e na alma.", "Placas de \"Use EPI\" nunca foram tão sinceras.", "Você separa o útil do inútil. O inútil é maioria.", "A mochila pesa mais a cada achado, e as costas reclamam."]}'::jsonb, 1),
  ('turno_noite_fio_norte', 'Enfrentar o turno da noite', 'fabrica_textil_fio_norte', null, 'combate', 'dificil', '{"forca": 45, "agilidade": 35, "percepcao": 20}'::jsonb, '[{"item": "tecido", "chance": 80, "min": 2, "max": 4}, {"item": "metal", "chance": 50, "min": 1, "max": 3}, {"item": "kit_reparo", "chance": 30, "min": 1, "max": 1}, {"item": "facao", "chance": 15, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "O turno da noite da Fio Norte nunca bateu o ponto de saída. Eles ainda andam entre as máquinas.", "log": ["Uniformes azuis em fila, como numa linha de produção.", "Você usa as máquinas como cobertura. Elas não reclamam.", "O encarregado é maior que os outros. E mais insistente.", "Fim de expediente. Desta vez para todos.", "Um guindaste range com o vento, balançando uma carga esquecida.", "Uma chaminé solta fumaça que ninguém acendeu.", "Você aperta a arma com força. Eles não sabem o que é medo, você sabe por dois.", "Gemidos se aproximam em ritmo de procissão."]}'::jsonb, 2),
  ('reservatorios_sete_trilhos', 'Esvaziar reservatórios do depósito', 'deposito_sete_trilhos', null, 'coleta_combustivel', 'dificil', '{"engenharia": 45, "forca": 30, "percepcao": 25}'::jsonb, '[{"item": "combustivel", "chance": 100, "min": 4, "max": 7}, {"item": "pecas_mecanicas", "chance": 50, "min": 1, "max": 3}, {"item": "metal", "chance": 40, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{"riscos": ["vazamento", "incendio", "explosao"], "ruido": 2}'::jsonb, '{"abertura": "O Depósito Sete Trilhos abastecia locomotivas. Os reservatórios são grandes, velhos e mal-humorados.", "log": ["As válvulas estão emperradas pela ferrugem.", "Um vagão-tanque tomba devagar com um gemido metálico.", "Você mede cada movimento: uma faísca aqui é fim de jogo.", "Os galões enchem. O barulho dos trilhos atrai visitas.", "Placas de \"Use EPI\" nunca foram tão sinceras.", "O cheiro de óleo queimado gruda na roupa e na alma.", "O cheiro de gasolina avisa que você está perto, e que qualquer faísca é má ideia.", "Você enche o galão devagar. Pressa e combustível não combinam."]}'::jsonb, 1),
  ('explorar_vagoes', 'Explorar os vagões', 'deposito_sete_trilhos', null, 'exploracao', 'media', '{"percepcao": 50, "agilidade": 30, "forca": 20}'::jsonb, '[{"item": "metal", "chance": 70, "min": 1, "max": 3}, {"item": "racao_militar", "chance": 30, "min": 1, "max": 2}, {"item": "madeira", "chance": 50, "min": 2, "max": 3}, {"item": "kit_reparo", "chance": 20, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "Vagões de carga parados em sete linhas. Cada um guarda uma surpresa, nem todas boas.", "log": ["Você força a primeira porta de correr. Caixas de madeira.", "Um vagão está cheio de sacos de cimento. Inútil e pesado.", "O terceiro tem marcas de unha por dentro. Você pula esse.", "Um contêiner de suprimentos com o lacre intacto. Raridade.", "Uma chaminé solta fumaça que ninguém acendeu.", "Um guindaste range com o vento, balançando uma carga esquecida.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 2),
  ('tanques_reserva_usina', 'Buscar tanques de reserva da usina', 'usina_termeletrica_vale_cinzento', null, 'coleta_combustivel', 'dificil', '{"engenharia": 40, "percepcao": 35, "forca": 25}'::jsonb, '[{"item": "combustivel", "chance": 100, "min": 5, "max": 8}, {"item": "componentes_eletronicos", "chance": 40, "min": 1, "max": 2}, {"item": "fios_cabos", "chance": 50, "min": 1, "max": 3}]'::jsonb, '{}'::jsonb, '{"riscos": ["vazamento", "incendio", "explosao"], "ruido": 2}'::jsonb, '{"abertura": "A Usina Vale Cinzento guardava combustível de reserva para emergências. Se isso não é emergência, nada é.", "log": ["Turbinas paradas do tamanho de prédios.", "O mapa de evacuação mostra os tanques no subsolo B.", "Medidores de pressão no vermelho. Ninguém para ler.", "Você enche os galões com o coração na garganta.", "O cheiro de óleo queimado gruda na roupa e na alma.", "Placas de \"Use EPI\" nunca foram tão sinceras.", "O cheiro de gasolina avisa que você está perto, e que qualquer faísca é má ideia.", "Você enche o galão devagar. Pressa e combustível não combinam."]}'::jsonb, 1),
  ('sala_controle_usina', 'Religar a sala de controle', 'usina_termeletrica_vale_cinzento', null, 'exploracao', 'dificil', '{"engenharia": 55, "percepcao": 25, "agilidade": 20}'::jsonb, '[{"item": "componentes_eletronicos", "chance": 80, "min": 2, "max": 3}, {"item": "fios_cabos", "chance": 80, "min": 2, "max": 4}, {"item": "kit_reparo", "chance": 30, "min": 1, "max": 1}, {"item": "painel_solar", "chance": 8, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "A sala de controle da usina tem os equipamentos mais caros da região. Desmontá-los exige cabeça fria.", "log": ["Painéis cheios de botões e avisos em amarelo.", "Um café derramado sobre o teclado. O último erro do operador.", "Você desparafusa placas com cuidado de cirurgião.", "As luzes de emergência acendem sozinhas por um segundo. Ninguém comemora.", "Um guindaste range com o vento, balançando uma carga esquecida.", "Uma chaminé solta fumaça que ninguém acendeu.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 2),
  ('reservatorios_ferro_velho', 'Esvaziar reservatórios do ferro-velho', 'ferro_velho_parafuso', null, 'coleta_combustivel', 'dificil', '{"engenharia": 40, "forca": 35, "percepcao": 25}'::jsonb, '[{"item": "combustivel", "chance": 100, "min": 4, "max": 7}, {"item": "sucata", "chance": 80, "min": 2, "max": 4}, {"item": "metal", "chance": 50, "min": 1, "max": 3}]'::jsonb, '{}'::jsonb, '{"riscos": ["vazamento", "incendio", "explosao"], "ruido": 2}'::jsonb, '{"abertura": "O Ferro-Velho Parafuso guardava tanques de carros e caminhões desmontados. Alguns ainda têm o que guardar.", "log": ["Pilhas de carros amassados formam corredores perigosos.", "O cão de guarda não late mais. Mas ainda está de guarda.", "Um tanque de caminhão pinga devagar. Você aproveita cada gota.", "Uma pilha de sucata desliza. O barulho ecoa longe.", "Placas de \"Use EPI\" nunca foram tão sinceras.", "O cheiro de óleo queimado gruda na roupa e na alma.", "O cheiro de gasolina avisa que você está perto, e que qualquer faísca é má ideia.", "Você enche o galão devagar. Pressa e combustível não combinam."]}'::jsonb, 1),
  ('garimpar_ferro_velho', 'Garimpar o ferro-velho', 'ferro_velho_parafuso', null, 'coleta_materiais', 'media', '{"forca": 40, "engenharia": 35, "percepcao": 25}'::jsonb, '[{"item": "sucata", "chance": 100, "min": 3, "max": 6}, {"item": "metal", "chance": 80, "min": 2, "max": 4}, {"item": "pecas_mecanicas", "chance": 60, "min": 1, "max": 3}, {"item": "kit_reparo", "chance": 20, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "Tudo no Ferro-Velho Parafuso pode virar outra coisa. A arte é escolher o quê.", "log": ["Você escala uma montanha de lataria com cuidado.", "Um motor quase inteiro. Quase é o bastante.", "O guindaste magnético segura um carro no ar há meses.", "Você sai com mais peso do que deveria e menos do que gostaria.", "Uma chaminé solta fumaça que ninguém acendeu.", "Um guindaste range com o vento, balançando uma carga esquecida.", "Você separa o útil do inútil. O inútil é maioria.", "A mochila pesa mais a cada achado, e as costas reclamam."]}'::jsonb, 2),
  ('camaras_frias_santa_brasa', 'Saquear as câmaras frias', 'frigorifico_santa_brasa', null, 'exploracao', 'dificil', '{"percepcao": 40, "forca": 35, "agilidade": 25}'::jsonb, '[{"item": "comida_enlatada", "chance": 90, "min": 3, "max": 5}, {"item": "racao_militar", "chance": 40, "min": 1, "max": 2}, {"item": "agua_potavel", "chance": 60, "min": 2, "max": 3}, {"item": "metal", "chance": 30, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "As câmaras frias do Santa Brasa pararam de gelar. O estoque de enlatados, porém, nunca estragou.", "log": ["O cheiro na entrada é um teste de caráter.", "Ganchos vazios balançam no teto.", "O estoque seco fica no fundo, depois de três portas pesadas.", "Você trabalha respirando pela boca. Às vezes, nem isso.", "O cheiro de óleo queimado gruda na roupa e na alma.", "Placas de \"Use EPI\" nunca foram tão sinceras.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 1),
  ('linha_abate_santa_brasa', 'Limpar a linha de abate', 'frigorifico_santa_brasa', null, 'combate', 'dificil', '{"forca": 50, "agilidade": 30, "percepcao": 20}'::jsonb, '[{"item": "comida_enlatada", "chance": 70, "min": 2, "max": 4}, {"item": "metal", "chance": 60, "min": 2, "max": 3}, {"item": "faca_de_caca", "chance": 20, "min": 1, "max": 1}, {"item": "machado", "chance": 15, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "A linha de abate do frigorífico agora funciona ao contrário. E a equipe de lá não usa luvas.", "log": ["O piso é de inox e escorregadio.", "Esteiras paradas formam um corredor estreito.", "Eles vêm em fila, como sempre vieram.", "No fim, só o pingar das torneiras.", "Um guindaste range com o vento, balançando uma carga esquecida.", "Uma chaminé solta fumaça que ninguém acendeu.", "Você aperta a arma com força. Eles não sabem o que é medo, você sabe por dois.", "Gemidos se aproximam em ritmo de procissão."]}'::jsonb, 2),
  ('desmontar_barco_estaleiro', 'Desmontar o barco encalhado', 'estaleiro_mare_morta', null, 'coleta_materiais', 'dificil', '{"engenharia": 45, "forca": 40, "percepcao": 15}'::jsonb, '[{"item": "metal", "chance": 90, "min": 3, "max": 5}, {"item": "pecas_mecanicas", "chance": 70, "min": 2, "max": 3}, {"item": "fios_cabos", "chance": 50, "min": 1, "max": 3}, {"item": "combustivel", "chance": 30, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "Um rebocador encalhado no Estaleiro Maré Morta. Casco de aço, motor diesel e fios por toda parte.", "log": ["A maré baixa revela o casco cheio de cracas.", "A casa de máquinas está alagada até o joelho.", "Você corta chapas com o que tem. Demora.", "A maré começa a subir. Hora de ir.", "Placas de \"Use EPI\" nunca foram tão sinceras.", "O cheiro de óleo queimado gruda na roupa e na alma.", "Você separa o útil do inútil. O inútil é maioria.", "A mochila pesa mais a cada achado, e as costas reclamam."]}'::jsonb, 1),
  ('resgatar_vigia_estaleiro', 'Resgatar o vigia do estaleiro', 'estaleiro_mare_morta', null, 'resgate', 'dificil', '{"agilidade": 35, "lideranca": 30, "forca": 20, "medicina": 15}'::jsonb, '[{"item": "sinalizador", "chance": 50, "min": 1, "max": 2}, {"item": "agua_potavel", "chance": 50, "min": 1, "max": 2}, {"item": "kit_primeiros_socorros", "chance": 30, "min": 1, "max": 1}, {"item": "remington_870", "chance": 8, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{"recruta_chance": 60}'::jsonb, '{"abertura": "O vigia do estaleiro vive no alto do guindaste há semanas. Ele acena com uma lanterna toda noite.", "log": ["O guindaste balança com o vento do mar.", "Embaixo, uma pequena multidão espera o vigia descer. Você também.", "A subida é longa. A descida, com companhia, mais longa ainda.", "O vigia conhece um atalho pelos galpões. Ainda bem.", "Uma chaminé solta fumaça que ninguém acendeu.", "Um guindaste range com o vento, balançando uma carga esquecida.", "Uma voz fraca responde ao seu chamado. Pode ser gente. Pode ser eco.", "Você marca o caminho de volta. Desta vez não vai voltar sozinho."]}'::jsonb, 2),
  ('subir_silos', 'Subir aos silos', 'silos_graneleiros_horizonte', null, 'exploracao', 'dificil', '{"agilidade": 45, "percepcao": 35, "forca": 20}'::jsonb, '[{"item": "comida_enlatada", "chance": 60, "min": 2, "max": 3}, {"item": "metal", "chance": 50, "min": 1, "max": 3}, {"item": "sinalizador", "chance": 40, "min": 1, "max": 1}, {"item": "remington_700", "chance": 6, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "Do alto dos Silos Horizonte dá para ver a cidade inteira. Dizem que alguém montou um posto de vigia lá em cima.", "log": ["Escadas verticais e enferrujadas. Não olhe para baixo.", "O vento lá em cima é cortante.", "O posto de vigia tem binóculos, enlatados e um diário.", "Lá de cima, a cidade parece calma. Engano de altura.", "O cheiro de óleo queimado gruda na roupa e na alma.", "Placas de \"Use EPI\" nunca foram tão sinceras.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 1),
  ('chefe_colosso_silos', 'Enfrentar o Colosso dos Silos', 'silos_graneleiros_horizonte', null, 'chefe', 'lendaria', '{"forca": 45, "agilidade": 30, "percepcao": 15, "medicina": 10}'::jsonb, '[{"item": "metal", "chance": 90, "min": 3, "max": 5}, {"item": "componentes_eletronicos", "chance": 60, "min": 2, "max": 3}, {"item": "kit_reparo", "chance": 50, "min": 1, "max": 2}, {"item": "fn_fal", "chance": 25, "min": 1, "max": 1}, {"item": "barrett_m82", "chance": 6, "min": 1, "max": 1}]'::jsonb, '{"nivel": 10}'::jsonb, '{}'::jsonb, '{"abertura": "Entre os silos vive algo que antes era um operador de empilhadeira e hoje é do tamanho dela. Os outros zumbis o seguem.", "log": ["O chão vibra a cada passo dele.", "Ele arranca uma porta de galpão como quem abre um pacote.", "Você precisa de espaço, e de sorte, e de mais espaço.", "Quando ele cai, o silêncio dura mais que o normal.", "Um guindaste range com o vento, balançando uma carga esquecida.", "Uma chaminé solta fumaça que ninguém acendeu.", "O chão treme de leve. Algo grande sabe que você chegou.", "Todos os outros zumbis abrem caminho. Isso nunca é bom sinal."]}'::jsonb, 2),
  ('filtros_agua_clara', 'Recuperar filtros e água', 'estacao_tratamento_agua_clara', null, 'exploracao', 'dificil', '{"engenharia": 40, "percepcao": 35, "medicina": 25}'::jsonb, '[{"item": "agua_potavel", "chance": 100, "min": 3, "max": 6}, {"item": "plastico", "chance": 60, "min": 1, "max": 3}, {"item": "componentes_eletronicos", "chance": 30, "min": 1, "max": 1}, {"item": "antidoto", "chance": 15, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "A Estação Água Clara tratava a água da cidade. Ainda há reservatórios limpos e filtros novos no almoxarifado.", "log": ["Tanques enormes de água parada refletem o céu cinza.", "O laboratório de análise está intacto. Os técnicos, não.", "Você enche garrafas no reservatório de água tratada.", "As bombas de recalque começam a girar sozinhas. Hora de ir.", "Placas de \"Use EPI\" nunca foram tão sinceras.", "O cheiro de óleo queimado gruda na roupa e na alma.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 1),
  ('comboio_militar_agua_clara', 'Revistar o comboio militar', 'estacao_tratamento_agua_clara', null, 'exploracao', 'dificil', '{"percepcao": 45, "agilidade": 30, "forca": 25}'::jsonb, '[{"item": "cartao_acesso_militar", "chance": 60, "min": 1, "max": 1}, {"item": "racao_militar", "chance": 70, "min": 1, "max": 3}, {"item": "sinalizador", "chance": 40, "min": 1, "max": 1}, {"item": "m4a1", "chance": 8, "min": 1, "max": 1}]'::jsonb, '{"nivel": 10}'::jsonb, '{}'::jsonb, '{"abertura": "Um comboio do exército parou na estação para buscar água e nunca mais saiu. O oficial responsável carregava um cartão de acesso à zona militar.", "log": ["Caminhões verdes estacionados em fila perfeita.", "Fardas, capacetes e nenhuma ordem.", "O jipe do oficial tem uma maleta presa ao banco.", "O rádio do comboio chia uma mensagem repetida. Melhor não entender.", "Uma chaminé solta fumaça que ninguém acendeu.", "Um guindaste range com o vento, balançando uma carga esquecida.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 2),
  ('deposito_combustivel_corvo', 'Invadir o depósito de combustível do Corvo', 'posto_avancado_corvo', null, 'coleta_combustivel', 'lendaria', '{"engenharia": 35, "agilidade": 30, "percepcao": 20, "forca": 15}'::jsonb, '[{"item": "combustivel", "chance": 100, "min": 8, "max": 12}, {"item": "combustivel", "chance": 30, "min": 2, "max": 4, "alta_qualidade": true}, {"item": "racao_militar", "chance": 50, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{"riscos": ["vazamento", "incendio", "explosao"], "ruido": 3}'::jsonb, '{"abertura": "O Posto Avançado Corvo guardava combustível para a frota inteira. Os tanques estão cheios; os vigias, não exatamente vivos.", "log": ["Holofotes giram sem ninguém controlando.", "O depósito tem portas blindadas e uma fechadura que já viu dias melhores.", "Combustível de aviação. Cheiro diferente, perigo igual.", "O alarme dispara no último galão. Claro que dispara.", "Alto-falantes repetem uma ordem de evacuação para ninguém.", "Luz fria, paredes brancas e manchas que não deveriam estar ali.", "O cheiro de gasolina avisa que você está perto, e que qualquer faísca é má ideia.", "Você enche o galão devagar. Pressa e combustível não combinam."]}'::jsonb, 1),
  ('revistar_paiol_corvo', 'Revistar o paiol', 'posto_avancado_corvo', null, 'exploracao', 'dificil', '{"percepcao": 40, "agilidade": 35, "forca": 25}'::jsonb, '[{"item": "racao_militar", "chance": 70, "min": 1, "max": 3}, {"item": "sinalizador", "chance": 50, "min": 1, "max": 2}, {"item": "kit_reparo", "chance": 40, "min": 1, "max": 1}, {"item": "sig_sauer_p226", "chance": 15, "min": 1, "max": 1}, {"item": "m4a1", "chance": 8, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "O paiol do Corvo foi trancado às pressas. Nem todo mundo levou o que precisava.", "log": ["Armários de armas abertos e vazios. A maioria.", "Uma caixa com lacre do exército escondida sob lonas.", "Etiquetas com números de série que ninguém vai conferir.", "Você sai pela vala de drenagem. Discreto, molhado e vivo.", "A cerca tem um buraco do tamanho exato de um erro de planejamento.", "Um holofote varre o pátio, ligado por um gerador teimoso.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 2),
  ('invadir_base_campanula', 'Invadir base militar', 'base_campanula', null, 'combate', 'lendaria', '{"forca": 35, "agilidade": 30, "percepcao": 20, "lideranca": 15}'::jsonb, '[{"item": "racao_militar", "chance": 80, "min": 2, "max": 4}, {"item": "kit_primeiros_socorros", "chance": 50, "min": 1, "max": 2}, {"item": "ak_47", "chance": 20, "min": 1, "max": 1}, {"item": "benelli_m4", "chance": 15, "min": 1, "max": 1}, {"item": "sako_trg_42", "chance": 6, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "A Base Campânula foi o último lugar a cair. Os soldados de lá caíram armados, treinados e em formação.", "log": ["Você corta a cerca no ponto cego da torre norte.", "Pelo pátio, soldados de farda rasgada marcham em círculos.", "O arsenal fica no prédio de comando. Claro que fica.", "Você sai antes do toque de recolher. Para eles, é eterno.", "Luz fria, paredes brancas e manchas que não deveriam estar ali.", "Alto-falantes repetem uma ordem de evacuação para ninguém.", "Você aperta a arma com força. Eles não sabem o que é medo, você sabe por dois.", "Gemidos se aproximam em ritmo de procissão."]}'::jsonb, 1),
  ('resgatar_patrulha_campanula', 'Resgatar a patrulha presa', 'base_campanula', null, 'resgate', 'dificil', '{"lideranca": 40, "agilidade": 25, "medicina": 20, "forca": 15}'::jsonb, '[{"item": "racao_militar", "chance": 70, "min": 1, "max": 3}, {"item": "kit_primeiros_socorros", "chance": 50, "min": 1, "max": 1}, {"item": "glock_17", "chance": 15, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{"recruta_chance": 70}'::jsonb, '{"abertura": "Uma patrulha ficou presa no bunker de munições da Campânula. O rádio deles ainda pede extração.", "log": ["Você encontra o bunker pelo som das batidas regulares.", "Lá dentro, três soldados e muita desconfiança.", "Eles conhecem a base. Você conhece a saída.", "Vocês correm juntos. Um deles ainda conta passos em voz alta.", "Um holofote varre o pátio, ligado por um gerador teimoso.", "A cerca tem um buraco do tamanho exato de um erro de planejamento.", "Uma voz fraca responde ao seu chamado. Pode ser gente. Pode ser eco.", "Você marca o caminho de volta. Desta vez não vai voltar sozinho."]}'::jsonb, 2),
  ('explorar_helix_9', 'Explorar o laboratório Helix-9', 'laboratorio_helix_9', null, 'exploracao', 'lendaria', '{"medicina": 40, "percepcao": 30, "engenharia": 30}'::jsonb, '[{"item": "antidoto", "chance": 80, "min": 1, "max": 3}, {"item": "antibiotico", "chance": 70, "min": 1, "max": 2}, {"item": "componentes_eletronicos", "chance": 70, "min": 2, "max": 3}, {"item": "kit_primeiros_socorros", "chance": 50, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "O Helix-9 estudava \"resistência celular\". Pelos resultados, a pesquisa foi um sucesso para o lado errado.", "log": ["Portas com leitores biométricos apagados.", "Jalecos pendurados, um ainda se mexe.", "Geladeiras de amostras com etiquetas que você prefere não ler.", "No quadro branco, uma fórmula riscada e a palavra \"DESCULPA\".", "Alto-falantes repetem uma ordem de evacuação para ninguém.", "Luz fria, paredes brancas e manchas que não deveriam estar ali.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 1),
  ('conter_cobaias_helix', 'Conter as cobaias', 'laboratorio_helix_9', null, 'combate', 'dificil', '{"agilidade": 40, "forca": 35, "medicina": 25}'::jsonb, '[{"item": "antidoto", "chance": 50, "min": 1, "max": 2}, {"item": "componentes_eletronicos", "chance": 60, "min": 1, "max": 2}, {"item": "vidro", "chance": 60, "min": 2, "max": 3}, {"item": "mossberg_500", "chance": 10, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "As cobaias do Helix-9 fugiram das gaiolas. São rápidas, magras e não seguem protocolo.", "log": ["Gaiolas abertas por dentro.", "Elas correm pelo forro. Você ouve antes de ver.", "A sala de quarentena vira armadilha.", "Quando a última para, o laboratório inteiro suspira.", "A cerca tem um buraco do tamanho exato de um erro de planejamento.", "Um holofote varre o pátio, ligado por um gerador teimoso.", "Você aperta a arma com força. Eles não sabem o que é medo, você sabe por dois.", "Gemidos se aproximam em ritmo de procissão."]}'::jsonb, 2),
  ('explorar_hospital_isolamento', 'Explorar hospital', 'hospital_isolamento_santa_augusta', null, 'exploracao', 'dificil', '{"medicina": 40, "percepcao": 35, "agilidade": 25}'::jsonb, '[{"item": "antibiotico", "chance": 80, "min": 1, "max": 3}, {"item": "kit_primeiros_socorros", "chance": 70, "min": 1, "max": 2}, {"item": "antidoto", "chance": 40, "min": 1, "max": 1}, {"item": "analgesico", "chance": 60, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "O Hospital de Isolamento Santa Augusta recebeu os primeiros casos. Os corredores ainda têm faixas de \"área contaminada\".", "log": ["Macas viradas formam barreiras nos corredores.", "Um quadro de plantão com nomes riscados um a um.", "A farmácia central fica no fim da ala vermelha.", "Você sai pelo necrotério. O caminho mais tranquilo, ironicamente.", "Luz fria, paredes brancas e manchas que não deveriam estar ali.", "Alto-falantes repetem uma ordem de evacuação para ninguém.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 1),
  ('resgatar_equipe_medica', 'Resgatar a equipe médica', 'hospital_isolamento_santa_augusta', null, 'resgate', 'lendaria', '{"medicina": 35, "lideranca": 30, "agilidade": 20, "forca": 15}'::jsonb, '[{"item": "kit_primeiros_socorros", "chance": 80, "min": 1, "max": 2}, {"item": "antibiotico", "chance": 70, "min": 1, "max": 2}, {"item": "antidoto", "chance": 50, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{"recruta_chance": 80}'::jsonb, '{"abertura": "Uma equipe médica se isolou na ala de pesquisa do Santa Augusta. Eles sabem coisas que valem uma cidade.", "log": ["Portas de vidro reforçado e rostos cansados do outro lado.", "A ala está cercada. Eles estão cercando há dias.", "Você distrai a multidão com o alarme de incêndio.", "A equipe sai em fila, carregando caixas de pesquisa e esperança.", "Um holofote varre o pátio, ligado por um gerador teimoso.", "A cerca tem um buraco do tamanho exato de um erro de planejamento.", "Uma voz fraca responde ao seu chamado. Pode ser gente. Pode ser eco.", "Você marca o caminho de volta. Desta vez não vai voltar sozinho."]}'::jsonb, 2),
  ('chefe_paciente_zero', 'Enfrentar chefe zumbi', 'complexo_subterraneo_nemesis', null, 'chefe', 'lendaria', '{"forca": 35, "agilidade": 30, "medicina": 20, "percepcao": 15}'::jsonb, '[{"item": "antidoto", "chance": 70, "min": 1, "max": 3}, {"item": "componentes_eletronicos", "chance": 70, "min": 2, "max": 4}, {"item": "barrett_m82", "chance": 15, "min": 1, "max": 1}, {"item": "benelli_m4", "chance": 20, "min": 1, "max": 1}]'::jsonb, '{"nivel": 14}'::jsonb, '{}'::jsonb, '{"abertura": "No fundo do Complexo Nêmesis está o que chamam de Paciente Zero. Ele não é o primeiro; é só o mais teimoso.", "log": ["Elevadores descem dez andares de concreto.", "Corredores com marcas de garras em espiral.", "Ele está na sala central, cercado de monitores apagados.", "Quando acaba, você fica um tempo parado. Merecido.", "Alto-falantes repetem uma ordem de evacuação para ninguém.", "Luz fria, paredes brancas e manchas que não deveriam estar ali.", "O chão treme de leve. Algo grande sabe que você chegou.", "Todos os outros zumbis abrem caminho. Isso nunca é bom sinal."]}'::jsonb, 1),
  ('mapear_tuneis_nemesis', 'Mapear os túneis', 'complexo_subterraneo_nemesis', null, 'exploracao', 'dificil', '{"percepcao": 50, "agilidade": 30, "engenharia": 20}'::jsonb, '[{"item": "fios_cabos", "chance": 70, "min": 2, "max": 3}, {"item": "componentes_eletronicos", "chance": 50, "min": 1, "max": 2}, {"item": "racao_militar", "chance": 50, "min": 1, "max": 2}, {"item": "sinalizador", "chance": 40, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "Os túneis do Complexo Nêmesis não estão em nenhum mapa. Você vai fazer o primeiro.", "log": ["Você marca as paredes com giz a cada cruzamento.", "Ventilação forçada, ainda funcionando. Por quê?", "Um corredor termina numa porta selada por dentro.", "Você volta pela trilha de giz. Ela ainda está lá. Ufa.", "A cerca tem um buraco do tamanho exato de um erro de planejamento.", "Um holofote varre o pátio, ligado por um gerador teimoso.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 2),
  ('recuperar_prototipo_cobalto', 'Recuperar o protótipo', 'campo_testes_cobalto', null, 'exploracao', 'lendaria', '{"engenharia": 45, "percepcao": 30, "agilidade": 25}'::jsonb, '[{"item": "painel_solar", "chance": 25, "min": 1, "max": 1}, {"item": "componentes_eletronicos", "chance": 90, "min": 2, "max": 4}, {"item": "fios_cabos", "chance": 70, "min": 2, "max": 3}, {"item": "kit_reparo", "chance": 40, "min": 1, "max": 2}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "No Campo de Testes Cobalto ficou um protótipo de gerador portátil. Dizem que funciona com sol.", "log": ["Crateras de testes cobrem o campo como acne.", "O hangar de testes tem a porta meio aberta.", "Você desmonta o protótipo seguindo um manual em inglês e fé.", "Uma sirene de teste dispara. Todos sabem que você está aqui.", "Luz fria, paredes brancas e manchas que não deveriam estar ali.", "Alto-falantes repetem uma ordem de evacuação para ninguém.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 1),
  ('sucata_blindados_cobalto', 'Coletar sucata de blindados', 'campo_testes_cobalto', null, 'coleta_materiais', 'dificil', '{"forca": 45, "engenharia": 35, "percepcao": 20}'::jsonb, '[{"item": "metal", "chance": 100, "min": 3, "max": 6}, {"item": "pecas_mecanicas", "chance": 70, "min": 2, "max": 3}, {"item": "sucata", "chance": 80, "min": 2, "max": 4}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "Blindados usados como alvo de testes viraram montanhas de aço. Boas para quem tem paciência e alicate.", "log": ["O aço é grosso. A paciência precisa ser mais.", "Um blindado ainda tem a escotilha trancada.", "O campo é aberto. Você se sente um alvo, porque é.", "Você volta curvado com o peso do metal.", "Um holofote varre o pátio, ligado por um gerador teimoso.", "A cerca tem um buraco do tamanho exato de um erro de planejamento.", "Você separa o útil do inútil. O inútil é maioria.", "A mochila pesa mais a cada achado, e as costas reclamam."]}'::jsonb, 2),
  ('religar_antena_vigilia', 'Religar a antena', 'centro_comunicacoes_vigilia', null, 'exploracao', 'dificil', '{"engenharia": 50, "percepcao": 30, "agilidade": 20}'::jsonb, '[{"item": "componentes_eletronicos", "chance": 90, "min": 2, "max": 4}, {"item": "fios_cabos", "chance": 80, "min": 2, "max": 4}, {"item": "painel_solar", "chance": 15, "min": 1, "max": 1}, {"item": "sinalizador", "chance": 30, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "O Centro de Comunicações Vigília ainda tem energia solar no teto. Religar a antena pode valer peças raras.", "log": ["A escada da torre é estreita e balança.", "Painéis cheios de luzes piscando em padrões antigos.", "Um rádio capta vozes. Não dá para saber se são gravações.", "Você desce com os bolsos cheios de chips.", "Alto-falantes repetem uma ordem de evacuação para ninguém.", "Luz fria, paredes brancas e manchas que não deveriam estar ali.", "Você abre gavetas com cuidado. A maioria guarda só poeira e arrependimento.", "Passos ecoam mais alto do que você gostaria."]}'::jsonb, 1),
  ('defender_central_vigilia', 'Defender a central', 'centro_comunicacoes_vigilia', null, 'combate', 'lendaria', '{"forca": 35, "agilidade": 30, "percepcao": 20, "lideranca": 15}'::jsonb, '[{"item": "componentes_eletronicos", "chance": 80, "min": 2, "max": 3}, {"item": "kit_reparo", "chance": 50, "min": 1, "max": 2}, {"item": "m4a1", "chance": 15, "min": 1, "max": 1}, {"item": "fn_fal", "chance": 12, "min": 1, "max": 1}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "Quando a antena acorda, a cidade inteira escuta. Inclusive quem não devia. Eles estão vindo.", "log": ["O primeiro grupo cruza a cerca norte.", "Você barra a porta com um armário de servidores.", "A antena continua transmitindo. A horda continua chegando.", "De repente, só o chiado do rádio.", "A cerca tem um buraco do tamanho exato de um erro de planejamento.", "Um holofote varre o pátio, ligado por um gerador teimoso.", "Você aperta a arma com força. Eles não sabem o que é medo, você sabe por dois.", "Gemidos se aproximam em ritmo de procissão."]}'::jsonb, 2),
  ('deposito_combustivel_vibora', 'Invadir o depósito de combustível do hangar', 'hangar_setor_vibora', null, 'coleta_combustivel', 'lendaria', '{"engenharia": 35, "agilidade": 30, "forca": 20, "percepcao": 15}'::jsonb, '[{"item": "combustivel", "chance": 100, "min": 8, "max": 12}, {"item": "combustivel", "chance": 30, "min": 2, "max": 4, "alta_qualidade": true}, {"item": "pecas_mecanicas", "chance": 50, "min": 1, "max": 3}]'::jsonb, '{}'::jsonb, '{"riscos": ["vazamento", "incendio", "explosao"], "ruido": 3}'::jsonb, '{"abertura": "O Hangar Setor Víbora abastecia helicópteros. O depósito de querosene está intacto, e cercado.", "log": ["Helicópteros parados com as hélices caídas.", "O depósito é um bunker baixo com cheiro forte.", "Você enche galões enquanto alguém se arrasta na pista.", "Uma faísca de lanterna e tudo acaba. Você segura a respiração.", "Luz fria, paredes brancas e manchas que não deveriam estar ali.", "Alto-falantes repetem uma ordem de evacuação para ninguém.", "O cheiro de gasolina avisa que você está perto, e que qualquer faísca é má ideia.", "Você enche o galão devagar. Pressa e combustível não combinam."]}'::jsonb, 1),
  ('desmontar_helicoptero', 'Desmontar o helicóptero', 'hangar_setor_vibora', null, 'coleta_materiais', 'lendaria', '{"engenharia": 50, "forca": 30, "percepcao": 20}'::jsonb, '[{"item": "componentes_eletronicos", "chance": 90, "min": 2, "max": 4}, {"item": "pecas_mecanicas", "chance": 90, "min": 2, "max": 4}, {"item": "metal", "chance": 70, "min": 2, "max": 4}, {"item": "fios_cabos", "chance": 70, "min": 2, "max": 3}]'::jsonb, '{}'::jsonb, '{}'::jsonb, '{"abertura": "Um helicóptero de transporte inteiro, parado no Hangar Víbora. Não voa mais, mas vale uma fortuna em peças.", "log": ["O painel tem mais botões do que você jamais vai entender.", "As hélices pesam mais que você.", "Você trabalha sob o olhar de um piloto ainda de capacete.", "O hangar ecoa cada ferramenta que cai.", "Um holofote varre o pátio, ligado por um gerador teimoso.", "A cerca tem um buraco do tamanho exato de um erro de planejamento.", "Você separa o útil do inútil. O inútil é maioria.", "A mochila pesa mais a cada achado, e as costas reclamam."]}'::jsonb, 2)
) as v(slug, nome, local, ponto, categoria, dificuldade, pesos, loot, requisitos, especial, textos, ordem)
join public.locations l on l.slug = v.local
on conflict (slug) do update set
  nome = excluded.nome, location_id = excluded.location_id, ponto = excluded.ponto, categoria = excluded.categoria,
  dificuldade = excluded.dificuldade, pesos = excluded.pesos, loot = excluded.loot, requisitos = excluded.requisitos,
  especial = excluded.especial, textos = excluded.textos, ordem = excluded.ordem;

-- ======== seed/seed_events.sql ========
-- Catálogo de eventos (35). Um evento por expedição; o banco sorteia (70% regionais, 30% gerais).
-- Pode rodar de novo (atualiza os textos).
--
-- Cada opção: titulo, descricao, e (efeito na chance), risco e recompensa (1 a 3, mostrados como ícones),
-- cautelosa (aplicada sozinha se o jogador não decidir em 24 h), requisito {atributo, valor},
-- custo {item, qtd} ou {stamina}, efeitos {texto, moral, moral_nao_ajudar, ferimento_chance, itens, xp,
-- perda_loot_pct, recruta_chance, zumbis}.
-- categorias: limita a evento a certas categorias de missão (ex.: só coleta de combustível).

insert into public.events (slug, escopo, region_id, peso, titulo, texto, opcoes, categorias)
select v.slug, v.escopo, r.id, v.peso, v.titulo, v.texto, v.opcoes, v.categorias
from (values
  ('sobrevivente_em_perigo', 'geral', null, 10, 'Sobrevivente em perigo', 'Um grito corta o silêncio. Numa varanda baixa, alguém tenta segurar a porta enquanto três deles forçam do outro lado.', '[{"titulo": "Ajudar", "descricao": "Correr até lá e dividir o problema.", "e": -4, "risco": 2, "recompensa": 2, "efeitos": {"texto": "Você chega a tempo. A pessoa agradece com a voz falhando e divide o que tinha.", "moral": 4, "ferimento_chance": 20, "itens": [{"item": "agua_potavel", "chance": 80, "min": 1, "max": 2}, {"item": "bandagem", "chance": 40, "min": 1, "max": 1}], "recruta_chance": 25}}, {"titulo": "Distrair com barulho", "descricao": "Fazer barulho do outro lado da rua e sumir.", "e": -1, "risco": 1, "recompensa": 1, "requisito": {"atributo": "agilidade", "valor": 5}, "efeitos": {"texto": "Você bate num portão e corre. Eles te seguem por um quarteirão e a varanda fica livre.", "moral": 2}}, {"titulo": "Seguir em frente", "descricao": "Não é problema seu. Não hoje.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "Você segue. O grito para logo depois. Você tenta não pensar nisso.", "moral_nao_ajudar": true}}]'::jsonb, null),
  ('chuva_acida', 'geral', null, 10, 'Chuva que arde', 'O céu escurece de repente e a chuva começa a cair com cheiro de bateria. Seus olhos ardem.', '[{"titulo": "Esperar num abrigo", "descricao": "Perder tempo, mas não a pele.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "Você espera numa marquise. A chuva passa e leva parte da sua paciência."}}, {"titulo": "Continuar coberto", "descricao": "Improvisar uma capa com o que tiver.", "e": 2, "risco": 1, "recompensa": 2, "custo": {"item": "tecido", "qtd": 1}, "efeitos": {"texto": "A capa de pano segura o pior. Você avança enquanto eles se escondem."}}, {"titulo": "Correr na chuva", "descricao": "Rápido e sem proteção.", "e": 1, "risco": 2, "recompensa": 1, "efeitos": {"ferimento_chance": 30, "texto": "Você corre. A pele arde por horas, mas o caminho ficou livre."}}]'::jsonb, null),
  ('mochila_abandonada', 'geral', null, 10, 'Mochila abandonada', 'No meio da calçada, uma mochila fechada. Perto demais de um carro com a porta aberta.', '[{"titulo": "Pegar com cuidado", "descricao": "Olhar em volta antes.", "e": 0, "risco": 1, "recompensa": 2, "requisito": {"atributo": "percepcao", "valor": 4}, "efeitos": {"texto": "Ninguém no carro. Na mochila, enlatados e um rolo de esparadrapo.", "itens": [{"item": "comida_enlatada", "chance": 100, "min": 1, "max": 2}, {"item": "bandagem", "chance": 60, "min": 1, "max": 1}]}}, {"titulo": "Pegar e correr", "descricao": "Rápido, antes que algo saia do carro.", "e": 0, "risco": 2, "recompensa": 2, "efeitos": {"ferimento_chance": 25, "texto": "Algo sai do carro. Você corre com a mochila no ombro.", "itens": [{"item": "comida_enlatada", "chance": 100, "min": 1, "max": 2}]}}, {"titulo": "Ignorar", "descricao": "Isca é isca.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "Você contorna. Uma mão pálida sai do carro e volta para dentro."}}]'::jsonb, null),
  ('radio_chiando', 'geral', null, 10, 'Rádio chiando', 'Um rádio de pilha caído no chão capta uma voz: alguém repete coordenadas de um esconderijo de suprimentos.', '[{"titulo": "Anotar e investigar", "descricao": "Desviar um pouco do caminho.", "e": -2, "risco": 2, "recompensa": 3, "requisito": {"atributo": "percepcao", "valor": 5}, "efeitos": {"texto": "O esconderijo existe. Alguém foi mais rápido, mas sobrou coisa boa.", "itens": [{"item": "racao_militar", "chance": 80, "min": 1, "max": 2}, {"item": "sinalizador", "chance": 40, "min": 1, "max": 1}], "xp": 10}}, {"titulo": "Levar o rádio", "descricao": "Peças sempre servem.", "e": 0, "risco": 1, "recompensa": 1, "efeitos": {"texto": "Você desmonta o rádio. A voz para no meio de uma frase.", "itens": [{"item": "componentes_eletronicos", "chance": 100, "min": 1, "max": 1}]}}, {"titulo": "Desligar e seguir", "descricao": "Barulho atrai.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "Você desliga o rádio. O silêncio volta, desconfiado."}}]'::jsonb, null),
  ('cachorro_faminto', 'geral', null, 10, 'Cachorro faminto', 'Um vira-lata magro te segue a uma distância respeitosa. Ele rosna para a esquina antes de você ver o motivo.', '[{"titulo": "Dar comida", "descricao": "Ele parece saber das coisas.", "e": 3, "risco": 1, "recompensa": 2, "custo": {"item": "comida_enlatada", "qtd": 1}, "efeitos": {"texto": "Ele come e passa a andar na frente, avisando de cada esquina. Bom garoto.", "moral": 3}}, {"titulo": "Seguir o aviso dele", "descricao": "Mudar de rota pelo rosnado.", "e": 1, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "Você troca de rua. Atrás da esquina, um grupo esperava."}}, {"titulo": "Espantar", "descricao": "Cachorro faz barulho.", "e": -1, "risco": 1, "recompensa": 1, "efeitos": {"texto": "Ele vai embora ganindo. A esquina fica sem aviso.", "moral": -2}}]'::jsonb, null),
  ('horda_passando', 'geral', null, 10, 'Horda passando', 'O chão vibra com centenas de passos arrastados. Uma horda atravessa a avenida bem no seu caminho.', '[{"titulo": "Esconder e esperar", "descricao": "Ficar imóvel até passarem.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "Você prende a respiração por longos minutos. Eles passam."}}, {"titulo": "Atravessar no meio", "descricao": "Aproveitar uma brecha.", "e": 3, "risco": 2, "recompensa": 2, "requisito": {"atributo": "agilidade", "valor": 6}, "efeitos": {"texto": "Você cruza entre dois grupos sem ser notado. Tempo ganho, coração perdido."}}, {"titulo": "Jogar um molotov", "descricao": "Abrir caminho no fogo.", "e": 5, "risco": 2, "recompensa": 2, "custo": {"item": "molotov", "qtd": 1}, "efeitos": {"texto": "O fogo abre caminho e assusta o resto. Você passa pelo corredor de fumaça.", "zumbis": 6}}]'::jsonb, null),
  ('tanque_vazando', 'geral', null, 30, 'Tanque vazando', 'O tanque que você está drenando racha. Combustível escorre pelo chão, e cada segundo leva mais embora.', '[{"titulo": "Agir rápido", "descricao": "Salvar o máximo, com risco de se encharcar.", "e": -2, "risco": 2, "recompensa": 3, "efeitos": {"ferimento_chance": 25, "texto": "Você enche o que dá com as mãos tremendo. Salvou muito, cheirando a posto.", "itens": [{"item": "combustivel", "chance": 100, "min": 1, "max": 2}]}}, {"titulo": "Remendar o vazamento", "descricao": "Engenharia resolve.", "e": 1, "risco": 1, "recompensa": 2, "requisito": {"atributo": "engenharia", "valor": 5}, "efeitos": {"texto": "Um remendo com fita e sorte. O vazamento para e quase nada se perde."}}, {"titulo": "Recuar e aceitar a perda", "descricao": "Combustível no chão não vale a pele.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"perda_loot_pct": 30, "texto": "Você se afasta do vazamento. Parte do combustível vira poça."}}]'::jsonb, array['coleta_combustivel']::text[]),
  ('comboio_abandonado', 'geral', null, 25, 'Comboio abandonado', 'Três caminhões-tanque parados na estrada, portas abertas. Muito combustível. Silêncio demais.', '[{"titulo": "Drenar tudo", "descricao": "Encher o que puder.", "e": -4, "risco": 3, "recompensa": 3, "efeitos": {"ferimento_chance": 35, "texto": "Era emboscada: eles estavam embaixo dos caminhões. Você sai com galões e arranhões.", "itens": [{"item": "combustivel", "chance": 100, "min": 2, "max": 4}], "zumbis": 3}}, {"titulo": "Vigiar antes", "descricao": "Observar o comboio por um tempo.", "e": 1, "risco": 1, "recompensa": 2, "requisito": {"atributo": "percepcao", "valor": 6}, "efeitos": {"texto": "Você vê movimento sob os caminhões e drena só o último, longe deles.", "itens": [{"item": "combustivel", "chance": 100, "min": 1, "max": 2}]}}, {"titulo": "Deixar para lá", "descricao": "Tanta fartura é suspeita.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "Você segue sem olhar para trás. Algo se mexe sob os caminhões."}}]'::jsonb, array['coleta_combustivel']::text[]),
  ('faisca_perigosa', 'geral', null, 30, 'Faísca perigosa', 'Um fio desencapado solta faíscas a um metro dos galões. O cheiro de gasolina está em todo lugar.', '[{"titulo": "Desligar o circuito", "descricao": "Saber qual fio cortar.", "e": 2, "risco": 1, "recompensa": 2, "requisito": {"atributo": "engenharia", "valor": 6}, "efeitos": {"texto": "Você corta o fio certo. As faíscas param e o trabalho segue tranquilo.", "xp": 10}}, {"titulo": "Abafar com pano", "descricao": "Improviso rápido.", "e": 0, "risco": 2, "recompensa": 1, "custo": {"item": "tecido", "qtd": 1}, "efeitos": {"ferimento_chance": 20, "texto": "O pano abafa as faíscas, com um susto e uma queimadura leve."}}, {"titulo": "Sair rápido com o que tem", "descricao": "Antes que tudo exploda.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"perda_loot_pct": 40, "texto": "Você sai correndo. Atrás, um estalo, um clarão e menos combustível para levar."}}]'::jsonb, array['coleta_combustivel']::text[]),
  ('guardiao_do_posto', 'geral', null, 25, 'Sobrevivente guardando o posto', 'Um homem armado com uma espingarda velha diz que o posto é dele. Os olhos dele dizem que ele não dorme há dias.', '[{"titulo": "Negociar", "descricao": "Dividir o combustível em troca de passagem.", "e": 1, "risco": 1, "recompensa": 2, "requisito": {"atributo": "lideranca", "valor": 5}, "efeitos": {"texto": "Vocês dividem. Ele até indica um tanque que você não tinha visto.", "moral": 3, "itens": [{"item": "combustivel", "chance": 100, "min": 1, "max": 2}]}}, {"titulo": "Ameaçar", "descricao": "Mostrar que você não está para conversa.", "e": -3, "risco": 3, "recompensa": 3, "efeitos": {"ferimento_chance": 40, "texto": "Ele atira para o alto, você avança, ele foge. O posto fica com você, a consciência pesada.", "moral": -4, "itens": [{"item": "combustivel", "chance": 100, "min": 1, "max": 3}]}}, {"titulo": "Ignorar e ir embora", "descricao": "O posto é dele, a vida é sua.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"perda_loot_pct": 50, "texto": "Você vai embora com o pouco que já tinha juntado."}}]'::jsonb, array['coleta_combustivel']::text[]),
  ('guardiao_do_posto_ignorar', 'geral', null, 15, 'Alguém vigia o tanque', 'Do alto de um caminhão, alguém observa você trabalhar. Não diz nada, não abaixa a arma.', '[{"titulo": "Ignorar e continuar", "descricao": "Fingir que não viu.", "e": -1, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "Ele não faz nada. Você também não. Trabalho tenso."}}, {"titulo": "Oferecer parte", "descricao": "Paz vale um galão.", "e": 0, "risco": 1, "recompensa": 1, "efeitos": {"perda_loot_pct": 20, "moral": 3, "texto": "Você deixa um galão no chão. Ele acena e some."}}, {"titulo": "Ajudar", "descricao": "Oferecer comida e companhia.", "e": 1, "risco": 1, "recompensa": 2, "custo": {"item": "comida_enlatada", "qtd": 1}, "efeitos": {"texto": "Ele desce, come em silêncio e diz que o tanque é de quem cuida dele.", "moral": 5, "recruta_chance": 40}}]'::jsonb, array['coleta_combustivel']::text[]),
  ('peri_pipa_presa', 'regional', 'periferia', 10, 'Pipa no fio', 'Uma pipa presa no poste balança com um bilhete amarrado: "tem comida no 32".', '[{"titulo": "Ir até o 32", "descricao": "Pode ser verdade.", "e": -1, "risco": 2, "recompensa": 2, "efeitos": {"ferimento_chance": 15, "texto": "No número 32, uma despensa e um morador que já não come.", "itens": [{"item": "comida_enlatada", "chance": 100, "min": 1, "max": 3}]}}, {"titulo": "Ignorar o bilhete", "descricao": "Pode ser armadilha.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "Você segue. A pipa continua dançando."}}, {"titulo": "Ler com atenção", "descricao": "O bilhete tem mais pistas.", "e": 0, "risco": 1, "recompensa": 2, "requisito": {"atributo": "percepcao", "valor": 4}, "efeitos": {"texto": "O bilhete fala dos fundos, não da frente. Entrar pelos fundos foi tranquilo.", "itens": [{"item": "comida_enlatada", "chance": 100, "min": 1, "max": 2}, {"item": "agua_potavel", "chance": 80, "min": 1, "max": 1}]}}]'::jsonb, null),
  ('peri_portao_rangendo', 'regional', 'periferia', 10, 'Portão rangendo', 'Um portão de garagem range sozinho. Do outro lado, alguma coisa se apoia nele.', '[{"titulo": "Travar com madeira", "descricao": "Prender o portão e seguir.", "e": 2, "risco": 1, "recompensa": 1, "custo": {"item": "madeira", "qtd": 1}, "efeitos": {"texto": "Duas tábuas e o problema fica do lado de lá."}}, {"titulo": "Dar a volta", "descricao": "Caminho mais longo.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "A volta custa tempo, mas não custa sangue."}}, {"titulo": "Abrir e enfrentar", "descricao": "Resolver logo.", "e": 1, "risco": 2, "recompensa": 2, "requisito": {"atributo": "forca", "valor": 4}, "efeitos": {"zumbis": 2, "texto": "Você abre, eles caem, você passa. Na garagem, uma caixa de ferramentas.", "itens": [{"item": "pecas_mecanicas", "chance": 70, "min": 1, "max": 2}]}}]'::jsonb, null),
  ('peri_cachorros_soltos', 'regional', 'periferia', 10, 'Matilha', 'Cachorros que já foram de estimação andam em bando agora. E estão com fome.', '[{"titulo": "Jogar comida longe", "descricao": "Distrair a matilha.", "e": 2, "risco": 1, "recompensa": 1, "custo": {"item": "comida_enlatada", "qtd": 1}, "efeitos": {"texto": "Eles brigam pela lata e esquecem de você."}}, {"titulo": "Subir num muro", "descricao": "Esperar passarem.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "Você espera em cima do muro até eles perderem o interesse."}}, {"titulo": "Encarar a matilha", "descricao": "Mostrar quem manda.", "e": 1, "risco": 2, "recompensa": 1, "requisito": {"atributo": "lideranca", "valor": 5}, "efeitos": {"texto": "Você fica firme e fala grosso. Eles recuam, desconfiados.", "moral": 2}}]'::jsonb, null),
  ('peri_vizinha_janela', 'regional', 'periferia', 10, 'A vizinha da janela', 'Uma senhora acena da janela do segundo andar e aponta, desesperada, para o próprio quintal.', '[{"titulo": "Ver o que é", "descricao": "Ela quer mostrar algo.", "e": -2, "risco": 2, "recompensa": 2, "efeitos": {"ferimento_chance": 15, "texto": "No quintal, o neto dela preso no galinheiro. Você o tira de lá. Ela te dá o que pode.", "moral": 4, "itens": [{"item": "agua_potavel", "chance": 100, "min": 1, "max": 2}, {"item": "bandagem", "chance": 50, "min": 1, "max": 1}], "recruta_chance": 20}}, {"titulo": "Acenar de volta e seguir", "descricao": "Não dá para ajudar todo mundo.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"moral_nao_ajudar": true, "texto": "Você acena. Ela para de acenar."}}]'::jsonb, null),
  ('peri_feira_movimento', 'regional', 'periferia', 10, 'Movimento na feira', 'Entre as lonas da feira, sombras se movem devagar. Algumas carregam sacolas.', '[{"titulo": "Observar de longe", "descricao": "Ver se são vivos.", "e": 1, "risco": 1, "recompensa": 2, "requisito": {"atributo": "percepcao", "valor": 5}, "efeitos": {"texto": "Vivos, catando comida. Vocês trocam acenos e informações.", "xp": 8}}, {"titulo": "Passar longe", "descricao": "Evitar problema.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "Você contorna a feira inteira."}}, {"titulo": "Chegar falando", "descricao": "Gente viva é rara.", "e": -1, "risco": 2, "recompensa": 2, "efeitos": {"moral": 3, "texto": "São sobreviventes. Desconfiados, mas trocam uma garrafa d''água por notícias.", "itens": [{"item": "agua_potavel", "chance": 100, "min": 1, "max": 1}]}}]'::jsonb, null),
  ('peri_onibus_tombado', 'regional', 'periferia', 10, 'Ônibus tombado', 'Um ônibus tombado bloqueia a rua. Por dentro, as janelas ainda têm marcas de mãos.', '[{"titulo": "Atravessar por dentro", "descricao": "O caminho mais curto.", "e": 2, "risco": 2, "recompensa": 2, "efeitos": {"ferimento_chance": 20, "texto": "Lá dentro, um passageiro se mexe. Você passa rápido e acha uma mochila.", "itens": [{"item": "plastico", "chance": 80, "min": 1, "max": 2}, {"item": "agua_potavel", "chance": 50, "min": 1, "max": 1}]}}, {"titulo": "Escalar por cima", "descricao": "Mais lento, mais seguro.", "e": 1, "risco": 1, "recompensa": 1, "requisito": {"atributo": "agilidade", "valor": 4}, "efeitos": {"texto": "Você sobe pelo teto do ônibus e desce do outro lado sem barulho."}}, {"titulo": "Dar a volta pelo quarteirão", "descricao": "Tempo é o que não falta.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "A volta é longa, mas tranquila."}}]'::jsonb, null),
  ('centro_alarme_carro', 'regional', 'centro_urbano', 10, 'Alarme de carro', 'Você esbarra num carro e o alarme dispara. Em todas as direções, cabeças se viram.', '[{"titulo": "Desligar o alarme", "descricao": "Abrir o capô e cortar o fio.", "e": 1, "risco": 1, "recompensa": 1, "requisito": {"atributo": "engenharia", "valor": 4}, "efeitos": {"texto": "Você arranca o fio da bateria. O silêncio volta antes da multidão."}}, {"titulo": "Correr", "descricao": "Sair dali agora.", "e": -1, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "Você corre dois quarteirões. A multidão fica com o carro."}}, {"titulo": "Usar como isca", "descricao": "Deixar tocar e ir por trás.", "e": 3, "risco": 1, "recompensa": 2, "requisito": {"atributo": "agilidade", "valor": 5}, "efeitos": {"texto": "Todos vão para o carro. Você vai para onde eles saíram."}}]'::jsonb, null),
  ('centro_franco_atirador', 'regional', 'centro_urbano', 10, 'Tiros do alto', 'Um tiro acerta o asfalto a um metro de você. Alguém num prédio não quer visitas.', '[{"titulo": "Procurar cobertura", "descricao": "Esperar o atirador se cansar.", "e": -1, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "Você espera atrás de um ônibus até o sol mudar de lado."}}, {"titulo": "Acenar com um pano", "descricao": "Mostrar que é gente.", "e": 1, "risco": 1, "recompensa": 2, "custo": {"item": "tecido", "qtd": 1}, "efeitos": {"moral": 2, "texto": "Os tiros param. Uma lata de comida desce numa corda, com um bilhete: \"vá embora\".", "itens": [{"item": "comida_enlatada", "chance": 100, "min": 1, "max": 1}]}}, {"titulo": "Correr em zigue-zague", "descricao": "Arriscar.", "e": 1, "risco": 3, "recompensa": 1, "efeitos": {"ferimento_chance": 40, "texto": "Um tiro passa raspando. Você chega do outro lado, sem fôlego."}}]'::jsonb, null),
  ('centro_elevador_parado', 'regional', 'centro_urbano', 10, 'Elevador parado', 'Um elevador parado entre andares. De dentro, batidas regulares. Pode ser alguém. Pode ser algo.', '[{"titulo": "Forçar a porta", "descricao": "Se for gente, precisa de ajuda.", "e": -2, "risco": 2, "recompensa": 2, "requisito": {"atributo": "forca", "valor": 5}, "efeitos": {"moral": 3, "texto": "Uma pessoa magra e desidratada cai nos seus braços.", "recruta_chance": 30, "itens": [{"item": "componentes_eletronicos", "chance": 40, "min": 1, "max": 1}]}}, {"titulo": "Perguntar quem está aí", "descricao": "Uma pergunta resolve.", "e": 0, "risco": 1, "recompensa": 1, "efeitos": {"texto": "Ninguém responde. As batidas continuam. Você vai embora."}}, {"titulo": "Seguir", "descricao": "Elevador é sempre problema.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"moral_nao_ajudar": true, "texto": "Você segue. As batidas ficam para trás."}}]'::jsonb, null),
  ('centro_letreiro', 'regional', 'centro_urbano', 10, 'Letreiro piscando', 'Um letreiro de neon ainda funciona, alimentado por algum gerador escondido no prédio.', '[{"titulo": "Achar o gerador", "descricao": "Combustível e peças.", "e": -1, "risco": 2, "recompensa": 3, "requisito": {"atributo": "percepcao", "valor": 5}, "efeitos": {"texto": "No subsolo, um gerador e galões. Os vizinhos do subsolo não gostaram.", "itens": [{"item": "combustivel", "chance": 80, "min": 1, "max": 2}, {"item": "fios_cabos", "chance": 80, "min": 1, "max": 2}], "ferimento_chance": 15}}, {"titulo": "Apagar o letreiro", "descricao": "Luz atrai.", "e": 2, "risco": 1, "recompensa": 1, "requisito": {"atributo": "engenharia", "valor": 4}, "efeitos": {"texto": "Você corta a luz. A rua fica mais escura e mais segura."}}, {"titulo": "Passar longe", "descricao": "Deixar brilhar.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "Você segue pela sombra."}}]'::jsonb, null),
  ('centro_metro_fumaca', 'regional', 'centro_urbano', 10, 'Fumaça do metrô', 'Fumaça sobe das grades do metrô. Alguém, lá embaixo, acendeu uma fogueira.', '[{"titulo": "Descer e conversar", "descricao": "Gente viva sabe coisas.", "e": -1, "risco": 2, "recompensa": 2, "requisito": {"atributo": "lideranca", "valor": 4}, "efeitos": {"texto": "Um grupo pequeno, armado e cansado. Dividem informação sobre a rota.", "xp": 10, "moral": 2}}, {"titulo": "Seguir pela superfície", "descricao": "Nada de túneis.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "Você segue por cima, ouvindo vozes abafadas."}}, {"titulo": "Jogar algo para chamar", "descricao": "Testar a reação.", "e": 0, "risco": 2, "recompensa": 1, "efeitos": {"texto": "A resposta vem em forma de pedra. Você entende o recado."}}]'::jsonb, null),
  ('centro_crianca_perdida', 'regional', 'centro_urbano', 10, 'Voz de criança', 'De dentro de uma loja vem uma voz fina cantando uma música de escola.', '[{"titulo": "Entrar e procurar", "descricao": "Não dá para deixar.", "e": -3, "risco": 2, "recompensa": 2, "efeitos": {"ferimento_chance": 20, "moral": 5, "texto": "Era uma menina escondida no provador. Ela sabe onde estão os pais. Você a leva até lá.", "recruta_chance": 15}}, {"titulo": "Chamar de fora", "descricao": "Sem entrar.", "e": 0, "risco": 1, "recompensa": 1, "efeitos": {"texto": "A música para. Ninguém aparece.", "moral": -2}}, {"titulo": "Ir embora", "descricao": "Pode ser armadilha.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"moral_nao_ajudar": true, "texto": "Você vai embora. A música continua por um tempo."}}]'::jsonb, null),
  ('ind_vapor', 'regional', 'zona_industrial', 10, 'Vazamento de vapor', 'Um cano estoura e enche o galpão de vapor quente. Você não enxerga um metro.', '[{"titulo": "Fechar a válvula", "descricao": "Saber onde fica.", "e": 2, "risco": 1, "recompensa": 2, "requisito": {"atributo": "engenharia", "valor": 6}, "efeitos": {"xp": 10, "texto": "Você acha a válvula pelo som e fecha. O galpão clareia."}}, {"titulo": "Esperar dissipar", "descricao": "Paciência.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "O vapor baixa devagar. Você espera agachado."}}, {"titulo": "Atravessar no escuro", "descricao": "Pressa.", "e": 1, "risco": 2, "recompensa": 1, "efeitos": {"ferimento_chance": 35, "texto": "Você atravessa queimando os braços."}}]'::jsonb, null),
  ('ind_guindaste', 'regional', 'zona_industrial', 10, 'Carga balançando', 'Um guindaste range com o vento. A carga presa nele balança sobre o caminho.', '[{"titulo": "Passar correndo", "descricao": "Calcular o tempo.", "e": 1, "risco": 1, "recompensa": 1, "requisito": {"atributo": "agilidade", "valor": 6}, "efeitos": {"texto": "Você passa entre um balanço e outro."}}, {"titulo": "Soltar a carga", "descricao": "Derrubar de uma vez.", "e": 2, "risco": 1, "recompensa": 2, "requisito": {"atributo": "engenharia", "valor": 7}, "efeitos": {"zumbis": 4, "texto": "A carga despenca sobre um grupo que vinha atrás. Problema resolvido em dobro."}}, {"titulo": "Contornar", "descricao": "Longe da carga.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "Você contorna o pátio inteiro."}}]'::jsonb, null),
  ('ind_operarios', 'regional', 'zona_industrial', 10, 'Turno da tarde', 'Uma fila de operários de uniforme marcha em direção ao relógio de ponto. Hábitos morrem devagar.', '[{"titulo": "Esperar o turno passar", "descricao": "Eles têm horário.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "Eles batem um ponto que não funciona e voltam. Você passa depois."}}, {"titulo": "Usar a fila como cobertura", "descricao": "Andar no meio deles.", "e": 3, "risco": 2, "recompensa": 1, "requisito": {"atributo": "agilidade", "valor": 7}, "efeitos": {"texto": "Você imita o passo arrastado e atravessa no meio da fila. Ninguém nota."}}, {"titulo": "Jogar molotov", "descricao": "Fim de expediente.", "e": 4, "risco": 1, "recompensa": 2, "custo": {"item": "molotov", "qtd": 1}, "efeitos": {"zumbis": 6, "texto": "O fogo encerra o turno. Para sempre."}}]'::jsonb, null),
  ('ind_acido', 'regional', 'zona_industrial', 10, 'Barris corroídos', 'Barris de produto químico vazam pelo chão. O cheiro faz a cabeça girar.', '[{"titulo": "Proteger o rosto", "descricao": "Pano molhado no rosto.", "e": 1, "risco": 1, "recompensa": 1, "custo": {"item": "agua_potavel", "qtd": 1}, "efeitos": {"texto": "O pano úmido segura o pior. Você passa sem tontura."}}, {"titulo": "Prender a respiração", "descricao": "Rápido.", "e": 0, "risco": 2, "recompensa": 1, "efeitos": {"ferimento_chance": 30, "texto": "Você atravessa com os pulmões queimando."}}, {"titulo": "Voltar e dar a volta", "descricao": "Química não perdoa.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "A volta é longa e respirável."}}]'::jsonb, null),
  ('ind_trabalhador_preso', 'regional', 'zona_industrial', 10, 'Preso na esteira', 'Um homem está preso sob uma esteira tombada. Ele ainda é homem, por enquanto.', '[{"titulo": "Levantar a esteira", "descricao": "Força bruta.", "e": -2, "risco": 2, "recompensa": 2, "requisito": {"atributo": "forca", "valor": 7}, "efeitos": {"moral": 5, "texto": "Você levanta o bastante. Ele sai mancando e te dá a chave do almoxarifado.", "itens": [{"item": "kit_reparo", "chance": 70, "min": 1, "max": 1}, {"item": "metal", "chance": 100, "min": 1, "max": 2}], "recruta_chance": 30}}, {"titulo": "Tratar a perna dele", "descricao": "Medicina primeiro.", "e": 0, "risco": 1, "recompensa": 2, "requisito": {"atributo": "medicina", "valor": 6}, "custo": {"item": "bandagem", "qtd": 1}, "efeitos": {"moral": 4, "texto": "Você faz um curativo e alavanca a esteira com um cano. Ele agradece em silêncio.", "recruta_chance": 35}}, {"titulo": "Deixar", "descricao": "Não dá tempo.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"moral_nao_ajudar": true, "texto": "Você segue. Ele para de pedir ajuda."}}]'::jsonb, null),
  ('ind_trilho', 'regional', 'zona_industrial', 10, 'Trem fantasma', 'Um vagão solto desce o trilho em sua direção, empurrado só pela gravidade.', '[{"titulo": "Pular para o lado", "descricao": "Simples.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "Você pula. O vagão passa e esmaga quem estava atrás.", "zumbis": 2}}, {"titulo": "Embarcar", "descricao": "Carona até o outro lado do pátio.", "e": 3, "risco": 2, "recompensa": 1, "requisito": {"atributo": "agilidade", "valor": 7}, "efeitos": {"texto": "Você sobe no vagão em movimento e desce perto do objetivo."}}, {"titulo": "Frear o vagão", "descricao": "Usar a alavanca.", "e": 1, "risco": 1, "recompensa": 2, "requisito": {"atributo": "engenharia", "valor": 6}, "efeitos": {"texto": "O vagão para. Dentro, caixas esquecidas.", "itens": [{"item": "pecas_mecanicas", "chance": 80, "min": 1, "max": 2}, {"item": "racao_militar", "chance": 40, "min": 1, "max": 1}]}}]'::jsonb, null),
  ('mil_holofote', 'regional', 'zona_militar_cientifica', 10, 'Holofote girando', 'Um holofote varre o pátio em círculos. Onde a luz passa, eles se viram.', '[{"titulo": "Seguir a sombra", "descricao": "Andar no ritmo da luz.", "e": 2, "risco": 1, "recompensa": 1, "requisito": {"atributo": "agilidade", "valor": 7}, "efeitos": {"texto": "Você anda na sombra do facho, passo a passo."}}, {"titulo": "Quebrar o holofote", "descricao": "Um tiro bem dado.", "e": 3, "risco": 2, "recompensa": 2, "requisito": {"atributo": "percepcao", "valor": 8}, "efeitos": {"texto": "O holofote apaga. O pátio fica escuro e seu."}}, {"titulo": "Esperar a ronda", "descricao": "Ele para em algum momento.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "O gerador engasga e o holofote para por um tempo."}}]'::jsonb, null),
  ('mil_soldado_ferido', 'regional', 'zona_militar_cientifica', 10, 'Soldado ferido', 'Um soldado encostado na cerca, perna enfaixada e fuzil sem munição. Ele pede água.', '[{"titulo": "Dar água e tratar", "descricao": "Ele merece.", "e": 1, "risco": 1, "recompensa": 3, "requisito": {"atributo": "medicina", "valor": 6}, "custo": {"item": "agua_potavel", "qtd": 1}, "efeitos": {"moral": 5, "texto": "Ele bebe, conta a rota segura e divide a ração do pelotão.", "itens": [{"item": "racao_militar", "chance": 100, "min": 1, "max": 2}], "recruta_chance": 40}}, {"titulo": "Dar só a água", "descricao": "O que dá para fazer.", "e": 1, "risco": 1, "recompensa": 1, "custo": {"item": "agua_potavel", "qtd": 1}, "efeitos": {"moral": 3, "texto": "Ele agradece e indica um portão sem vigia."}}, {"titulo": "Seguir", "descricao": "Ele está perdido.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"moral_nao_ajudar": true, "texto": "Você segue. Ele fecha os olhos."}}]'::jsonb, null),
  ('mil_campo_minado', 'regional', 'zona_militar_cientifica', 10, 'Placa de perigo', 'Uma placa torta avisa: "ÁREA MINADA". O atalho passa por ali.', '[{"titulo": "Atravessar com cuidado", "descricao": "Ler o terreno.", "e": 2, "risco": 1, "recompensa": 2, "requisito": {"atributo": "percepcao", "valor": 8}, "efeitos": {"texto": "Você vê as marcas na terra e passa pelo caminho certo."}}, {"titulo": "Jogar pedras na frente", "descricao": "Testar o chão.", "e": 1, "risco": 2, "recompensa": 1, "efeitos": {"ferimento_chance": 25, "texto": "Uma explosão a dez metros. Você passa com os ouvidos zumbindo.", "zumbis": 3}}, {"titulo": "Dar a volta", "descricao": "Placa é placa.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "A volta é longa. Ninguém explode."}}]'::jsonb, null),
  ('mil_laboratorio_alarme', 'regional', 'zona_militar_cientifica', 10, 'Alarme biológico', 'Uma sirene diferente toca. Uma voz gravada anuncia "contenção falhou" em três idiomas.', '[{"titulo": "Correr para a saída", "descricao": "Sair da área.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"perda_loot_pct": 20, "texto": "Você corre, deixando parte do que juntou."}}, {"titulo": "Desligar o sistema", "descricao": "Achar o painel.", "e": 2, "risco": 1, "recompensa": 2, "requisito": {"atributo": "engenharia", "valor": 8}, "efeitos": {"xp": 15, "texto": "Você desliga a sirene. As portas de contenção travam o que vinha."}}, {"titulo": "Usar o caos", "descricao": "Pegar o que der enquanto todos correm.", "e": -3, "risco": 3, "recompensa": 3, "efeitos": {"ferimento_chance": 35, "texto": "No meio do caos, uma geladeira de remédios aberta.", "itens": [{"item": "antidoto", "chance": 100, "min": 1, "max": 2}, {"item": "antibiotico", "chance": 70, "min": 1, "max": 1}]}}]'::jsonb, null),
  ('mil_drone', 'regional', 'zona_militar_cientifica', 10, 'Drone de patrulha', 'Um drone militar ainda patrulha o perímetro, com um alto-falante pedindo identificação.', '[{"titulo": "Hackear o drone", "descricao": "Componentes e cabos.", "e": 1, "risco": 1, "recompensa": 3, "requisito": {"atributo": "engenharia", "valor": 7}, "efeitos": {"texto": "Você derruba o drone com um curto. Peças de primeira.", "itens": [{"item": "componentes_eletronicos", "chance": 100, "min": 2, "max": 3}]}}, {"titulo": "Esconder-se", "descricao": "Esperar passar.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"texto": "O drone passa por cima e segue a rota."}}, {"titulo": "Usar um sinalizador", "descricao": "Confundir os sensores.", "e": 3, "risco": 1, "recompensa": 1, "custo": {"item": "sinalizador", "qtd": 1}, "efeitos": {"texto": "O drone segue a luz do sinalizador para longe."}}]'::jsonb, null),
  ('mil_cientista', 'regional', 'zona_militar_cientifica', 10, 'A cientista', 'Uma mulher de jaleco acena atrás de uma porta de vidro blindado. Ela segura um caderno.', '[{"titulo": "Abrir a porta", "descricao": "O código está no crachá ao lado.", "e": -2, "risco": 2, "recompensa": 3, "requisito": {"atributo": "percepcao", "valor": 7}, "efeitos": {"moral": 4, "texto": "Ela sai e entrega o caderno: anotações sobre o que deu errado. E sobre o que pode dar certo.", "xp": 20, "recruta_chance": 35}}, {"titulo": "Pedir o caderno pela fresta", "descricao": "Sem abrir.", "e": 0, "risco": 1, "recompensa": 2, "efeitos": {"texto": "Ela passa algumas folhas pela fresta e fica.", "xp": 10, "moral": -3}}, {"titulo": "Ir embora", "descricao": "Vidro blindado é proteção para os dois lados.", "e": 0, "risco": 1, "recompensa": 1, "cautelosa": true, "efeitos": {"moral_nao_ajudar": true, "texto": "Você vai. Ela continua acenando."}}]'::jsonb, null)
) as v(slug, escopo, regiao, peso, titulo, texto, opcoes, categorias)
left join public.regions r on r.slug = v.regiao
on conflict (slug) do update set
  escopo = excluded.escopo, region_id = excluded.region_id, peso = excluded.peso, titulo = excluded.titulo,
  texto = excluded.texto, opcoes = excluded.opcoes, categorias = excluded.categorias;

