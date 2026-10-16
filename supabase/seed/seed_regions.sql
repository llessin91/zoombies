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
