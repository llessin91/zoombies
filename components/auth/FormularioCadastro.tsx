'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState, type FormEvent } from 'react';
import { MailCheck } from 'lucide-react';
import { Botao } from '@/components/ui/Botao';
import { Campo, CampoCaixa } from '@/components/ui/Campo';
import { Cartao } from '@/components/ui/Cartao';
import { useToast } from '@/components/ui/Toast';
import { criarClienteNavegador } from '@/lib/supabase/client';
import { mensagemErroAuth } from '@/lib/supabase/erros';
import { cadastroSchema, errosPorCampo } from '@/lib/validacao/auth';

export function FormularioCadastro() {
  const router = useRouter();
  const toast = useToast();
  const [valores, setValores] = useState({ nome: '', email: '', senha: '', confirmar: '', aceitou: false });
  const [erros, setErros] = useState<Record<string, string>>({});
  const [carregando, setCarregando] = useState(false);
  const [emailEnviado, setEmailEnviado] = useState<string | null>(null);

  function mudar<K extends keyof typeof valores>(campo: K, valor: (typeof valores)[K]) {
    setValores((v) => ({ ...v, [campo]: valor }));
  }

  async function enviar(e: FormEvent) {
    e.preventDefault();
    const validacao = cadastroSchema.safeParse(valores);
    if (!validacao.success) {
      setErros(errosPorCampo(validacao.error));
      return;
    }
    setErros({});
    setCarregando(true);

    try {
      const supabase = criarClienteNavegador();
      const dados = validacao.data;

      // Aviso antecipado de nome repetido (o banco também garante a unicidade)
      const { data: livre, error: erroNome } = await supabase.rpc('nome_disponivel', { p_nome: dados.nome });
      if (erroNome) throw erroNome;
      if (!livre) {
        setErros({ nome: 'Este nome de sobrevivente já está em uso.' });
        return;
      }

      const { data, error } = await supabase.auth.signUp({
        email: dados.email,
        password: dados.senha,
        options: {
          data: { nome_sobrevivente: dados.nome, aceitou_16_mais: true },
          emailRedirectTo: `${window.location.origin}/auth/callback?next=/tutorial`,
        },
      });
      if (error) {
        setErros({ geral: mensagemErroAuth(error) });
        return;
      }
      // E-mail já cadastrado: o Supabase devolve um usuário sem identidades
      if (data.user && data.user.identities?.length === 0) {
        setErros({ email: 'Este e-mail já tem uma conta. Tente entrar.' });
        return;
      }
      if (data.session) {
        router.replace('/tutorial');
        router.refresh();
        return;
      }
      setEmailEnviado(dados.email);
    } catch {
      toast.erro('Não foi possível criar a conta', 'Verifique a internet e tente de novo.');
    } finally {
      setCarregando(false);
    }
  }

  if (emailEnviado) {
    return (
      <Cartao titulo="Quase lá" icone={<MailCheck className="h-6 w-6 text-acento-verde" aria-hidden />}>
        <p className="text-sm">
          Enviamos um link de confirmação para <strong>{emailEnviado}</strong>. Abra o e-mail e clique no link para
          ativar a conta e começar o tutorial.
        </p>
        <p className="mt-2 text-xs text-texto-suave">Não chegou? Confira o spam. Abra o link no mesmo navegador em que criou a conta.</p>
        <Link href="/login" className="mt-4 inline-block text-sm text-acento-verde underline">
          Voltar para o login
        </Link>
      </Cartao>
    );
  }

  return (
    <Cartao titulo="Criar conta" variante="fita">
      <form onSubmit={enviar} noValidate className="space-y-4">
        <Campo
          rotulo="Nome do sobrevivente"
          autoComplete="nickname"
          value={valores.nome}
          onChange={(e) => mudar('nome', e.target.value)}
          erro={erros.nome}
          dica="De 3 a 20 caracteres. É único e aparece para os outros jogadores."
        />
        <Campo
          rotulo="E-mail"
          type="email"
          autoComplete="email"
          value={valores.email}
          onChange={(e) => mudar('email', e.target.value)}
          erro={erros.email}
        />
        <Campo
          rotulo="Senha"
          type="password"
          autoComplete="new-password"
          value={valores.senha}
          onChange={(e) => mudar('senha', e.target.value)}
          erro={erros.senha}
          dica="Mínimo de 8 caracteres."
        />
        <Campo
          rotulo="Confirmar senha"
          type="password"
          autoComplete="new-password"
          value={valores.confirmar}
          onChange={(e) => mudar('confirmar', e.target.value)}
          erro={erros.confirmar}
        />
        <CampoCaixa
          rotulo="Tenho 16 anos ou mais"
          checked={valores.aceitou}
          onChange={(e) => mudar('aceitou', e.target.checked)}
          erro={erros.aceitou}
        />

        {erros.geral && (
          <p role="alert" className="text-sm text-acento-vermelho">
            {erros.geral}
          </p>
        )}

        <Botao type="submit" carregando={carregando} className="w-full">
          Criar conta
        </Botao>
      </form>

      <Link
        href="/login"
        className="mt-4 flex min-h-[44px] items-center justify-center rounded-md border border-borda text-sm hover:bg-fundo-2"
      >
        Já tenho conta
      </Link>
    </Cartao>
  );
}
