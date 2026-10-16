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
