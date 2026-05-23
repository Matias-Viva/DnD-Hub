import { useState, useEffect } from 'react'

function App() {
  const [status, setStatus] = useState(null)

  useEffect(() => {
    fetch('/api/health')
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