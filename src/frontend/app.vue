<template>
  <div id="app">
    <header class="header">
      <h1>📝 TODO App</h1>
      <p>GKE Learning Project</p>
    </header>
    
    <main class="container">
      <div class="todo-form">
        <h2>Add New TODO</h2>
        <input 
          v-model="newTodo.title" 
          type="text" 
          placeholder="Todo title..."
          @keyup.enter="addTodo"
          class="input"
        />
        <textarea 
          v-model="newTodo.description" 
          placeholder="Description (optional)..."
          class="textarea"
        ></textarea>
        <button @click="addTodo" class="btn btn-primary">Add TODO</button>
      </div>

      <div class="todo-list">
        <h2>TODO List ({{ todos.length }})</h2>
        <div v-if="loading" class="loading">Loading...</div>
        <div v-else-if="todos.length === 0" class="empty">No todos yet. Add one above!</div>
        <div v-else>
          <div 
            v-for="todo in todos" 
            :key="todo.id" 
            class="todo-item"
            :class="{ completed: todo.completed }"
          >
            <div class="todo-content">
              <h3>{{ todo.title }}</h3>
              <p v-if="todo.description">{{ todo.description }}</p>
              <small>{{ formatDate(todo.created_at) }}</small>
            </div>
            <div class="todo-actions">
              <button 
                @click="toggleTodo(todo)" 
                class="btn btn-small"
                :class="todo.completed ? 'btn-secondary' : 'btn-success'"
              >
                {{ todo.completed ? '↩️ Undo' : '✓ Complete' }}
              </button>
              <button 
                @click="deleteTodo(todo.id)" 
                class="btn btn-small btn-danger"
              >
                🗑️ Delete
              </button>
            </div>
          </div>
        </div>
      </div>
    </main>

    <footer class="footer">
      <p>Built with Nuxt.js + FastAPI + GKE</p>
    </footer>
  </div>
</template>

<script setup lang="ts">
const config = useRuntimeConfig()
const apiBase = config.public.apiBase

interface Todo {
  id: number
  title: string
  description?: string
  completed: boolean
  created_at: string
}

const todos = ref<Todo[]>([])
const loading = ref(false)
const newTodo = ref({
  title: '',
  description: ''
})

// TODOの取得
const fetchTodos = async () => {
  loading.value = true
  try {
    const response = await fetch(`${apiBase}/api/todos`)
    todos.value = await response.json()
  } catch (error) {
    console.error('Failed to fetch todos:', error)
    alert('Failed to load todos')
  } finally {
    loading.value = false
  }
}

// TODOの追加
const addTodo = async () => {
  if (!newTodo.value.title.trim()) {
    alert('Please enter a title')
    return
  }

  try {
    const response = await fetch(`${apiBase}/api/todos`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(newTodo.value)
    })
    
    if (response.ok) {
      newTodo.value = { title: '', description: '' }
      await fetchTodos()
    }
  } catch (error) {
    console.error('Failed to add todo:', error)
    alert('Failed to add todo')
  }
}

// TODOの完了/未完了切り替え
const toggleTodo = async (todo: Todo) => {
  try {
    const response = await fetch(`${apiBase}/api/todos/${todo.id}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        ...todo,
        completed: !todo.completed
      })
    })
    
    if (response.ok) {
      await fetchTodos()
    }
  } catch (error) {
    console.error('Failed to update todo:', error)
    alert('Failed to update todo')
  }
}

// TODOの削除
const deleteTodo = async (id: number) => {
  if (!confirm('Are you sure you want to delete this todo?')) {
    return
  }

  try {
    const response = await fetch(`${apiBase}/api/todos/${id}`, {
      method: 'DELETE'
    })
    
    if (response.ok) {
      await fetchTodos()
    }
  } catch (error) {
    console.error('Failed to delete todo:', error)
    alert('Failed to delete todo')
  }
}

// 日付のフォーマット
const formatDate = (dateString: string) => {
  const date = new Date(dateString)
  return date.toLocaleString('ja-JP')
}

// 初期ロード
onMounted(() => {
  fetchTodos()
})
</script>

<style scoped>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

#app {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.header {
  background: rgba(255, 255, 255, 0.95);
  padding: 2rem;
  text-align: center;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
}

.header h1 {
  font-size: 2.5rem;
  color: #333;
  margin-bottom: 0.5rem;
}

.header p {
  color: #666;
  font-size: 1rem;
}

.container {
  flex: 1;
  max-width: 800px;
  width: 100%;
  margin: 2rem auto;
  padding: 0 1rem;
}

.todo-form {
  background: white;
  padding: 2rem;
  border-radius: 12px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);
  margin-bottom: 2rem;
}

.todo-form h2 {
  margin-bottom: 1rem;
  color: #333;
}

.input, .textarea {
  width: 100%;
  padding: 0.75rem;
  margin-bottom: 1rem;
  border: 2px solid #e0e0e0;
  border-radius: 8px;
  font-size: 1rem;
  transition: border-color 0.3s;
}

.input:focus, .textarea:focus {
  outline: none;
  border-color: #667eea;
}

.textarea {
  min-height: 80px;
  resize: vertical;
  font-family: inherit;
}

.btn {
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: 8px;
  font-size: 1rem;
  cursor: pointer;
  transition: all 0.3s;
  font-weight: 600;
}

.btn-primary {
  background: #667eea;
  color: white;
  width: 100%;
}

.btn-primary:hover {
  background: #5568d3;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
}

.btn-small {
  padding: 0.5rem 1rem;
  font-size: 0.875rem;
}

.btn-success {
  background: #48bb78;
  color: white;
}

.btn-success:hover {
  background: #38a169;
}

.btn-secondary {
  background: #718096;
  color: white;
}

.btn-secondary:hover {
  background: #4a5568;
}

.btn-danger {
  background: #f56565;
  color: white;
}

.btn-danger:hover {
  background: #e53e3e;
}

.todo-list {
  background: white;
  padding: 2rem;
  border-radius: 12px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);
}

.todo-list h2 {
  margin-bottom: 1.5rem;
  color: #333;
}

.loading, .empty {
  text-align: center;
  padding: 2rem;
  color: #666;
  font-style: italic;
}

.todo-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem;
  margin-bottom: 1rem;
  background: #f7fafc;
  border-radius: 8px;
  border-left: 4px solid #667eea;
  transition: all 0.3s;
}

.todo-item:hover {
  transform: translateX(4px);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.todo-item.completed {
  opacity: 0.6;
  border-left-color: #48bb78;
}

.todo-item.completed .todo-content h3 {
  text-decoration: line-through;
}

.todo-content {
  flex: 1;
}

.todo-content h3 {
  font-size: 1.25rem;
  margin-bottom: 0.5rem;
  color: #2d3748;
}

.todo-content p {
  color: #4a5568;
  margin-bottom: 0.5rem;
}

.todo-content small {
  color: #a0aec0;
  font-size: 0.875rem;
}

.todo-actions {
  display: flex;
  gap: 0.5rem;
}

.footer {
  background: rgba(255, 255, 255, 0.95);
  padding: 1.5rem;
  text-align: center;
  color: #666;
  font-size: 0.875rem;
}

@media (max-width: 768px) {
  .todo-item {
    flex-direction: column;
    gap: 1rem;
  }

  .todo-actions {
    width: 100%;
  }

  .btn-small {
    flex: 1;
  }
}
</style>

