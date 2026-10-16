-- 0001: utilitários. Pode ser executado mais de uma vez sem problema.

-- Atualiza a coluna atualizado_em automaticamente em todo UPDATE
create or replace function public.definir_atualizado_em()
returns trigger
language plpgsql
as $$
begin
  new.atualizado_em := now();
  return new;
end;
$$;
