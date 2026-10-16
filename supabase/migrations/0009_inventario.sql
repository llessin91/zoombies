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
