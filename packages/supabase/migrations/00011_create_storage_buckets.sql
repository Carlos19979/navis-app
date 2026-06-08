-- Create storage buckets for boat photos and document scans.
-- Buckets are public so the app can render images via getPublicUrl + cached
-- network images. Writes remain protected by the per-user RLS policies below
-- (uploads/updates/deletes scoped to the owner's {userId}/... folder).
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('boats', 'boats', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('documents', 'documents', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

-- RLS policies for boats bucket: users can only access their own files
-- Path pattern: {userId}/{boatId}/photo.jpg
CREATE POLICY "Users can upload boat photos"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'boats'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users can view own boat photos"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'boats'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users can update own boat photos"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'boats'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users can delete own boat photos"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'boats'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- RLS policies for documents bucket
-- Path pattern: {userId}/{docId}/scan.{ext}
CREATE POLICY "Users can upload document scans"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users can view own document scans"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users can update own document scans"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users can delete own document scans"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
