-- 견적서 최종 수정자 + 간단 수정 이력
ALTER TABLE public.support_as_quotes
  ADD COLUMN IF NOT EXISTS updated_by text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS edit_history jsonb NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.support_as_quotes.updated_by IS '마지막 저장한 사람';
COMMENT ON COLUMN public.support_as_quotes.edit_history IS '수정 이력 [{at,by,summary}, ...] 최근순 아님 시간순, 앱에서 상한 유지';
COMMENT ON COLUMN public.support_as_quotes.updated_at IS '마지막 저장 시각';
COMMENT ON COLUMN public.support_as_quotes.created_by IS '최초 작성자 (수정 시 유지)';
COMMENT ON COLUMN public.support_as_quotes.created_at IS '최초 작성 시각 (수정 시 유지)';
