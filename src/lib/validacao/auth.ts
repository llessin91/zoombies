import { z } from 'zod';

export const emailSchema = z.string().trim().toLowerCase().email('Informe um e-mail válido.');

export const senhaSchema = z
  .string()
  .min(8, 'A senha precisa ter pelo menos 8 caracteres.')
  .max(72, 'A senha pode ter no máximo 72 caracteres.');

export const nomeSobreviventeSchema = z
  .string()
  .trim()
  .min(3, 'O nome precisa ter de 3 a 20 caracteres.')
  .max(20, 'O nome precisa ter de 3 a 20 caracteres.');

export const loginSchema = z.object({
  email: emailSchema,
  senha: z.string().min(1, 'Informe a senha.'),
});

export const somenteEmailSchema = z.object({ email: emailSchema });

export const cadastroSchema = z
  .object({
    nome: nomeSobreviventeSchema,
    email: emailSchema,
    senha: senhaSchema,
    confirmar: z.string(),
    aceitou: z.boolean().refine((v) => v === true, 'Você precisa confirmar que tem 16 anos ou mais.'),
  })
  .superRefine((dados, ctx) => {
    if (dados.senha !== dados.confirmar) {
      ctx.addIssue({ code: 'custom', path: ['confirmar'], message: 'As senhas não conferem.' });
    }
  });

export const novaSenhaSchema = z
  .object({ senha: senhaSchema, confirmar: z.string() })
  .superRefine((dados, ctx) => {
    if (dados.senha !== dados.confirmar) {
      ctx.addIssue({ code: 'custom', path: ['confirmar'], message: 'As senhas não conferem.' });
    }
  });

// Junta os erros do Zod em { campo: primeira mensagem }
export function errosPorCampo(erro: z.ZodError): Record<string, string> {
  const resultado: Record<string, string> = {};
  for (const issue of erro.issues) {
    const campo = String(issue.path[0] ?? 'geral');
    if (!resultado[campo]) resultado[campo] = issue.message;
  }
  return resultado;
}
