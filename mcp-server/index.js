require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');
const { MongoClient } = require('mongodb');
const axios = require('axios');

const app = express();
app.use(express.json());

const pg = new Pool({ connectionString: process.env.PG_URL });
let mongoDb;

(async () => {
  const mongoClient = await new MongoClient(process.env.MONGO_URL).connect();
  mongoDb = mongoClient.db('promptcontent');
  console.log('Mongo connected');
})().catch(err => { console.error('Mongo error', err); process.exit(1); });

// Tool 1: getContent — búsqueda vectorial (pgvector)
app.post('/tools/getContent', async (req, res) => {
  try {
    const { tenant_id, query_text, limit = 10 } = req.body;
    if (!query_text) return res.status(400).json({ error: 'query_text required' });

    // Embedding con Hugging Face Inference (POST + token)
    const embResp = await axios.post(
      'https://api-inference.huggingface.co/pipeline/feature-extraction/sentence-transformers/all-MiniLM-L6-v2',
      query_text,
      { headers: { Authorization: `Bearer ${process.env.HF_TOKEN}` } }
    );

    // Asegurar vector 1D y castear a ::vector en la consulta
    let emb = embResp.data;
    if (Array.isArray(emb) && Array.isArray(emb[0])) {
      // si viene [[...]] tomamos la primera fila (o podrías promediar)
      emb = emb[0];
    }
    const embText = `[${emb.join(',')}]`; // pgvector acepta texto '[x,y,...]'

    const q = `SELECT content_id, title, hashtags
               FROM content_vectors
               ORDER BY embedding <=> $1::vector
               LIMIT $2`;
    const r = await pg.query(q, [embText, limit]);

    res.json({
      items: r.rows.map(x => ({ content_id: x.content_id, title: x.title, hashtags: x.hashtags })),
      took_ms: 0
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message });
  }
});

// Tool 2: generateAudienceMessages — guarda bitácora en Mongo
app.post('/tools/generateAudienceMessages', async (req, res) => {
  try {
    const { tenant_id, campaign_description, audiences, n_messages = 3 } = req.body;
    if (!campaign_description || !Array.isArray(audiences)) {
      return res.status(400).json({ error: 'campaign_description and audiences[] required' });
    }
    const logs = audiences.map(a => ({
      audience: a.name,
      messages: Array.from({ length: n_messages }, (_, i) =>
        `[${a.name}] ${campaign_description} — Mensaje ${i + 1}: CTA compra ahora`)
    }));

    await mongoDb.collection('prompt_logs').insertOne({
      tenant_id,
      tool: 'generateAudienceMessages',
      request: { campaign_description, audiences, n_messages },
      response: { logs },
      status: 'ok',
      created_at: new Date()
    });

    res.json({ logs });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message });
  }
});

app.get('/health', (_, res) => res.json({ ok: true }));

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`MCP server listening on :${port}`));
