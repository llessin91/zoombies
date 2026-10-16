'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState, type FormEvent } from 'react';
import { Botao } from '@/components/ui/Botao';
import { Campo } from '@/components/ui/Campo';
import { Cartao } from '@/components/ui/Cartao';
import { useToast } from '@/components/ui/Toast';
import { criarClienteNavegador } from '@/lib/supabase/client';
import { ehLimiteDeEnvio, mensagemErroAuth } from '@/lib/supabase/erros';
import { errosPorCampo, loginSchema, somenteEmailSchema } from '@/lib/validacao/auth';

type Modo = 'entrar' | 'link' | 'esqueci';

const TITULOS: Record<Modo, string> = {
  entrar: 'Entrar',
  link: 'Entrar com link mágico',
  esqueci: 'Recuperar senha',
};

export function FormularioLogin({ aviso }: { aviso?: string }) {
  const router = useRouter();
  const toast = useToast();
  const [modo, setModo] = useState<Modo>('entrar');
  const [email, setEmail] = useState('');
  const [senha, setSenha] = useState('');
  const [erros, setErros] = useState<Record<string, string>>({});
  const [info, setInfo] = useState<string | null>(null);
  const [carregando, setCarregando] = useState(false);

  function trocarModo(novo: Modo) {
    setModo(novo);
    setErros({});
    setInfo(null);
  }

  async function enviar(e: FormEvent) {
    e.preventDefault();
    setInfo(null);

    const validacao =
      modo === 'entrar' ? loginSchema.safeParse({ email, senha }) : somenteEmailSchema.safeParse({ email });
    if (!validacao.success) {
      setErros(errosPorCampo(validacao.error));
      return;
    }
    setErros({});
    setCarregando(true);

    try {
      const supabase = criarClienteNavegador();
      const emailLimpo = validacao.data.email;
      const origem = window.location.origin;

      if (modo === 'entrar') {
        const { error } = await supabase.auth.signInWithPassword({ email: emailLimpo, password: senha });
        if (error) {
          setErros({ geral: mensagemErroAuth(error) });
          return;
        }
        router.replace('/inicio');
        router.refresh();
        return;
      }

      // Link mágico e recuperação: resposta neutra para não revelar quais e-mails têm conta
      const { error } =
        modo === 'link'
          ? await supabase.auth.signInWithOtp({
              email: emailLimpo,
              options: { shouldCreateUser: false, emailRedirectTo: `${origem}/auth/callback?next=/inicio` },
            })
          : await supabase.auth.resetPasswordForEmail(emailLimpo, {
              redirectTo: `${origem}/auth/callback?next=/redefinir-senha`,
            });
      if (error && ehLimiteDeEnvio(error)) {
        setErros({ geral: mensagemErroAuth(error) });
        return;
      }
      setInfo('Se este e-mail tiver uma conta, enviamos um link. Confira a caixa de entrada e o spam.');
    } catch {
      toast.erro('Não foi possível conectar', 'Verifique a internet e tente de novo.');
    } finally {
      setCarregando(false);
    }
  }

  return (
    <Cartao titulo={TITULOS[modo]} variante="fita">
      {aviso && (
        <p role="alert" className="mb-3 rounded border border-acento-ambar/60 bg-acento-ambar/10 p-2 text-sm">
          {aviso}
        </p>
      )}
      <form onSubmit={enviar} noValidate className="space-y-4">
        <Campo
          rotulo="E-mail"
          type="email"
          autoComplete="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          erro={erros.email}
        />
        {modo === 'entrar' && (
          <Campo
            rotulo="Senha"
            type="password"
            autoComplete="current-password"
            value={senha}
            onChange={(e) => setSenha(e.target.value)}
            erro={erros.senha}
          />
        )}

        {erros.geral && (
          <p role="alert" className="text-sm text-acento-vermelho">
            {erros.geral}
          </p>
        )}
        {info && (
          <p role="status" className="rounded border border-acento-verde/60 bg-acento-verde/10 p-2 text-sm">
            {info}
          </p>
        )}

        <Botao type="submit" carregando={carregando} className="w-full">
          {modo === 'entrar' ? 'Entrar' : 'Enviar link'}
        </Botao>
      </form>

      <div className="mt-4 flex flex-col items-stretch gap-1">
        {modo === 'entrar' ? (
          <>
            <Botao variante="fantasma" onClick={() => trocarModo('esqueci')}>
              Esqueci a senha
            </Botao>
            <Botao variante="fantasma" onClick={() => trocarModo('link')}>
              Entrar com link mágico
            </Botao>
          </>
        ) : (
          <Botao variante="fantasma" onClick={() => trocarModo('entrar')}>
            Voltar para o login
          </Botao>
        )}
        <Link
          href="/cadastro"
          className="flex min-h-[44px] items-center justify-center rounded-md border border-borda text-sm hover:bg-fundo-2"
        >
          Criar conta
        </Link>
      </div>
    </Cartao>
  );
}
