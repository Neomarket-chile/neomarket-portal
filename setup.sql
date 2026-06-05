-- ══════════════════════════════════════════════
-- NEOMARKET PORTAL — Script de configuración
-- Ejecuta esto en Supabase > SQL Editor > New Query
-- ══════════════════════════════════════════════

-- 1. Tabla de perfiles de usuario
CREATE TABLE public.profiles (
  id    uuid REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email text NOT NULL,
  name  text NOT NULL,
  role  text NOT NULL DEFAULT 'client'
);

-- 2. Tabla de proyectos
CREATE TABLE public.projects (
  id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  client_email  text NOT NULL,
  client_name   text NOT NULL,
  project_name  text NOT NULL,
  project_type  text NOT NULL DEFAULT 'website',
  status        text NOT NULL DEFAULT 'proceso',
  progress      integer NOT NULL DEFAULT 0,
  start_date    text,
  delivery_date text,
  stages        jsonb NOT NULL DEFAULT '{}',
  notes         text DEFAULT '',
  files         jsonb NOT NULL DEFAULT '[]',
  created_at    timestamptz DEFAULT now()
);

-- 3. Activar seguridad por fila (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects  ENABLE ROW LEVEL SECURITY;

-- 4. Políticas de seguridad para profiles
CREATE POLICY "usuarios_ven_su_perfil" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "admin_todo_profiles" ON profiles
  FOR ALL USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
  );

-- 5. Políticas de seguridad para projects
CREATE POLICY "admin_todo_projects" ON projects
  FOR ALL USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
  );

CREATE POLICY "cliente_ve_su_proyecto" ON projects
  FOR SELECT USING (
    client_email = (SELECT email FROM profiles WHERE id = auth.uid())
  );

-- 6. Trigger: crear perfil automático al registrar usuario
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'client')
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
