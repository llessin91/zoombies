-- Os 4 abrigos iniciais. Números de vantagens e desvantagens do prompt (10%, 5%, 5 unidades, +1 stamina)
-- estão aqui. Quantidade de slots, ruído, dano e custo de reconstrução são PROVISÓRIOS.

insert into public.shelters (slug, tipo, nome, descricao, region_id, location_id, slots_iniciais, vantagens, desvantagens, ordem)
select v.slug, 'inicial', v.nome, v.descricao, r.id, l.id, v.slots, v.vantagens::jsonb, v.desvantagens::jsonb, v.ordem
from (values
  ('apartamento_barricado', 'Apartamento barricado',
   'Quatro paredes, uma porta reforçada com o sofá e uma vista privilegiada do caos. Pequeno, mas ninguém reclamou do aluguel.',
   'periferia', 'conjunto_primavera', 4, '{"stamina_max_bonus_pct":10}', '{"espaco_reduzido":true}', 1),
  ('oficina_abandonada', 'Oficina abandonada',
   'Cheira a graxa e a decisões questionáveis. Tem bancada, ferramentas e um forno que ainda aquece. O barulho, porém, atrai visitas.',
   'periferia', 'oficina_dois_irmaos', 6, '{"engenharia_bonus_pct":10,"forja_basica":true}', '{"ruido_ataque_mult":1.25}', 2),
  ('porao_mercearia', 'Porão da mercearia',
   'Fresco, escuro e cheio de prateleiras que o antigo dono jurava estarem vazias. Sair de lá exige subir uma escada que parece cada vez maior.',
   'periferia', 'mercearia_do_joaquim', 6, '{"recursos_basicos_iniciais":5,"comida_inicial":5,"agua_inicial":5}', '{"custo_stamina_saida_extra":1,"removido_por":"saida_reforcada"}', 3),
  ('trailer_blindado', 'Trailer blindado',
   'Um trailer com chapas soldadas por alguém que nunca viu um manual. Leve e veloz para fugir, mas qualquer ataque sério vira uma lata amassada.',
   'periferia', 'campo_do_uniao', 5, '{"agilidade_bonus_pct_periferia":5,"furtividade_bonus_pct_periferia":5}', '{"dano_ataque_mult":1.25,"reconstrucao_custo_mult":1.5}', 4)
) as v(slug, nome, descricao, regiao, local, slots, vantagens, desvantagens, ordem)
join public.regions r on r.slug = v.regiao
join public.locations l on l.slug = v.local
on conflict (slug) do update set
  nome = excluded.nome, descricao = excluded.descricao, region_id = excluded.region_id, location_id = excluded.location_id,
  slots_iniciais = excluded.slots_iniciais, vantagens = excluded.vantagens, desvantagens = excluded.desvantagens, ordem = excluded.ordem;
