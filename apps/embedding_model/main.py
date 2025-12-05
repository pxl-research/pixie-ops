from fastapi import FastAPI
from FlagEmbedding import FlagAutoModel
import torch

embedding_model = FlagAutoModel.from_finetuned(
    "BAAI/bge-small-en-v1.5",
    # "BAAI/bge-m3",
    query_instruction_for_retrieval="Represent this sentence for searching relevant passages: ",
    devices="cuda:0",   # if not specified, will use all available gpus or cpu when no gpu available
)

app = FastAPI()

@app.get("/")
def root():
    return str(torch.__version__) + " " + str(torch.cuda.is_available()) + " " + torch.cuda.get_device_name(0)

@app.get("/embed")
def embed():
    query = "Hello"
    q_embedding = embedding_model.encode_queries(query)["dense_vecs"]

    return q_embedding.tolist()[:3]
