-- Family subscription plans (billing UI only — all families start on free)
ALTER TABLE families
  ADD COLUMN IF NOT EXISTS plan_id TEXT NOT NULL DEFAULT 'free'
    CHECK (plan_id IN ('free', 'premium')),
  ADD COLUMN IF NOT EXISTS plan_status TEXT NOT NULL DEFAULT 'active'
    CHECK (plan_status IN ('active', 'cancelled', 'past_due', 'trialing')),
  ADD COLUMN IF NOT EXISTS plan_started_at TIMESTAMPTZ DEFAULT now(),
  ADD COLUMN IF NOT EXISTS plan_expires_at TIMESTAMPTZ;

UPDATE families
SET plan_id = 'free', plan_status = 'active', plan_started_at = COALESCE(plan_started_at, created_at)
WHERE plan_id IS NULL OR plan_status IS NULL;

-- Analyze family activity and return an overall health score (0–100) with insights
CREATE OR REPLACE FUNCTION get_family_health(p_family_id UUID)
RETURNS JSON
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_window_start TIMESTAMPTZ := now() - INTERVAL '7 days';
  v_window_end TIMESTAMPTZ := now() + INTERVAL '7 days';
  v_week_start DATE := date_trunc('week', CURRENT_DATE)::DATE;

  v_tasks_created INT := 0;
  v_tasks_completed INT := 0;
  v_tasks_overdue INT := 0;
  v_events_count INT := 0;
  v_announcements INT := 0;
  v_meal_filled INT := 0;
  v_meal_total INT := 0;
  v_active_members INT := 0;
  v_engaged_members INT := 0;

  v_task_score NUMERIC := 0;
  v_calendar_score NUMERIC := 0;
  v_comm_score NUMERIC := 0;
  v_meal_score NUMERIC := 0;
  v_engagement_score NUMERIC := 0;
  v_overall NUMERIC := 0;
  v_label TEXT;
  v_insights JSONB := '[]'::JSONB;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT is_family_member(p_family_id) THEN
    RAISE EXCEPTION 'Not a family member';
  END IF;

  SELECT COUNT(*) INTO v_active_members
  FROM family_members
  WHERE family_id = p_family_id AND status = 'active';

  SELECT COUNT(*) INTO v_tasks_created
  FROM tasks
  WHERE family_id = p_family_id AND created_at >= v_window_start;

  SELECT COUNT(*) INTO v_tasks_completed
  FROM tasks
  WHERE family_id = p_family_id
    AND status = 'completed'
    AND completed_at >= v_window_start;

  SELECT COUNT(*) INTO v_tasks_overdue
  FROM tasks
  WHERE family_id = p_family_id
    AND status = 'pending'
    AND due_at IS NOT NULL
    AND due_at < now();

  SELECT COUNT(*) INTO v_events_count
  FROM events
  WHERE family_id = p_family_id
    AND status = 'active'
    AND starts_at >= now()
    AND starts_at < v_window_end;

  SELECT COUNT(*) INTO v_announcements
  FROM announcements
  WHERE family_id = p_family_id AND created_at >= v_window_start;

  SELECT
    COUNT(*) FILTER (WHERE ms.meal_name IS NOT NULL AND trim(ms.meal_name) <> ''),
    COUNT(*)
  INTO v_meal_filled, v_meal_total
  FROM meal_plans mp
  JOIN meal_slots ms ON ms.meal_plan_id = mp.id
  WHERE mp.family_id = p_family_id AND mp.week_start_date = v_week_start;

  SELECT COUNT(DISTINCT user_id) INTO v_engaged_members
  FROM (
    SELECT completed_by AS user_id
    FROM tasks
    WHERE family_id = p_family_id
      AND completed_at >= v_window_start
      AND completed_by IS NOT NULL
    UNION
    SELECT created_by FROM tasks
    WHERE family_id = p_family_id AND created_at >= v_window_start
    UNION
    SELECT created_by FROM events
    WHERE family_id = p_family_id AND created_at >= v_window_start
    UNION
    SELECT author_id FROM announcements
    WHERE family_id = p_family_id AND created_at >= v_window_start
  ) engaged;

  -- Task score
  IF v_tasks_created = 0 AND v_tasks_completed = 0 THEN
    v_task_score := 55;
  ELSE
    v_task_score := LEAST(100, (v_tasks_completed::NUMERIC / GREATEST(v_tasks_created, 1)) * 100);
    v_task_score := GREATEST(0, v_task_score - (v_tasks_overdue * 8));
  END IF;

  -- Calendar score
  v_calendar_score := LEAST(100, v_events_count * 25);
  IF v_events_count = 0 THEN v_calendar_score := 35; END IF;

  -- Communication score
  v_comm_score := LEAST(100, v_announcements * 34);
  IF v_announcements = 0 THEN v_comm_score := 40; END IF;

  -- Meal planning score
  IF v_meal_total = 0 THEN
    v_meal_score := 45;
  ELSE
    v_meal_score := (v_meal_filled::NUMERIC / v_meal_total) * 100;
  END IF;

  -- Member engagement score
  IF v_active_members = 0 THEN
    v_engagement_score := 50;
  ELSE
    v_engagement_score := LEAST(100, (v_engaged_members::NUMERIC / v_active_members) * 100);
  END IF;

  v_overall := ROUND(
    v_task_score * 0.35 +
    v_calendar_score * 0.15 +
    v_comm_score * 0.15 +
    v_meal_score * 0.15 +
    v_engagement_score * 0.20
  );

  IF v_overall >= 80 THEN
    v_label := 'Thriving';
  ELSIF v_overall >= 60 THEN
    v_label := 'Healthy';
  ELSIF v_overall >= 40 THEN
    v_label := 'Fair';
  ELSE
    v_label := 'Needs attention';
  END IF;

  IF v_tasks_overdue > 0 THEN
    v_insights := v_insights || jsonb_build_array(
      format('%s overdue task%s — tackle the oldest one first.',
        v_tasks_overdue, CASE WHEN v_tasks_overdue = 1 THEN '' ELSE 's' END)
    );
  END IF;

  IF v_tasks_created > 0 AND v_tasks_completed::NUMERIC / GREATEST(v_tasks_created, 1) < 0.5 THEN
    v_insights := v_insights || jsonb_build_array(
      'Less than half of this week''s tasks are done — break big chores into smaller steps.'
    );
  END IF;

  IF v_events_count = 0 THEN
    v_insights := v_insights || jsonb_build_array(
      'No upcoming events — add a family activity to the calendar.'
    );
  END IF;

  IF v_announcements = 0 THEN
    v_insights := v_insights || jsonb_build_array(
      'No family updates this week — share a quick announcement.'
    );
  END IF;

  IF v_meal_total > 0 AND v_meal_filled::NUMERIC / v_meal_total < 0.4 THEN
    v_insights := v_insights || jsonb_build_array(
      'Meal plan is mostly empty — planning meals reduces last-minute stress.'
    );
  END IF;

  IF v_active_members > 1 AND v_engaged_members::NUMERIC / v_active_members < 0.5 THEN
    v_insights := v_insights || jsonb_build_array(
      'Several members haven''t participated this week — assign tasks to share the load.'
    );
  END IF;

  IF jsonb_array_length(v_insights) = 0 THEN
    v_insights := v_insights || jsonb_build_array(
      'Your family is staying on top of things — keep up the great coordination!'
    );
  END IF;

  RETURN json_build_object(
    'score', v_overall,
    'label', v_label,
    'period_days', 7,
    'metrics', json_build_object(
      'tasks_created', v_tasks_created,
      'tasks_completed', v_tasks_completed,
      'tasks_overdue', v_tasks_overdue,
      'upcoming_events', v_events_count,
      'announcements', v_announcements,
      'meals_planned', v_meal_filled,
      'meals_total', v_meal_total,
      'active_members', v_active_members,
      'engaged_members', v_engaged_members,
      'task_score', ROUND(v_task_score),
      'calendar_score', ROUND(v_calendar_score),
      'communication_score', ROUND(v_comm_score),
      'meal_score', ROUND(v_meal_score),
      'engagement_score', ROUND(v_engagement_score)
    ),
    'insights', v_insights
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_family_health(UUID) TO authenticated;