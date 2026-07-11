-- Collapse the three consumer tiers (normal/armador/gestor) into a single
-- Free/Pro model. The paid tier is 'pro'; a B2B "fleet" tier is future work.
--
-- Remap existing data: normal -> free, armador/gestor -> pro (armador/gestor
-- were the paying tiers, so their users keep paid access).

-- 1) Drop the old CHECK so the remap and the new default are accepted.
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_plan_check;

-- 2) Remap existing rows.
UPDATE profiles SET plan = 'free' WHERE plan = 'normal';
UPDATE profiles SET plan = 'pro'  WHERE plan IN ('armador', 'gestor');

-- 3) New default + constraint.
ALTER TABLE profiles ALTER COLUMN plan SET DEFAULT 'free';
ALTER TABLE profiles ADD CONSTRAINT profiles_plan_check CHECK (plan IN ('free', 'pro'));
