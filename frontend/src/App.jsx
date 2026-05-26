import { useState, useEffect } from 'react'
import logo from './assets/logo.png'
import { supabase } from './services/supabase'

const API_URL = import.meta.env.VITE_API_URL || ''

function App() {
  const [status, setStatus] = useState(null)
  const [sources, setSources] = useState([])

  useEffect(() => {
    fetch(`${API_URL}/api/health`)
      .then(res => res.json())
      .then(data => setStatus(data.status))
      .catch(() => setStatus('error'))
  }, [])

  useEffect(() => {
    supabase
      .from('sources')
      .select('*')
      .then(({ data, error }) => {
        if (error) console.error(error)
        else setSources(data)
      })
  }, [])

  return (
    <div className="p-8">
      <img src={logo} alt="DnD Hub" />
      <p>Backend status: {status ?? 'checking...'}</p>
      <p>Database: {sources.length > 0 ? '✅ connected' : 'checking...'}</p>
    </div>
  )
}

export default App