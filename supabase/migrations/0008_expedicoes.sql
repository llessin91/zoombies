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
