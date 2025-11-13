-- PostgreSQL: pgvector + tabla para embeddings de PromptContent
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS content_vectors(
  content_id uuid PRIMARY KEY,
  title      text        NOT NULL,
  hashtags   text[]      NOT NULL,
  embedding  vector(384) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_content_vectors_embedding
  ON content_vectors USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Recomendada tras carga inicial para mejorar el planificador
ANALYZE content_vectors;

-- Opcional (consultas ANN más rápidas, ajusta según precisión deseada):
-- SET ivfflat.probes = 10;
