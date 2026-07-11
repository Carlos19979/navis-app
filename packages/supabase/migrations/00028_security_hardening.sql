-- Security hardening before launch:
--   1. sent_notifications was created without RLS — any authenticated user
--      could read every user's notification dedup log through PostgREST.
--   2. The documents bucket was public: document scans (insurance policies,
--      medical certificates — PII) were fetchable by anyone with the URL.
--      Reads now require a signed URL or an authenticated request under RLS.
--      Boat photos stay public by design (non-sensitive, cached by the app).

-- 1. Row Level Security on sent_notifications ------------------------------

ALTER TABLE sent_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sent_notifications_read_own"
  ON sent_notifications FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Writes happen only through the API's direct Postgres connection (bypasses
-- RLS); no INSERT/UPDATE/DELETE policies are granted to clients on purpose.

-- 2. Private documents bucket ----------------------------------------------

UPDATE storage.buckets SET public = false WHERE id = 'documents';

-- The owner keeps full access via the per-folder policies from 00011. Crew /
-- co-owners can read a boat's document scans through the API today, so they
-- also need SELECT on the underlying objects to mint/use signed URLs.
-- Scan paths are {ownerId}/{documentId}/scan.{ext}; invoice attachments
-- ({ownerId}/invoices/...) stay owner-only.
--
-- documents/boat_members have owner-scoped RLS, so the membership check runs
-- in a SECURITY DEFINER function (executes as the table owner, bypassing RLS)
-- while auth.uid() still resolves to the caller.
CREATE OR REPLACE FUNCTION public.can_read_document_scan(owner_id text, document_id text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM documents d
    JOIN boat_members bm ON bm.boat_id = d.boat_id
    WHERE d.user_id::text = owner_id
      AND d.id::text = document_id
      AND bm.user_id = auth.uid()
  );
$$;

REVOKE ALL ON FUNCTION public.can_read_document_scan(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.can_read_document_scan(text, text) TO authenticated;

CREATE POLICY "Boat members can view shared document scans"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'documents'
    AND array_length(storage.foldername(name), 1) >= 2
    AND public.can_read_document_scan(
      (storage.foldername(name))[1],
      (storage.foldername(name))[2]
    )
  );
