CREATE TABLE public.profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text NOT NULL DEFAULT 'Learner',
  avatar_url text,
  preferred_language text NOT NULL DEFAULT 'en',
  interests text[] NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Learners can view their own profile" ON public.profiles FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "Learners can update their own profile" ON public.profiles FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE TABLE public.user_roles (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('admin', 'learner')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, role)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;
CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role) $$;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, text) TO authenticated;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Learners can view their own roles" ON public.user_roles FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "Admins can manage roles" ON public.user_roles FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE TABLE public.courses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  title text NOT NULL,
  description text NOT NULL,
  category text NOT NULL,
  level text NOT NULL DEFAULT 'Beginner',
  duration_minutes integer NOT NULL DEFAULT 20,
  xp_reward integer NOT NULL DEFAULT 100,
  cover_key text NOT NULL DEFAULT 'science',
  published boolean NOT NULL DEFAULT true,
  lessons jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.courses TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.courses TO authenticated;
GRANT ALL ON public.courses TO service_role;
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can browse published courses" ON public.courses FOR SELECT TO anon, authenticated USING (published = true OR public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins can create courses" ON public.courses FOR INSERT TO authenticated WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins can edit courses" ON public.courses FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins can delete courses" ON public.courses FOR DELETE TO authenticated USING (public.has_role(auth.uid(), 'admin'));

INSERT INTO public.courses (slug, title, description, category, level, duration_minutes, xp_reward, cover_key, lessons) VALUES
('cosmic-chemistry', 'The chemistry of stars', 'Follow the elements forged in stellar fire, from hydrogen to the matter in your hands.', 'Science', 'Beginner', 24, 120, 'science', '[{"title":"A universe of hydrogen","duration":"6 min"},{"title":"Inside a star","duration":"8 min"},{"title":"Elements that travel","duration":"10 min"}]'::jsonb),
('build-a-neural-net', 'Build a tiny neural net', 'Make a small learning machine and see how patterns emerge from examples.', 'AI', 'Beginner', 32, 160, 'ai', '[{"title":"Patterns and predictions","duration":"8 min"},{"title":"Teach a tiny model","duration":"12 min"},{"title":"Test your network","duration":"12 min"}]'::jsonb),
('creative-coding', 'Creative code: living lines', 'Turn simple rules into an ever-changing generative artwork.', 'Coding', 'Beginner', 28, 140, 'coding', '[{"title":"Coordinates in motion","duration":"7 min"},{"title":"Loops that grow","duration":"10 min"},{"title":"Make it yours","duration":"11 min"}]'::jsonb),
('money-mindset', 'Money, made meaningful', 'Build a clear foundation in saving, spending, and compound growth.', 'Finance', 'Beginner', 20, 100, 'finance', '[{"title":"Choose what matters","duration":"6 min"},{"title":"Small gains, big growth","duration":"8 min"},{"title":"Your first money map","duration":"6 min"}]'::jsonb),
('speak-through-stories', 'Language through stories', 'Learn useful phrases through a short, branching conversation.', 'Languages', 'Beginner', 18, 90, 'languages', '[{"title":"A new introduction","duration":"5 min"},{"title":"Find the right words","duration":"7 min"},{"title":"Your first conversation","duration":"6 min"}]'::jsonb),
('design-through-time', 'Ideas that changed the world', 'Explore how art, invention, and engineering reshape everyday life.', 'History', 'Intermediate', 26, 130, 'history', '[{"title":"Before the turning point","duration":"7 min"},{"title":"A new way to build","duration":"9 min"},{"title":"What comes next","duration":"10 min"}]'::jsonb);

CREATE TABLE public.learning_progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  course_slug text NOT NULL REFERENCES public.courses(slug) ON DELETE CASCADE,
  completed_lessons text[] NOT NULL DEFAULT '{}',
  quiz_score integer,
  xp_earned integer NOT NULL DEFAULT 0,
  completed_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, course_slug)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.learning_progress TO authenticated;
GRANT ALL ON public.learning_progress TO service_role;
ALTER TABLE public.learning_progress ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Learners manage their own progress" ON public.learning_progress FOR ALL TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE TABLE public.discussions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  display_name text NOT NULL,
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 2000),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.discussions TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.discussions TO authenticated;
GRANT ALL ON public.discussions TO service_role;
ALTER TABLE public.discussions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read discussions" ON public.discussions FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Members can post discussions" ON public.discussions FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "Members manage their own discussions" ON public.discussions FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY "Members can remove their own discussions" ON public.discussions FOR DELETE TO authenticated USING (user_id = auth.uid());
CREATE POLICY "Admins can remove discussions" ON public.discussions FOR DELETE TO authenticated USING (public.has_role(auth.uid(), 'admin'));

CREATE OR REPLACE FUNCTION public.create_skillverse_profile()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (user_id, display_name)
  VALUES (NEW.id, COALESCE(NULLIF(NEW.raw_user_meta_data ->> 'display_name', ''), NULLIF(split_part(NEW.email, '@', 1), ''), 'Learner'))
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;
CREATE TRIGGER on_auth_user_created_skillverse_profile
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.create_skillverse_profile();
CREATE INDEX courses_published_category_idx ON public.courses (published, category);
CREATE INDEX discussions_created_at_idx ON public.discussions (created_at DESC);
CREATE INDEX learning_progress_user_idx ON public.learning_progress (user_id);