# Zombies

Um jogo pra provar que você conseguiria sobreviver a um mundo apocalíptico zumbi.

Estado atual: **Fase 1** (projeto base, design system e layout). Sem banco e sem login ainda.

## O que você precisa instalar

1. **Node.js versão LTS** (https://nodejs.org). Depois de instalar, abra um terminal e rode `node -v`. Deve mostrar 18.18 ou maior.
2. **VS Code** (https://code.visualstudio.com), recomendado.
3. Git, conta no GitHub, Supabase e Vercel: só nas fases seguintes.

## Como rodar

1. Extraia o zip e abra a pasta `zombies` no VS Code (Arquivo > Abrir Pasta).
2. Abra o terminal do VS Code (Terminal > Novo Terminal).
3. Rode: `npm install` (demora 1 a 3 minutos na primeira vez).
4. Rode: `npm run dev`
5. Abra http://localhost:3000 no navegador. Você será levado para `/inicio`.
6. Para ver todos os componentes, abra http://localhost:3000/kit-ui
7. Para parar o servidor: `Ctrl + C` no terminal.

Comandos úteis: `npm run lint` (verifica estilo), `npm run typecheck` (verifica tipos), `npm run build` (gera a versão de produção; precisa de internet para baixar as fontes do Google).

## O que você deve ver

- Fundo escuro com granulado e vinheta, título ZOMBIES em verde.
- Desktop: barra superior (nível, XP, stamina, moral, relógio), menu à esquerda e painel de recursos/alertas à direita (em telas bem largas).
- Celular (reduza a janela abaixo de 1024 px): barra inferior com 5 ícones + "Mais".
- Cada página mostra título, skeleton e uma mensagem de estado vazio.

Os números da barra superior (nível 1, stamina 20/20, moral 70) são fixos nesta fase.

## Estrutura de pastas

- `src/app`: páginas. `(game)` é o jogo, `(auth)` é login e cadastro.
- `src/components/ui`: botões, cartões, barras, modal, abas, toast, selo, skeleton.
- `src/components/game`: layout do jogo e blocos de página.
- `src/lib`: regras e utilitários. `lib/game` receberá as fórmulas e `config.ts` a partir da Fase 3.
- `supabase`: migrations e seeds (Fase 2).
- `tests`: testes (Fase 3 em diante).

## Painel de balanceamento

Será preenchido a partir da Fase 3. Todos os valores marcados como provisórios no prompt ficarão em `src/lib/game/config.ts` e na tabela `game_config`, com instruções de como alterar cada um.

## Problemas comuns

- **`npm` não é reconhecido**: o Node.js não foi instalado ou o terminal foi aberto antes. Feche e abra o terminal de novo.
- **Porta 3000 em uso**: o Next escolhe outra porta e mostra no terminal. Use o endereço que aparecer.
- **Erro ao baixar fontes**: confira a internet. As fontes (Staatliches, Inter, JetBrains Mono) vêm do Google no build.
- **Página sem estilo**: pare o servidor (`Ctrl + C`) e rode `npm run dev` de novo.
