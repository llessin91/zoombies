# Zombies

Um jogo pra provar que você conseguiria sobreviver a um mundo apocalíptico zumbi.

Estado atual: **Fase 3** (personagem: criação, atributos, XP, níveis, pontos, moral e stamina). Mapa e missões chegam na Fase 4.

## Já fez a Fase 2? Atualize assim

1. **Banco**: no Supabase, **SQL Editor > New query**, cole **todo** o arquivo `supabase/atualizacao_fase3.sql` e clique em **Run**. Deve aparecer "Success".
2. **Site**: suba os arquivos desta pasta de novo para o mesmo repositório do GitHub (**Add file > Upload files**, arraste tudo e confirme com **Commit changes**). Os arquivos com o mesmo nome são substituídos. A Vercel publica sozinha em 1 ou 2 minutos.
3. Abra o jogo e siga o checklist da Fase 3 mais abaixo.

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
4. Para conferir: menu **Table Editor**. Você deve ver `regions` (4 linhas), `locations` (32), `items` (41), `building_types` (19), `shelters` (4) e `game_config` (43).

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

No Codespaces ou no computador: `npm test`. São 49 testes (curva de XP, pontos por nível incluindo a troca de 3 para 2 no nível 11, stamina por tempo e teto, criação, distribuição, moral, relógio, limite de pedidos e mensagens de erro). No GitHub, cada envio roda lint, checagem de tipos e testes sozinho (aba **Actions**).

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

As demais chaves (missões, eventos, carga, recrutas, energia, ataques, fabricação) passam a valer nas fases seguintes. Personagens já criados não mudam se você alterar valores de criação.

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
- `src/lib/game`: regras (`progressao.ts`, `stamina.ts`, `tempo.ts`, `formulas.ts`, `atributos.ts`, `config.ts`). `src/lib/api`: esqueleto das ações. `src/lib/validacao`: Zod. `src/lib/supabase`: conexão.
- `supabase/migrations`: tabelas, segurança e funções, numeradas. `supabase/seed`: conteúdo. `supabase/setup_completo.sql`: tudo junto. `supabase/atualizacao_fase3.sql`: só o que mudou na Fase 3.
- `tests`: testes automáticos (Vitest).

## Problemas comuns

- **"Falta atualizar o banco"** ao abrir o jogo: o site já está na Fase 3, mas o Supabase não. Rode `supabase/atualizacao_fase3.sql` no SQL Editor.
- **Tela branca ou erro 500 falando de variáveis**: faltam `NEXT_PUBLIC_SUPABASE_URL` e `NEXT_PUBLIC_SUPABASE_ANON_KEY`. Na Vercel, adicione e faça **Redeploy**; no Codespaces, confira o `.env.local` e reinicie o `npm run dev`.
- **"Invalid API key" ou erro de conexão**: a chave foi copiada incompleta ou é a errada. Copie de novo a anon/publishable.
- **Link do e-mail leva para localhost ou dá "link expirou"**: Site URL ou Redirect URLs errados (Passo 3).
- **"Muitas tentativas"**: o Supabase limita e-mails por hora no plano gratuito. Espere ou desligue "Confirm email" para testar.
- **"Calma, sobrevivente. Muitos pedidos seguidos"**: você clicou muitas vezes seguidas. Espere 10 segundos.
- **A comemoração de nível não aparece depois do SQL**: recarregue a página (o jogo também confere sozinho a cada 2 minutos e quando você volta para a aba).
- **Relógio do jogo correndo muito rápido** (pula vários dias por minuto): `tempo.dias_jogo_por_hora_real` está 24. O certo é 1; a atualização da Fase 3 corrige sozinha se o valor ainda for o de fábrica.
- **Erro no SQL Editor**: rode o arquivo inteiro de uma vez. Se parou no meio, rode de novo, ele é seguro para repetir.
