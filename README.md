# Zombies

Um jogo pra provar que você conseguiria sobreviver a um mundo apocalíptico zumbi.

Estado atual: **Fase 2** (Supabase, banco de dados, login e cadastro). O personagem e as missões chegam nas próximas fases.

## Como colocar para funcionar (do zero)

Você precisa de três coisas: o banco (Supabase), o código no GitHub e um lugar para rodar (Vercel ou Codespaces).

### Passo 1: criar o projeto no Supabase

1. Crie uma conta grátis em https://supabase.com e clique em **New project**.
2. Dê o nome `zombies`, escolha uma senha forte para o banco (guarde em lugar seguro, não vamos usar agora) e a região **South America (São Paulo)**. Clique em **Create new project** e espere uns 2 minutos.

### Passo 2: criar as tabelas e o conteúdo do jogo

1. No menu esquerdo, abra **SQL Editor** e clique em **New query**.
2. Abra o arquivo `supabase/setup_completo.sql` deste projeto, copie **tudo** e cole no editor.
3. Clique em **Run**. Deve aparecer "Success. No rows returned".
4. Para conferir: menu **Table Editor**. Você deve ver `regions` (4 linhas), `locations` (32), `items` (41), `building_types` (19), `shelters` (4) e `game_config` (41).

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
- A chave **service_role** é secreta. **Não é necessária na Fase 2.** Nunca a coloque no GitHub.

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

## O que testar (checklist)

1. Abra o endereço do jogo. Você deve cair na tela de **login**, com a cidade em ruínas ao fundo e zumbis se balançando.
2. Clique em **Criar conta**. Tente enviar vazio: devem aparecer mensagens de erro em vermelho.
3. Preencha nome (3 a 20 letras), e-mail, senha (8 ou mais), confirmação e marque "Tenho 16 anos ou mais". Envie.
4. Com "Confirm email" desligado, você entra direto em **/tutorial** (ainda uma tela vazia). Com ele ligado, aparece "Quase lá"; clique no link do e-mail.
5. Confira seu nome em "Sobrevivente" no menu lateral. No Supabase, **Table Editor > profiles** deve ter uma linha com ele.
6. Clique em **Sair**. Você volta ao login. Tente abrir `/missoes` direto: deve voltar ao login.
7. Tente criar outra conta com o mesmo nome (mudando maiúsculas): deve avisar que já está em uso.
8. Teste **Esqueci a senha** e **Entrar com link mágico**: ambos mostram uma resposta neutra e mandam e-mail se a conta existir.

## Painel de balanceamento (parcial)

Todos os números provisórios do jogo ficam na tabela `game_config`. Para mudar um:

1. Supabase, **Table Editor**, tabela `game_config`.
2. Ache a linha pela coluna `chave`, por exemplo `stamina.minutos_por_ponto`.
3. Edite a coluna `valor` (é JSON: número simples como `6`, ou objeto como `{"facil":2,"media":3}`) e salve.

Valores de catálogo (pesos de itens, bônus de armas, custo e tempo de instalações, vantagens dos abrigos) ficam nos arquivos `supabase/seed/*.sql` e na tabela correspondente. As chaves de `game_config` passam a ser usadas pelas fases seguintes; nesta fase nada no jogo lê esses valores ainda.

## Segurança desta fase

- Todas as tabelas têm RLS ligado. O jogador logado só **lê** os próprios dados e o catálogo; **nenhuma tabela aceita escrita direta** do navegador.
- O servidor valida o cadastro (nome de 3 a 20 caracteres e 16+) dentro do banco, mesmo que alguém burle a tela.
- Rotas do jogo exigem login (middleware e layout).
- Apagar a conta de um usuário no Supabase apaga todos os dados dele em cascata.

## Estrutura de pastas

- `src/app`: páginas. `(auth)` login, cadastro e nova senha; `(game)` o jogo; `auth/callback` recebe os links dos e-mails.
- `src/components`: `ui` componentes de interface, `auth` formulários, `game` layout do jogo, `scenes` cenas animadas.
- `src/lib/supabase`: conexão com o banco (navegador, servidor e middleware). `src/lib/validacao`: regras de validação (Zod).
- `supabase/migrations`: tabelas e segurança, numeradas. `supabase/seed`: conteúdo do jogo. `supabase/setup_completo.sql`: tudo junto para colar no SQL Editor.

## Problemas comuns

- **Tela branca ou erro 500 falando de variáveis**: faltam `NEXT_PUBLIC_SUPABASE_URL` e `NEXT_PUBLIC_SUPABASE_ANON_KEY`. Na Vercel, adicione e faça **Redeploy**; no Codespaces, confira o `.env.local` e reinicie o `npm run dev`.
- **"Invalid API key" ou erro de conexão**: a chave foi copiada incompleta ou é a errada. Copie de novo a anon/publishable.
- **Link do e-mail leva para localhost ou dá "link expirou"**: Site URL ou Redirect URLs errados (Passo 3). Abra o link no mesmo navegador em que criou a conta.
- **"Muitas tentativas"**: o Supabase limita e-mails por hora no plano gratuito. Espere ou desligue "Confirm email" para testar.
- **Erro no SQL Editor**: rode o arquivo inteiro de uma vez. Se parou no meio, rode de novo, ele é seguro para repetir.
- **Cadastro diz "nome em uso" sem ser seu**: o nome é único sem diferenciar maiúsculas de minúsculas.
