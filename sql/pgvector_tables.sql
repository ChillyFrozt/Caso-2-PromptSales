CREATE EXTENSION IF NOT EXISTS vector;
CREATE TABLE IF NOT EXISTS content_vectors(
  content_id uuid PRIMARY KEY,
  title text NOT NULL,
  hashtags text[] NOT NULL,
  embedding vector(384) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_content_vectors_embedding
  ON content_vectors USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
