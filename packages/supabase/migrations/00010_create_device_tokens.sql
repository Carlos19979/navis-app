-- Device tokens for push notifications (FCM).
CREATE TABLE device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE device_tokens ADD CONSTRAINT uq_device_tokens_token UNIQUE (token);

CREATE INDEX idx_device_tokens_user_id ON device_tokens (user_id);

-- RLS
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY device_tokens_select ON device_tokens
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY device_tokens_insert ON device_tokens
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY device_tokens_delete ON device_tokens
  FOR DELETE USING (auth.uid() = user_id);

-- Service role can read all tokens (for cron job).
CREATE POLICY device_tokens_service_select ON device_tokens
  FOR SELECT TO service_role USING (true);
