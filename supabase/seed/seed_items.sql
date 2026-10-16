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
  ('molotov', 'Molotov', 'consumivel', null, 'incomum', 1, 'Garrafa, pano e combustível. Arremessar de longe.', '{}', null, 1, true),
  ('sinalizador', 'Sinalizador', 'consumivel', null, 'incomum', 1, 'Chama a atenção. Escolha bem de quem.', '{}', null, 1, true),

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
