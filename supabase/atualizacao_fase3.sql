-- ZOMBIES: atualização da Fase 3 (personagem).
-- Use se você JÁ rodou o setup da Fase 2. Cole tudo no SQL Editor do Supabase e clique em Run.
-- Pode rodar mais de uma vez sem problema.

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
