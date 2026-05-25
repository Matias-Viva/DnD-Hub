import { useState, useEffect } from 'react'

const API_URL = import.meta.env.VITE_API_URL || ''
console.log('API_URL:', import.meta.env.VITE_API_URL)

function App() {
  const [status, setStatus] = useState(null)

  useEffect(() => {
    fetch(`${API_URL}/api/health`)
      .then(res => res.json())
      .then(data => setStatus(data.status))
      .catch(() => setStatus('error'))
  }, [])

  return (
    <div>
      <h1>DnD Hub</h1>
      <p>Backend status: {status ?? 'checking...'}</p>
    </div>
  )
}

export default App