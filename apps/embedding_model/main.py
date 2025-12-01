from fastapi import FastAPI
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer

app = FastAPI()

# Load model once at startup
model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")

class TextRequest(BaseModel):
    text: str

@app.get("/")
def root():
    return {"status": "ok"}

@app.post("/embed")
def embed(req: TextRequest):
    embedding = model.encode(req.text)

    return {
        "embedding": embedding.tolist(),
        "dim": len(embedding)
    }
