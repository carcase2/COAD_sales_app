-- A/S 견적서 PDF 클라우드 보관 + 메타(생성일·작성자·수정자·발송일) 컬럼

ALTER TABLE public.support_as_quotes
  ADD COLUMN IF NOT EXISTS pdf_path text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS pdf_uploaded_at timestamptz,
  ADD COLUMN IF NOT EXISTS pdf_uploaded_by text NOT NULL DEFAULT '';

COMMENT ON COLUMN public.support_as_quotes.pdf_path IS
  'storage bucket support-as-quotes 내 객체 경로';
COMMENT ON COLUMN public.support_as_quotes.pdf_uploaded_at IS
  'PDF 클라우드 업로드 시각';
COMMENT ON COLUMN public.support_as_quotes.pdf_uploaded_by IS
  'PDF를 클라우드에 올린 사람(최종작성자)';
COMMENT ON COLUMN public.support_as_quotes.created_at IS
  '생성일 (수정·PDF 업로드 시 유지)';
COMMENT ON COLUMN public.support_as_quotes.created_by IS
  '최초 작성자 (수정·PDF 업로드 시 유지)';
COMMENT ON COLUMN public.support_as_quotes.updated_by IS
  '마지막 수정자';
COMMENT ON COLUMN public.support_as_quotes.sent_ymd IS
  '발송일';

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'support-as-quotes',
  'support-as-quotes',
  true,
  20971520,
  ARRAY['application/pdf']::text[]
)
ON CONFLICT (id) DO UPDATE
SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS support_as_quotes_storage_all ON storage.objects;
CREATE POLICY support_as_quotes_storage_all
  ON storage.objects
  FOR ALL
  USING (bucket_id = 'support-as-quotes')
  WITH CHECK (bucket_id = 'support-as-quotes');
