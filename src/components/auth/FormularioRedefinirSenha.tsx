'use client';

import { useRouter } from 'next/navigation';
import { useState, type FormEvent } from 'react';
import { Botao } from '@/components/ui/Botao';
import { Campo } from '@/components/ui/Campo';
import { Cartao } from '@/components/ui/Cartao';
import { useToast } from '@/components/ui/Toast';
import { criarClienteNavegador } from '@/lib/supabase/client';
import { mensagemErroAuth } from '@/lib/supabase/erros';
import { errosPorCampo, novaSenhaSchema } from '@/lib/validacao/auth';

export function FormularioRedefinirSenha() {
  const router = useRouter();
  const toast = useToast();
  const [senha, setSenha] = useState('');
  const [confirmar, setConfirmar] = useState('');
  const [erros, setErros] = useState<Record<string, string>>({});
  const [carregando, setCarregando] = useState(false);

  async function enviar(e: FormEvent) {
    e.preventDefault();
    const validacao = novaSenhaSchema.safeParse({ senha, confirmar });
    if (!validacao.success) {
      setErros(errosPorCampo(validacao.error));
      return;
    }
    setErros({});
    setCarregando(true);
    try {
      const { error } = await criarClienteNavegador().auth.updateUser({ password: validacao.data.senha });
      if (error) {
        setErros({ geral: mensagemErroAuth(error) });
        return;
      }
      toast.sucesso('Senha alterada', 'Use a nova senha no próximo login.');
      router.replace('/inicio');
      router.refresh();
    } catch {
      toast.erro('Não foi possível alterar a senha', 'Tente de novo.');
    } finally {
      setCarregando(false);
    }
  }

  return (
    <Cartao titulo="Nova senha" variante="fita">
      <form onSubmit={enviar} noValidate className="space-y-4">
        <Campo
          rotulo="Nova senha"
          type="password"
          autoComplete="new-password"
          value={senha}
          onChange={(e) => setSenha(e.target.value)}
          erro={erros.senha}
          dica="Mínimo de 8 caracteres."
        />
        <Campo
          rotulo="Confirmar nova senha"
          type="password"
          autoComplete="new-password"
          value={confirmar}
          onChange={(e) => setConfirmar(e.target.value)}
          erro={erros.confirmar}
        />
        {erros.geral && (
          <p role="alert" className="text-sm text-acento-vermelho">
            {erros.geral}
          </p>
        )}
        <Botao type="submit" carregando={carregando} className="w-full">
          Salvar nova senha
        </Botao>
      </form>
    </Cartao>
  );
}
