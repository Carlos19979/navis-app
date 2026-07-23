-- Fix: the profiles.plan CHECK constraint was left allowing only ('free','pro')
-- by migration 00027, but the three-tier subscription work (PR #57) added a
-- 'plus' tier in code (domain.Plan / profile.go). Any attempt to write
-- plan='plus' — e.g. the RevenueCat webhook granting the Plus entitlement or the
-- dev plan switcher — would violate the old constraint and fail.
--
-- This realigns the DB with the domain model: free / plus / pro. The future B2B
-- 'fleet' tier will be added to this constraint together with the Fleet work.

ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_plan_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_plan_check
  CHECK (plan IN ('free', 'plus', 'pro'));
