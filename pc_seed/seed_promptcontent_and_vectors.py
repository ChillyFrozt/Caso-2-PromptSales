# Seed de PromptContent en Mongo y embeddings en Postgres (pgvector)
import argparse, uuid, random
from datetime import datetime
from pymongo import MongoClient
import psycopg2
from sentence_transformers import SentenceTransformer

p=argparse.ArgumentParser()
p.add_argument('--mongo', required=True); p.add_argument('--pg', required=True)
a=p.parse_args()

mongo = MongoClient(a.mongo).promptcontent
pg = psycopg2.connect(a.pg); cur = pg.cursor()
model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')

hashtags=["ai","ads","marketing","video","photo","copy","sale","retail","b2b","b2c","blackfriday","winter","summer","spring","autumn"]
domains=["retail","saas","edu","travel","fashion","food"]; locales=["ES","US","MX","CR","AR","CO","CL"]

docs=[]
for i in range(1,101):
    title=f"Promo {i}"
    desc=f"{title}: campaña para {random.choice(domains)} en {random.choice(locales)}. CTA compra ahora con {random.choice(['20%','30%','40%'])} off."
    _id=str(uuid.uuid4())
    docs.append({"_id":_id,"tenant_id":"00000000-0000-0000-000000000001","title":title,"description":desc,"hashtags":random.sample(hashtags,3),"formats":["image","text"],"approval":{"status":"approved"},"created_at":datetime.utcnow()})
mongo.contents.insert_many(docs)

for d in docs:
    emb = model.encode(d["description"]).tolist()
    cur.execute("""INSERT INTO content_vectors(content_id,title,hashtags,embedding) VALUES (%s,%s,%s,%s)""",(d["_id"],d["title"],d["hashtags"],emb))
pg.commit(); cur.close(); pg.close()
print("Seed OK:",len(docs))
