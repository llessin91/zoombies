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
