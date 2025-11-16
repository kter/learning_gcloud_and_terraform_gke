"""
Simple TODO API using FastAPI
学習用のサンプルコード
"""
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import os

app = FastAPI(title="TODO API", version="1.0.0")

# CORS設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 本番環境では適切に設定すること
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# データモデル
class TodoBase(BaseModel):
    title: str
    description: Optional[str] = None
    completed: bool = False

class TodoCreate(TodoBase):
    pass

class Todo(TodoBase):
    id: int
    created_at: datetime
    
    class Config:
        from_attributes = True

# インメモリストレージ（本番環境ではDBを使用）
todos_db = []
todo_id_counter = 1

@app.get("/")
async def root():
    """ヘルスチェック用エンドポイント"""
    return {
        "message": "TODO API is running",
        "version": "1.0.0",
        "environment": os.getenv("ENVIRONMENT", "development")
    }

@app.get("/api/todos", response_model=List[Todo])
async def get_todos():
    """全てのTODOを取得"""
    return todos_db

@app.get("/api/todos/{todo_id}", response_model=Todo)
async def get_todo(todo_id: int):
    """特定のTODOを取得"""
    for todo in todos_db:
        if todo["id"] == todo_id:
            return todo
    raise HTTPException(status_code=404, detail="Todo not found")

@app.post("/api/todos", response_model=Todo, status_code=201)
async def create_todo(todo: TodoCreate):
    """新しいTODOを作成"""
    global todo_id_counter
    new_todo = {
        "id": todo_id_counter,
        "title": todo.title,
        "description": todo.description,
        "completed": todo.completed,
        "created_at": datetime.now()
    }
    todos_db.append(new_todo)
    todo_id_counter += 1
    return new_todo

@app.put("/api/todos/{todo_id}", response_model=Todo)
async def update_todo(todo_id: int, todo: TodoCreate):
    """TODOを更新"""
    for i, existing_todo in enumerate(todos_db):
        if existing_todo["id"] == todo_id:
            todos_db[i].update({
                "title": todo.title,
                "description": todo.description,
                "completed": todo.completed
            })
            return todos_db[i]
    raise HTTPException(status_code=404, detail="Todo not found")

@app.delete("/api/todos/{todo_id}")
async def delete_todo(todo_id: int):
    """TODOを削除"""
    for i, todo in enumerate(todos_db):
        if todo["id"] == todo_id:
            todos_db.pop(i)
            return {"message": "Todo deleted successfully"}
    raise HTTPException(status_code=404, detail="Todo not found")

@app.get("/health")
async def health_check():
    """ヘルスチェック"""
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

