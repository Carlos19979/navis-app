-- Service-evidence photos on maintenance logs (impeller/anode wear, etc.).
-- Stored as an array of storage URLs; the plan gate (AttachmentLimit) is
-- enforced in the Go service, mirroring invoice attachments.
ALTER TABLE maintenance_logs
  ADD COLUMN IF NOT EXISTS photo_urls TEXT[] NOT NULL DEFAULT '{}';
