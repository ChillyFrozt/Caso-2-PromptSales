require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');
const { MongoClient } = require('mongodb');
const axios = require('axios');

const app = express(); app.use(express.json());
const pg = new Pool({ connectionString: process.env.PG_URL });
let mongoDb;
(async () => { mongoDb = (await new MongoClient(process.env.MONGO_URL).connect()).db('promptcontent'); })();

app.post('/tools/getContent', async (req,res)=>{
  try{
    const { query_text, limit=10 } = req.body;
    if(!query_text) return res.status(400).json({error:'query_text required'});
    const embResp = await axios.post(
      'https://api-inference.huggingface.co/pipeline/feature-extraction/sentence-transformers/all-MiniLM-L6-v2',
      query_text,
      { headers: { Authorization: `Bearer ${process.env.HF_TOKEN}` } }
    );
    const q='SELECT content_id,title,hashtags FROM content_vectors ORDER BY embedding <=> $1 LIMIT $2';
    const r=await pg.query(q,[embResp.data, limit]);
    res.json({items:r.rows});
  }catch(e){ res.status(500).json({error:e.message}); }
});

app.post('/tools/generateAudienceMessages', async (req,res)=>{
  try{
    const { tenant_id, campaign_description, audiences, n_messages=3 } = req.body;
    if(!campaign_description || !Array.isArray(audiences)) return res.status(400).json({error:'campaign_description and audiences[] required'});
    const logs = audiences.map(a=>({audience:a.name, messages:Array.from({length:n_messages},(_,i)=>`[${a.name}] ${campaign_description} — Mensaje ${i+1}: CTA compra ahora`)}));
    await mongoDb.collection('prompt_logs').insertOne({tenant_id, tool:'generateAudienceMessages', request:{campaign_description,audiences,n_messages}, response:{logs}, created_at:new Date()});
    res.json({logs});
  }catch(e){ res.status(500).json({error:e.message}); }
});

app.get('/health',(_,res)=>res.json({ok:true}));
app.listen(process.env.PORT||3000, ()=>console.log('MCP server on :3000'));
