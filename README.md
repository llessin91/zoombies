# Zombies

Um jogo pra provar que você conseguiria sobreviver a um mundo apocalíptico zumbi.

Estado atual: **Fase 6** (inventário: filtros, busca, usar, equipar, descartar, 2 slots de arma, barras de carga e depósito, raridades com brilho e itens novos destacados). Abrigo e produção chegam na Fase 7.

## Já fez uma fase anterior? Atualize assim

1. **Banco**: no Supabase, **SQL Editor > New query**, cole **todo** o arquivo `supabase/atualizacao_fase6.sql` e clique em **Run**. Deve aparecer "Success". (Ele já inclui as Fases 3, 4 e 5; pode rodar mesmo se você já rodou alguma delas.)
2. **Site**: suba os arquivos desta pasta de novo para o mesmo repositório do GitHub (**Add file > Upload files**, arraste tudo e confirme com **Commit changes**). Os arquivos com o mesmo nome são substituídos. A Vercel publica sozinha em 1 ou 2 minutos.
3. Abra o jogo e siga o checklist da Fase 6 mais abaixo.

Se você ainda não fez nada, siga o passo a passo completo abaixo.

## Como colocar para funcionar (do zero)

Você precisa de três coisas: o banco (Supabase), o código no GitHub e um lugar para rodar (Vercel ou Codespaces).

### Passo 1: criar o projeto no Supabase

1. Crie uma conta grátis em https://supabase.com e clique em **New project**.
2. Dê o nome `zombies`, escolha uma senha forte para o banco (guarde em lugar seguro, não vamos usar agora) e a região **South America (São Paulo)**. Clique em **Create new project** e espere uns 2 minutos.

### Passo 2: criar as tabelas e o conteúdo do jogo

1. No menu esquerdo, abra **SQL Editor** e clique em **New query**.
2. Abra o arquivo `supabase/setup_completo.sql` deste projeto, copie **tudo** e cole no editor.
3. Clique em **Run**. Deve aparecer "Success. No rows returned".
4. Para conferir: menu **Table Editor**. Você deve ver `regions` (4 linhas), `locations` (32), `items` (41), `building_types` (19), `shelters` (4), `missions` (65), `events` (35) e `game_config` (55).

Pode rodar o arquivo de novo sem medo: ele não duplica nada e não apaga valores que você já editou em `game_config`.

### Passo 3: configurar o login

1. Menu **Authentication**, depois **Sign In / Providers**, e confirme que **Email** está ligado.
2. Para os primeiros testes, **desligue "Confirm email"**. Assim o cadastro entra direto no jogo. Antes de abrir o jogo para outras pessoas, ligue de novo.
3. Menu **Authentication**, depois **URL Configuration**:
   - **Site URL**: o endereço onde o jogo roda (ex.: `https://zombies.vercel.app`).
   - **Redirect URLs**: o mesmo endereço seguido de `/**` (ex.: `https://zombies.vercel.app/**`). Adicione também `http://localhost:3000/**` se for rodar no seu computador.
   - No Codespaces o endereço tem o formato `https://NOME-3000.app.github.dev`. Adicione com `/**`.

### Passo 4: pegar as chaves

No Supabase: **Project Settings** (engrenagem), depois **API** (ou **API Keys**).

- **Project URL** vai em `NEXT_PUBLIC_SUPABASE_URL`.
- **anon public** (ou **publishable**) vai em `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
- A chave **service_role** é secreta. **Não é necessária até aqui.** Nunca a coloque no GitHub.

### Passo 5A: rodar na Vercel (sem instalar nada)

1. Suba o conteúdo desta pasta para um repositório no GitHub (**Add file > Upload files**; o `package.json` precisa ficar na raiz).
2. Na Vercel: **Add New > Project**, escolha o repositório.
3. Antes de clicar em Deploy, abra **Environment Variables** e adicione as duas variáveis do Passo 4.
4. **Deploy**. Quando terminar, copie o endereço e volte ao Passo 3 para preencher Site URL e Redirect URLs.

### Passo 5B: rodar no Codespaces

1. No repositório do GitHub: **Code > Codespaces > Create codespace**.
2. No terminal: `cp .env.example .env.local` e preencha as duas variáveis.
3. Rode `npm install` e depois `npm run dev`. Abra a porta 3000 pelo aviso do Codespaces.

### Passo 5C: rodar no seu computador (opcional)

Precisa do Node.js LTS instalado pelo instalador `.msi`. Copie `.env.example` para `.env.local`, preencha, rode `npm install` e `npm run dev`, e abra http://localhost:3000.

## O que testar na Fase 6 (checklist)

1. Volte de uma expedição com saque. O menu **Inventário** ganha uma bolinha. Abra: os itens que acabaram de chegar aparecem com **novo** e brilho.
2. Cada item tem borda pela raridade (comum, incomum verde, raro azul, épico roxo, lendário dourado). Armas mostram a barra de durabilidade.
3. Use as abas (Todos, Recursos, Consumíveis, Armas, Itens-chave, Outros) e a busca (sem acento funciona: "agua" acha "Água potável").
4. Clique num item: abre o detalhe com descrição, raridade, peso, efeitos e os botões **Usar**, **Equipar** e **Descartar**. Botões bloqueados explicam o motivo ao passar o mouse.
5. **Usar** água, comida ou ração recupera stamina (não passa do máximo; com stamina cheia fica bloqueado). Bandagem, kit e analgésico curam ferimentos.
6. **Equipar** uma arma: ela vai para "Arma principal" ou "Corpo a corpo" (machado, facão etc.). Arma quebrada ou de nível alto fica bloqueada. Em **Personagem** o slot mostra a arma, o bônus e a durabilidade; na preparação da missão ela já vem escolhida.
7. **Descartar**: escolha a quantidade e confirme. Itens-chave e armas equipadas não podem ser descartados.
8. As barras mostram o peso da mochila e o depósito (o depósito só funciona quando você tiver abrigo, na Fase 7).

Para testar sem esperar o saque, dê itens a você pelo SQL Editor:

```sql
select public.entregar_itens(p.id, '[{"item":"agua_potavel","qtd":3},{"item":"bandagem","qtd":2},{"item":"glock_17","qtd":1},{"item":"facao","qtd":1}]')
  from public.profiles p where p.nome_sobrevivente = 'SEU NOME';
```

## O que testar na Fase 5 (checklist)

1. Em **Missões**, abra uma missão da Periferia e clique em **Iniciar expedição**. A stamina cai e você vai para a tela da expedição.
2. A cena é da região (Periferia: casas, postes e lixo ao vento; Centro: prédios, carros e letreiros; Industrial: chaminés e guindaste; Militar: cerca, holofotes e laboratório). Zumbis cambaleiam ao fundo, mais numerosos nas missões difíceis.
3. A barra anda sozinha. Se houver evento, aparece um traço na barra (sem dizer o que é). Linhas do diário surgem com o horário do jogo.
4. No evento, a barra para e aparece a decisão: opções com caveiras (risco) e joias (recompensa). Opções sem o atributo ou sem o item ficam apagadas com cadeado; passe o mouse para ver o motivo.
5. No fim: **Sucesso total**, **Sucesso parcial** ou **Fracasso**, com XP, moral, stamina gasta, ferimentos, zumbis abatidos e o saque (que vai direto para a mochila).
6. Clique em **Pular**: o resultado sai na hora (se tiver evento, ele aparece antes).
7. Comece outra expedição e feche a aba. Abra o jogo de novo: o cartão **Expedição em andamento** em Início (e o aviso em Missões) tem o botão **Retomar**.
8. Depois de uma expedição, o local fica **esgotado** por alguns dias do jogo (Mapa e Missões mostram).
9. Se o saque passar da sua capacidade de carga, aparece **O que levar?**: use − e + até caber e clique em **Levar isto**.

Para testar com arma e molotov, dê itens a você mesmo pelo SQL Editor:

```sql
insert into public.inventory (user_id, item_id, quantidade, durabilidade)
select p.id, i.id, 1, i.durabilidade_max from public.profiles p, public.items i
 where p.nome_sobrevivente = 'SEU NOME' and i.slug = 'glock_17';
insert into public.inventory (user_id, item_id, quantidade)
select p.id, i.id, 3 from public.profiles p, public.items i
 where p.nome_sobrevivente = 'SEU NOME' and i.slug = 'molotov';
```

Liberar todos os locais esgotados: `delete from public.location_cooldowns;`

## O que testar na Fase 4 (checklist)

1. Abra **Missões**. Aparecem 65 cartões com nome, local, dificuldade colorida, custo de stamina, duração, XP e ícones do que pode render.
2. Missões da Periferia e do Centro (se você tiver nível 4) mostram uma faixa: **Segura**, **Equilibrada**, **Arriscada** ou **Muito arriscada**. Nunca aparece número.
3. Missões da Zona Industrial e Militar mostram o cadeado e o motivo (ex.: "requer nível 8 e credencial industrial").
4. Use os filtros: região, dificuldade, categoria e **Somente disponíveis**. Com filtros que não acham nada, aparece "Limpar filtros".
5. Categoria **Coleta de combustível**: 9 missões, incluindo **Saquear as bombas do posto** (Posto de gasolina, no Terminal do Bairro Novo).
6. Clique numa missão: abre a preparação com a história, as barras de peso dos atributos, o que pode render, os riscos, arma e consumíveis (vazios até a Fase 6), a carga e o botão **Iniciar expedição** (desabilitado: passe o mouse para ver o motivo).
7. Abra **Mapa**: 4 regiões; as bloqueadas têm névoa e cadeado com o requisito. Clique numa região para ver os locais, as dificuldades e o estado.
8. Teste o **esgotamento de local** pelo SQL Editor (veja abaixo): o local fica âmbar no mapa e as missões dele mostram "Esgotado, volta em 3 dias do jogo".

Esgotar um local (como se você tivesse acabado de saquear a Oficina Dois Irmãos):

```sql
select public.aplicar_cooldown_local(p.id, l.id, 'facil')
  from public.profiles p, public.locations l
 where p.nome_sobrevivente = 'SEU NOME' and l.slug = 'oficina_dois_irmaos';
```

Para liberar de novo: `delete from public.location_cooldowns;`

## O que testar na Fase 3 (checklist)

1. Crie uma conta nova. Em vez do tutorial, você cai em **Quem é (seu nome)?**, a criação do personagem.
2. Os seis atributos começam em 1 e há 6 pontos restantes. O botão "Começar a sobreviver" fica bloqueado até distribuir todos. Nenhum atributo passa de 3.
3. Clique em **Começar a sobreviver**. Você vai para **Personagem**: nível 1, XP 0/100, stamina 20/20 "Cheia", moral 70 "Boa".
4. A barra de cima mostra nível, XP, stamina, moral e o relógio do jogo (**Dia 1 · 08:00** na criação; 1 hora real = 1 dia do jogo).
5. Em **Início**, o cartão do personagem e "Últimos acontecimentos" com a frase "Você abriu os olhos...".
6. Teste a **subida de nível** (ainda não há missões, então damos XP pelo SQL Editor; veja abaixo). Recarregue a página: aparece a comemoração com partículas.
7. Em **Personagem**, use o **+** nos atributos, o **−** para tirar e **Desfazer**. Só ao clicar em **Confirmar pontos** os pontos valem. Recarregue: continuam lá.
8. Teste a **stamina** (veja abaixo): a barra volta sozinha com o tempo, com contagem "+1 em 5:59".

### Testes pelo SQL Editor (só para você, dono do jogo)

Troque `SEU NOME` pelo nome do sobrevivente. O SQL Editor roda como administrador; jogadores comuns **não** conseguem chamar essas funções.

Dar 300 de XP (sobe do nível 1 ao 3 e ganha 6 pontos):

```sql
select public.conceder_xp(id, 300) from public.profiles where nome_sobrevivente = 'SEU NOME';
```

Gastar 15 de stamina e simular que se passaram 33 minutos (deve voltar a 10 e mostrar "+1 em 3:00"):

```sql
update public.characters c
   set stamina_atual = 5, stamina_atualizada_em = now() - interval '33 minutes'
  from public.profiles p
 where p.id = c.user_id and p.nome_sobrevivente = 'SEU NOME';
```

Mudar a moral (soma ou subtrai, sempre entre 0 e 100):

```sql
select public.ajustar_moral(id, -40, 'Teste de moral') from public.profiles where nome_sobrevivente = 'SEU NOME';
```

### Testes automáticos

No Codespaces ou no computador: `npm test`. São 103 testes (usar, equipar e descartar com todas as recusas, filtros e busca sem acento, desfecho total/parcial/fracasso, saque e XP por desfecho, carga e "o que levar", ferimento, desgaste da arma, opção cautelosa após 24 h, barra com pausa, fórmula de sucesso com limites 5 e 95 e efeitos de B, M, I e E, faixas, desbloqueio de regiões, esgotamento de local, carga, curva de XP, pontos por nível incluindo a troca de 3 para 2 no nível 11, stamina por tempo e teto, criação, distribuição, moral, relógio, limite de pedidos e mensagens de erro). No GitHub, cada envio roda lint, checagem de tipos e testes sozinho (aba **Actions**).

## Painel de balanceamento

Todos os números provisórios ficam na tabela `game_config`. Para mudar um:

1. Supabase, **Table Editor**, tabela `game_config`.
2. Ache a linha pela coluna `chave`.
3. Edite a coluna `valor` (é JSON: número simples como `6`, lista como `[100,150]` ou objeto como `{"facil":2}`) e salve. O jogo usa o novo valor na próxima vez que a página carregar.

Chaves que já valem nesta fase:

| Chave | Padrão | O que faz |
| --- | --- | --- |
| `stamina.inicial` | 20 | Stamina ao criar o personagem |
| `stamina.maxima` | 20 | Stamina máxima (o abrigo pode dar bônus em %) |
| `stamina.minutos_por_ponto` | 6 | Minutos reais para voltar 1 ponto (10 por hora) |
| `atributos.pontos_na_criacao` | 12 | Pontos para distribuir na criação |
| `atributos.minimo_na_criacao` / `maximo_na_criacao` | 1 / 3 | Limites de cada atributo na criação |
| `atributos.maximo` | 20 | Máximo de um atributo |
| `moral.inicial` | 70 | Moral ao criar o personagem |
| `moral.divisor_modificador` | 10 | Efeito da moral nas missões: (moral − 50) / 10 |
| `xp.para_subir_ate_nivel_10` | [100, 150, 220, 320, 450, 600, 800, 1050, 1350] | XP para 1→2 até 9→10 |
| `xp.incremento_apos_nivel_10` | 350 | Do 10 em diante, soma isto a cada nível |
| `xp.pontos_por_nivel` | {"ate_nivel_10": 3, "a_partir_nivel_11": 2} | Pontos ganhos por nível |
| `xp.ultimo_nivel_com_mais_pontos` | 10 | Último nível que ainda dá os pontos maiores |
| `tempo.dias_jogo_por_hora_real` | 1 | Dias do jogo por hora real (1 = cada hora real é um dia) |
| `tempo.hora_inicial` | 8 | Hora do relógio quando o personagem nasce |
| `stamina.custo_por_dificuldade` | {"facil":2,"media":3,"dificil":5,"lendaria":6} | Stamina para sair em missão |
| `missao.formula` | base 50, peso 5, mínimo 5, máximo 95 | Fórmula P = 50 + (H − D) × 5 + B + M − I + E, entre 5 e 95 |
| `missao.dificuldade_numerica` | {"facil":3,"media":6,"dificil":10,"lendaria":14} | D da fórmula |
| `missao.faixas_chance` | {"segura":70,"equilibrada":45,"arriscada":25} | Chance mínima de cada faixa mostrada ao jogador |
| `missao.duracao_segundos` | {"facil":30,"media":60,"dificil":90,"lendaria":120} | Duração real da expedição |
| `missao.xp_base` | {"facil":20,"media":45,"dificil":90,"lendaria":160} | XP por dificuldade |
| `missao.cooldown_local_dias` | {"facil":3,"media":5,"dificil":8,"lendaria":12} | Dias do jogo que o local fica esgotado depois de saqueado |
| `carga.base` / `carga.por_ponto_forca` | 10 / 2 | Capacidade de carga = 10 + Força × 2 |
| `eventos.probabilidade_pct` | {"facil":60,"media":70,"dificil":80,"lendaria":90} | Chance de ter evento na expedição |
| `eventos.peso_regional_pct` | 70 | % de eventos regionais no sorteio (o resto é geral) |
| `eventos.prazo_decisao_horas` | 24 | Horas reais até a opção cautelosa ser aplicada sozinha |
| `eventos.ruido` | 5 por nível de ruído, −0,5 por ponto de Agilidade | Ajuste da chance de evento |
| `eventos.posicao_pct` | 30 a 70 | Em que parte da barra o evento acontece |
| `missao.formula` (parcial e falha) | margem 15, parcial 50% do saque e do XP, fracasso 15% do XP | Desfechos |
| `missao.falha` | moral −3, 40% de chance de ferimento | Consequências do fracasso |
| `missao.reducao_ferimento_pct` | bandagem 20, kit 40 | Quanto cada item levado protege no fracasso |
| `missao.penalidade_por_ferimento` | 5 | I da fórmula por nível de ferimento |
| `ferimento.maximo` / `ferimento.dias_recuperacao_por_nivel` | 3 / 2 | Ferimentos curam sozinhos com o tempo do jogo |
| `armas.desgaste_por_missao` | {"facil":2,"media":3,"dificil":5,"lendaria":8} | Durabilidade perdida (dobra no fracasso) |
| `missao.zumbis_abatidos` | combate 3–8, chefe 1, outras 0–2 | Só para as estatísticas |
| `missao.linhas_log` | 6 | Linhas do diário por expedição |
| `stamina.recupera_por_item` | água 1, comida enlatada 2, ração militar 3 | Stamina recuperada ao usar |
| `itens.cura_ferimento` | bandagem 1, kit 2, analgésico 1 | Níveis de ferimento curados ao usar |

Eventos: tabela `events` ou arquivo `supabase/seed/seed_events.sql` (opções, custos, requisitos, efeitos e peso no sorteio). O bônus de molotov (4) e sinalizador (2) fica em `items.efeitos` (`bonus_missao`); armas também.

Outros números provisórios ficam no catálogo:

- **Regiões** (tabela `regions`): `nivel_minimo` (Periferia 1, Centro 4, Industrial 8, Militar 12) e `item_acesso_slug` (item-chave exigido).
- **Missões** (tabela `missions` ou arquivo `supabase/seed/seed_missions.sql`): `pesos` dos atributos (somam 100), `loot` (chance %, mínimo e máximo de cada item), `requisitos` (nível, itens). Para dar custo, duração ou XP diferente a UMA missão, preencha `custo_stamina`, `duracao_segundos` ou `xp_base` dela (vazio = usa o da dificuldade).
- **Locais** (tabela `locations`): `cooldown_dias` (vazio = usa o da dificuldade).

Atenção: rodar `seed_missions.sql`, `seed_events.sql` (ou o setup completo, ou o arquivo de atualização) de novo **volta missões e eventos ao padrão do arquivo**. Se editar missões pelo Table Editor, edite também o arquivo.

As demais chaves (recrutas, energia, ataques, fabricação) passam a valer nas fases seguintes. Personagens já criados não mudam se você alterar valores de criação.

Gancho futuro: cada personagem tem `xp_multiplier` (padrão 1.0). XP final = XP base × multiplicador. Não há tela para isso, de propósito.

## Segurança

- Todas as tabelas têm RLS ligado. O jogador logado só **lê** os próprios dados e o catálogo; **nenhuma tabela aceita escrita direta** do navegador.
- Toda ação passa por `src/app/api/...`: confere a sessão, limita pedidos repetidos, valida os dados com Zod e chama uma função do banco que confere as regras de novo, dentro de uma transação, travando a linha do personagem (dois cliques ao mesmo tempo não gastam o mesmo ponto duas vezes).
- Funções internas (dar XP, gastar stamina, mudar moral) **não** podem ser chamadas pelo site: só por outras funções do banco.
- O horário usado é sempre o do banco (`now()`), nunca o do computador do jogador.
- Apagar a conta de um usuário no Supabase apaga todos os dados dele em cascata.

## Estrutura de pastas

- `src/app`: páginas. `(auth)` login e cadastro; `(criacao)` criação do personagem; `(game)` o jogo; `api` as ações; `auth/callback` links dos e-mails.
- `src/components`: `ui` componentes de interface, `auth` formulários, `game` telas e peças do jogo, `scenes` cenas animadas.
- `src/lib/game`: regras (`progressao.ts`, `stamina.ts`, `tempo.ts`, `formulas.ts`, `atributos.ts`, `missoes.ts`, `config.ts`) e `mundo.ts` (monta os dados do Mapa e das Missões). `src/lib/api`: esqueleto das ações. `src/lib/validacao`: Zod. `src/lib/supabase`: conexão.
- `supabase/migrations`: tabelas, segurança e funções, numeradas. `supabase/seed`: conteúdo. `supabase/setup_completo.sql`: tudo junto. `supabase/atualizacao_fase6.sql`: o que mudou nas Fases 3 a 6.
- `tests`: testes automáticos (Vitest).

## Problemas comuns

- **"Falta atualizar o banco"** ou **"O banco ainda não tem as missões desta fase"**: o site está numa fase mais nova que o Supabase. Rode `supabase/atualizacao_fase6.sql` no SQL Editor.
- **"Sua stamina já está cheia"** ou **"Você não está ferido"** ao usar um item: é proposital, para não gastar à toa.
- **Mochila acima da capacidade**: por enquanto não atrapalha; o que conta na expedição é o que você leva e traz. Quando tiver abrigo (Fase 7), guarde no depósito.
- **"Você já está numa expedição"**: termine (ou retome) a atual pelo botão **Retomar** em Início.
- **"Decida o que levar da última expedição"**: abra a expedição pelo **Retomar** e escolha o que levar.
- **Fracassos frequentes no começo**: com atributos iniciais, a chance fica perto de 50%. O tutorial (Fase 11) garante o primeiro sucesso; para ajustar o equilíbrio, mexa em `missao.formula` e `missao.dificuldade_numerica`.
- **Todas as missões aparecem "Muito arriscada"**: normal no começo para missões difíceis. Para mudar o corte das faixas, edite `missao.faixas_chance`.
- **Tela branca ou erro 500 falando de variáveis**: faltam `NEXT_PUBLIC_SUPABASE_URL` e `NEXT_PUBLIC_SUPABASE_ANON_KEY`. Na Vercel, adicione e faça **Redeploy**; no Codespaces, confira o `.env.local` e reinicie o `npm run dev`.
- **"Invalid API key" ou erro de conexão**: a chave foi copiada incompleta ou é a errada. Copie de novo a anon/publishable.
- **Link do e-mail leva para localhost ou dá "link expirou"**: Site URL ou Redirect URLs errados (Passo 3).
- **"Muitas tentativas"**: o Supabase limita e-mails por hora no plano gratuito. Espere ou desligue "Confirm email" para testar.
- **"Calma, sobrevivente. Muitos pedidos seguidos"**: você clicou muitas vezes seguidas. Espere 10 segundos.
- **A comemoração de nível não aparece depois do SQL**: recarregue a página (o jogo também confere sozinho a cada 2 minutos e quando você volta para a aba).
- **Relógio do jogo correndo muito rápido** (pula vários dias por minuto): `tempo.dias_jogo_por_hora_real` está 24. O certo é 1; a atualização da Fase 3 corrige sozinha se o valor ainda for o de fábrica.
- **Erro no SQL Editor**: rode o arquivo inteiro de uma vez. Se parou no meio, rode de novo, ele é seguro para repetir.
