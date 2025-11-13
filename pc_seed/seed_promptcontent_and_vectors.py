# Inserta ~100 contenidos en Mongo y sus embeddings en Postgres (pgvector).
# Uso:
#   pip install -r requirements.txt
#   python seed_promptcontent_and_vectors.py --mongo "mongodb://localhost:27017" --pg "postgres://postgres:postgres@localhost:5432/promptsales"

import argparse, uuid, random
from datetime import datetime
from pymongo import MongoClient
import psycopg2
from sentence_transformers import SentenceTransformer

parser = argparse.ArgumentParser()
parser.add_argument('--mongo', required=True, help='URL MongoDB')
parser.add_argument('--pg', required=True, help='URL Postgres')
args = parser.parse_args()

mongo = MongoClient(args.mongo).promptcontent
pg = psycopg2.connect(args.pg)
cur = pg.cursor()

model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')

hashtags_pool = ["ai","ads","marketing","video","photo","copy","sale","retail","b2b","b2c","blackfriday","winter","summer","spring","autumn"]
domains = ["retail","saas","edu","travel","fashion","food"]
locales = ["ES","US","MX","CR","AR","CO","CL"]

docs = []
for i in range(1, 101):
    title = f"Promo {i} {'Video' if i%3==0 else 'Imagen' if i%3==1 else 'Texto'}"
    hid = random.sample(hashtags_pool, k=3)
    desc = f"{title}: campaña para {random.choice(domains)} en {random.choice(locales)}. CTA compra ahora con {random.choice(['20%','30%','40%'])} off."
    _id = str(uuid.uuid4())
    docs.append({
        "_id": _id,
        "tenant_id": "00000000-0000-0000-0000-000000000001",
        "title": title,
        "description": desc,
        "hashtags": hid,
        "formats": ["image","text"],
        "approval": {"status":"approved"},
        "created_at": datetime.utcnow()
    })

mongo.contents.insert_many(docs)

for d in docs:
    emb = model.encode(d["description"]).tolist()
    emb_text = "[" + ",".join(str(x) for x in emb) + "]"
    cur.execute(
        """INSERT INTO content_vectors(content_id,title,hashtags,embedding)
           VALUES (%s,%s,%s,%s::vector)""",
        (d["_id"], d["title"], d["hashtags"], emb_text)
    )

pg.commit()
cur.close()
pg.close()
print("Seed OK:", len(docs))
