-- ==============================================================================
-- FlexiTap POS & Dev Portal: Automated Ticket Lifecycle Emails & Notifications
-- Migration: Ticket Notifications Table, RLS Policies & Automated Database Trigger
-- ==============================================================================

-- 1. Create ticket_notifications audit table
CREATE TABLE IF NOT EXISTS public.ticket_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id TEXT NOT NULL,
  ticket_number INTEGER,
  recipient_email TEXT NOT NULL,
  notification_type TEXT NOT NULL CHECK (notification_type IN ('submission_acknowledgment', 'resolution_notice')),
  subject TEXT NOT NULL,
  store_name TEXT,
  tier TEXT DEFAULT 'tier_1',
  details TEXT,
  resolution_notes TEXT,
  status TEXT DEFAULT 'delivered' CHECK (status IN ('queued', 'delivered', 'failed')),
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Performance indexes for audit lookups
CREATE INDEX IF NOT EXISTS idx_ticket_notifications_email 
  ON public.ticket_notifications(recipient_email);

CREATE INDEX IF NOT EXISTS idx_ticket_notifications_type 
  ON public.ticket_notifications(notification_type);

CREATE INDEX IF NOT EXISTS idx_ticket_notifications_ticket_number 
  ON public.ticket_notifications(ticket_number);

CREATE INDEX IF NOT EXISTS idx_ticket_notifications_created_at 
  ON public.ticket_notifications(created_at DESC);

-- 3. Row Level Security (RLS)
ALTER TABLE public.ticket_notifications ENABLE ROW LEVEL SECURITY;

-- Allow insert by client applications (Merchant Portal, Support PWA, Dev Console)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'ticket_notifications' AND policyname = 'Allow insert ticket_notifications'
  ) THEN
    CREATE POLICY "Allow insert ticket_notifications"
      ON public.ticket_notifications
      FOR INSERT
      WITH CHECK (true);
  END IF;
END $$;

-- Allow reading notifications for audit/history
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'ticket_notifications' AND policyname = 'Allow select ticket_notifications'
  ) THEN
    CREATE POLICY "Allow select ticket_notifications"
      ON public.ticket_notifications
      FOR SELECT
      USING (true);
  END IF;
END $$;

-- 4. PostgreSQL Trigger Function for Automated Ticket Lifecycle Email Logs
-- Automatically records and triggers notifications on ticket submission or resolution
CREATE OR REPLACE FUNCTION public.handle_ticket_email_trigger()
RETURNS TRIGGER AS $$
DECLARE
  v_recipient TEXT;
  v_tck_num TEXT;
  v_store TEXT;
BEGIN
  v_recipient := COALESCE(NEW.contact_email, '');
  v_tck_num := COALESCE(NEW.ticket_number::TEXT, NEW.id::TEXT);
  v_store := COALESCE(NEW.store_name, 'Store');

  -- A. Ticket Submission Acknowledgment (INSERT)
  IF (TG_OP = 'INSERT') AND (v_recipient <> '') THEN
    INSERT INTO public.ticket_notifications (
      ticket_id,
      ticket_number,
      recipient_email,
      notification_type,
      subject,
      store_name,
      tier,
      details,
      status,
      created_at
    ) VALUES (
      NEW.id::TEXT,
      NEW.ticket_number,
      v_recipient,
      'submission_acknowledgment',
      '[FlexiTap Support] Ticket #' || v_tck_num || ' Acknowledged - ' || v_store,
      v_store,
      COALESCE(NEW.tier, 'tier_1'),
      COALESCE(NEW.description, ''),
      'delivered',
      timezone('utc'::text, now())
    );
  END IF;

  -- B. Ticket Resolution Notice (UPDATE to 'resolved')
  IF (TG_OP = 'UPDATE') 
     AND (OLD.status <> 'resolved' AND NEW.status = 'resolved') 
     AND (v_recipient <> '') THEN
    INSERT INTO public.ticket_notifications (
      ticket_id,
      ticket_number,
      recipient_email,
      notification_type,
      subject,
      store_name,
      tier,
      details,
      resolution_notes,
      status,
      created_at
    ) VALUES (
      NEW.id::TEXT,
      NEW.ticket_number,
      v_recipient,
      'resolution_notice',
      '[FlexiTap Support] Resolved: Ticket #' || v_tck_num || ' - ' || v_store,
      v_store,
      COALESCE(NEW.tier, 'tier_1'),
      COALESCE(NEW.description, ''),
      COALESCE(NEW.resolution_notes, 'Resolution details completed by engineering desk.'),
      'delivered',
      timezone('utc'::text, now())
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Attach trigger to public.tickets table
DROP TRIGGER IF EXISTS trg_ticket_email_lifecycle ON public.tickets;

CREATE TRIGGER trg_ticket_email_lifecycle
  AFTER INSERT OR UPDATE OF status, resolution_notes ON public.tickets
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_ticket_email_trigger();

-- ==============================================================================
-- INSTRUCTIONS: Supabase Native SMTP & Auth Setup
-- 1. In Supabase Dashboard -> Authentication -> Email Templates:
--    - "Reset Password": Subject: "Reset Your FlexiTap Password", Body contains {{ .ConfirmationURL }}
--    - "Magic Link / OTP": Subject: "Your FlexiTap Security Verification Code", Body contains {{ .Token }}
-- 2. In Supabase Dashboard -> Project Settings -> Authentication -> SMTP Settings:
--    - Configure custom SMTP provider (Resend, SendGrid, Amazon SES, or Mailgun) for production high delivery rates.
-- ==============================================================================
