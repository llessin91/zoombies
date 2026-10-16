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
