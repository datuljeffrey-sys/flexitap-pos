-- =============================================================================
-- Migration: Add optional recaptcha_token column to tickets table
-- Version: 20261107000001
-- =============================================================================

ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS recaptcha_token TEXT;
COMMENT ON COLUMN public.tickets.recaptcha_token IS 'Optional Google reCAPTCHA v2 verification token submitted with the support ticket';
