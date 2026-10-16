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
