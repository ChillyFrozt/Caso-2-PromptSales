
# Entregable 2 — Guía Paso a Paso (sin ETL ni Kubernetes)

Esta guía te lleva **desde cero** para montar y demostrar los POC del Entregable 2, en tu máquina local, **sin** ETL ni Kubernetes:

1) **PromptContent** → MongoDB + **pgvector** (PostgreSQL) + **MCP server** (Node.js) con 2 tools:
   - `getContent`: búsqueda semántica por embeddings
   - `generateAudienceMessages`: guarda bitácora en Mongo y devuelve 3 mensajes por audiencia
2) **PromptCrm** → **Linked Server** a PromptAds (SQL Server) + **cifrado X.509** de PII
3) **Rendimiento** → vista y **vista indexada** con comparación de planes
4) **Concurrencia** → deadlock en cascada, dirty read y lost update (con fixes)

---

## 0) Requisitos

- **SQL Server Developer** + **SSMS** (o Azure Data Studio)
- **PostgreSQL 15+** con extensión **`vector` (pgvector)**
- **MongoDB Community**
- **Node.js 18+**
- **Python 3.10+** y `pip`
- Haber corrido el **Entregable 1** (DDL). Para **PromptAds**, usa el archivo corregido que define la PK de `PerformanceDaily` como `([date], perf_id)`.

> Si no tienes pgvector: en Postgres como superusuario ejecuta `CREATE EXTENSION vector;`.

---

## 1) Descarga / estructura de carpetas

Descarga esta carpeta y conserva esta estructura:

```
promptsales-d2/
  mcp-server/
    index.js
    package.json
    .env.example
  pc_seed/
    seed_promptcontent_and_vectors.py
    requirements.txt
  sql/
    pgvector_tables.sql
    linked_server_promptcrm_to_promptads.sql
    encryption_x509_promptcrm.sql
    views_indexed_promptcrm.sql
    concurrency_demos.sql
  README_Guia_Entregable2.md
```

Si estás usando los archivos ligados a esta conversación, descárgalos desde el chat y colócalos con los mismos nombres.

---

## 2) PostgreSQL — crear tabla `content_vectors` (pgvector)

1. Crea la BD **promptsales** (si no existe):
   ```sql
   CREATE DATABASE promptsales;
   ```

2. En **promptsales**, ejecuta el script:
   - Archivo: `sql/pgvector_tables.sql`
   - Contenido clave:
     ```sql
     CREATE EXTENSION IF NOT EXISTS vector;

     CREATE TABLE IF NOT EXISTS content_vectors(
       content_id uuid PRIMARY KEY,
       title text NOT NULL,
       hashtags text[] NOT NULL,
       embedding vector(384) NOT NULL
     );

     CREATE INDEX IF NOT EXISTS idx_content_vectors_embedding
       ON content_vectors USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
     ```

> **Tip**: tras el primer `INSERT`, Postgres podría sugerir `ANALYZE` para mejorar el ANN. Basta con ejecutar `ANALYZE content_vectors;`.

---

## 3) MongoDB — no requiere preparación

El script de **seed** creará la BD `promptcontent` y las colecciones necesarias.

---

## 4) Sembrar 100 contenidos y sus embeddings

1. Instala dependencias:
   ```bash
   cd pc_seed
   pip install -r requirements.txt
   ```

2. Ejecuta el seed (usa Mongo y Postgres locales):
   ```bash
   python seed_promptcontent_and_vectors.py \
     --mongo "mongodb://localhost:27017" \
     --pg "postgres://postgres:postgres@localhost:5432/promptsales"
   ```

El script:
- Inserta ~100 documentos **approved** en `promptcontent.contents`
- Genera embeddings con `sentence-transformers/all-MiniLM-L6-v2`
- Inserta los vectores en `promptsales.public.content_vectors`

**Verificación rápida**

- En **Mongo**:
  ```js
  use promptcontent
  db.contents.countDocuments()
  db.contents.findOne({}, {title:1, hashtags:1, created_at:1})
  ```
- En **Postgres** (psql):
  ```sql
  SELECT count(*) FROM content_vectors;
  SELECT title, hashtags FROM content_vectors LIMIT 3;
  ```

> Si `psycopg2-binary` no instala en Windows, instala Visual C++ Build Tools o usa WSL. En Linux puedes necesitar `libpq-dev`/`python3-dev`.

---

## 5) MCP server (Node.js) con 2 tools

1. Crea el archivo `.env` a partir de `.env.example`:
   ```bash
   cd ../mcp-server
   cp .env.example .env
   ```

2. Edita `.env`:
   ```env
   PG_URL=postgres://postgres:postgres@localhost:5432/promptsales
   MONGO_URL=mongodb://localhost:27017
   HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx   # Token de Hugging Face (read)
   ```

3. Instala y arranca:
   ```bash
   npm install
   npm start
   ```

4. Pruebas (en otra terminal):
   ```bash
   # getContent: devuelve los items más similares por embedding
   curl -s -X POST http://localhost:3000/tools/getContent -H "content-type: application/json" \
     -d '{"tenant_id":"00000000-0000-0000-0000-000000000001","query_text":"campaña retail invierno descuento","limit":5}' | jq

   # generateAudienceMessages: guarda log en Mongo y devuelve 3 mensajes/audiencia
   curl -s -X POST http://localhost:3000/tools/generateAudienceMessages -H "content-type: application/json" \
     -d '{"tenant_id":"00000000-0000-0000-0000-000000000001","campaign_description":"Ofertas invierno 30%","audiences":[{"name":"B2C jóvenes"},{"name":"B2B retail"}],"n_messages":3}' | jq

   # health
   curl -s http://localhost:3000/health
   ```

5. Verifica que se registró el log en Mongo:
   ```js
   use promptcontent
   db.prompt_logs.find().sort({created_at:-1}).limit(1)
   ```

**Posibles errores**

- `401 Unauthorized` en Hugging Face: revisa `HF_TOKEN`
- `connection refused` a PG o Mongo: revisa `PG_URL` / `MONGO_URL`
- `vector` no existe: ejecuta `CREATE EXTENSION vector;`

---

## 6) SQL Server — Linked Server (PromptCrm → PromptAds)

1. En **SSMS**, conéctate a la instancia que tiene la BD **PromptCrm**.
2. Ejecuta `sql/linked_server_promptcrm_to_promptads.sql` y **ajusta**:
   - `@datasrc = N'SRV_ADS'` → nombre/instancia real del servidor PromptAds
   - Credenciales en `sp_addlinkedsrvlogin` o usa `@useself='TRUE'` (Kerberos/SSPI)
3. Prueba:
   ```sql
   SELECT TOP 5 name, status
   FROM PROMPTADS.PromptAds.dbo.Campaign;
   ```

**Troubleshooting**

- *Cannot obtain a connection*: proveedor incorrecto. Usa `MSOLEDBSQL` si `SQLNCLI` no está.
- *Login failed*: revisa `sp_addlinkedsrvlogin` y permisos en la BD remota.
- *Ad Hoc Distributed Queries disabled*: no aplica aquí (usamos Linked Server).

---

## 7) SQL Server — Cifrado X.509 de PII

1. En **master** y **PromptCrm** ejecuta `sql/encryption_x509_promptcrm.sql`:
   - Crea **MASTER KEY** y **CERTIFICATE** (master)
   - Crea **SYMMETRIC KEY** (PromptCrm)
   - Agrega `email_enc`/`phone_enc` y cifra datos
   - Muestra lectura con `DecryptByKey(...)`

2. Demostración de restore sin certificado:
   - Haz **backup** de PromptCrm
   - Restaura en otro servidor *sin* el certificado
   - Consulta `DecryptByKey(email_enc)` ⇒ **NULL** (no se puede descifrar)

> Si ya tenías MasterKey/Cert, el script lo respeta; ajusta contraseñas a tu política.

---

## 8) SQL Server — Rendimiento con vista indexada

1. Ejecuta `sql/views_indexed_promptcrm.sql` en **PromptCrm**. Crea:
   - `v_PurchaseAgg` (agregada)
   - `v_PurchaseAgg_IV` (**indexada** con `UNIQUE CLUSTERED`)

2. Compara:
   ```sql
   -- sin vista
   SET STATISTICS IO, TIME ON;
   SELECT campaign_id_ext, COUNT(*) FROM dbo.Purchase GROUP BY campaign_id_ext;

   -- con vista indexada
   SELECT campaign_id_ext, SUM(orders) FROM dbo.v_PurchaseAgg_IV GROUP BY campaign_id_ext;
   SET STATISTICS IO, TIME OFF;
   ```

Observa **menos lecturas lógicas** y menor tiempo al usar la vista indexada.

---

## 9) SQL Server — Concurrencia (deadlock / dirty read / lost update)

1. Ejecuta `sql/concurrency_demos.sql` para crear `dbo.Stock` y procs.
2. Abre **tres** ventanas en SSMS y corre los bloques de **Sesión 1/2/3** para provocar el **deadlock**.
3. **Fix**: ordena siempre actualizaciones por clave (A→B→C) o usa `sp_getapplock`.
4. **Dirty read**: muestra lectura sucia con `READ UNCOMMITTED`; **fix** con `READ_COMMITTED_SNAPSHOT ON`.
5. **Lost update**: compara `usp_add_qty_vulnerable` vs `usp_add_qty_safe` (usa `UPDLOCK` y operación atómica).

---

## 10) Qué evidencias entregar

- **PromptContent**: terminal de `curl` a `/tools/getContent` y `/tools/generateAudienceMessages` + screenshot de `prompt_logs` en Mongo
- **Linked Server**: screenshot del `SELECT` exitoso a `PROMPTADS.PromptAds.dbo.Campaign`
- **Cifrado**: `DecryptByKey(...)` mostrando datos en claro; nota de restore sin cert (NULL)
- **Rendimiento**: capturas de los **Execution Plans** y de `STATISTICS IO/TIME`
- **Concurrencia**: captura del **deadlock** y de la salida tras aplicar el **fix**

---

## 11) Errores comunes y soluciones

- **PK en tabla particionada** (PromptAds): la PK/índice **único** debe incluir la columna de partición (`[date]`). Usa el script corregido.
- **pgvector**: si falla `ivfflat`, ejecuta `ANALYZE content_vectors;`. La primera búsqueda puede ser más lenta sin estadísticas.
- **Hugging Face 401**: renueva `HF_TOKEN` con permiso *read*.
- **psycopg2 build**: instala `libpq-dev`/`python3-dev` (Linux) o Build Tools (Windows). Alternativa: WSL.

---

## 12) Apéndice — Comandos útiles

- **Postgres**:
  ```sql
  SELECT * FROM content_vectors ORDER BY embedding <=> '[0,0,...]' LIMIT 1; -- ejemplo si tienes un vector literal
  ```
- **Mongo**:
  ```js
  db.prompt_logs.find({tool:'generateAudienceMessages'}).sort({created_at:-1}).limit(3)
  ```
- **Node**:
  ```bash
  curl -s http://localhost:3000/health
  ```

---

**Listo.** Con esto tienes todo para correr el POC completo del Entregable 2 en local, sin ETL ni Kubernetes.
