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
