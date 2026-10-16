-- 0004: cria o perfil automaticamente quando um usuário se cadastra,
-- e uma função para checar se o nome de sobrevivente está livre.

create or replace function public.criar_perfil_novo_usuario()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_nome text;
  v_aceitou boolean;
begin
  v_nome := btrim(coalesce(new.raw_user_meta_data->>'nome_sobrevivente', ''));
  v_aceitou := coalesce((new.raw_user_meta_data->>'aceitou_16_mais')::boolean, false);

  -- O servidor também valida (não confia só na tela)
  if char_length(v_nome) < 3 or char_length(v_nome) > 20 then
    raise exception 'Nome do sobrevivente inválido (3 a 20 caracteres).';
  end if;
  if not v_aceitou then
    raise exception 'É preciso confirmar que tem 16 anos ou mais.';
  end if;

  insert into public.profiles (id, nome_sobrevivente, aceitou_16_mais)
  values (new.id, v_nome, true);

  return new;
end;
$$;

drop trigger if exists ao_criar_usuario on auth.users;
create trigger ao_criar_usuario
  after insert on auth.users
  for each row execute function public.criar_perfil_novo_usuario();

-- Usada na tela de cadastro para avisar "nome já em uso" antes de criar a conta
create or replace function public.nome_disponivel(p_nome text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1 from public.profiles where lower(nome_sobrevivente) = lower(btrim(p_nome))
  );
$$;

revoke all on function public.nome_disponivel(text) from public;
grant execute on function public.nome_disponivel(text) to anon, authenticated;
