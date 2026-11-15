ALTER TABLE public.profiles
ADD COLUMN share_progress boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.get_leaderboard()
RETURNS TABLE (rank bigint, display_name text, xp integer, level text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT
    row_number() OVER (ORDER BY SUM(lp.xp_earned) DESC, p.display_name ASC) AS rank,
    p.display_name,
    SUM(lp.xp_earned)::integer AS xp,
    CASE
      WHEN SUM(lp.xp_earned) >= 1000 THEN 'Luminary'
      WHEN SUM(lp.xp_earned) >= 500 THEN 'Pathfinder'
      WHEN SUM(lp.xp_earned) >= 200 THEN 'Explorer'
      ELSE 'Newcomer'
    END AS level
  FROM public.profiles p
  JOIN public.learning_progress lp ON lp.user_id = p.user_id
  WHERE p.share_progress = true
  GROUP BY p.user_id, p.display_name
  ORDER BY SUM(lp.xp_earned) DESC, p.display_name ASC
  LIMIT 50;
$$;
REVOKE ALL ON FUNCTION public.get_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_leaderboard() TO anon, authenticated;
REVOKE ALL ON FUNCTION public.has_role(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, text) TO authenticated;