import { useState, useEffect } from 'react'
import logo from './assets/logo.png'
import { supabase } from './services/supabase'

const API_URL = import.meta.env.VITE_API_URL || ''

const STATUS_LABEL = {
  checking: 'Connecting...',
  ok: '✅ Success',
  error: '❌ Error',
}

function App() {
  const [backendStatus, setBackendStatus] = useState('checking')
  const [dbStatus, setDbStatus] = useState('checking')
  const [backendDbStatus, setBackendDbStatus] = useState('checking')

  useEffect(() => {
    fetch(`${API_URL}/api/health`)
      .then(res => {
        if (!res.ok) throw new Error()
      })
      .then(() => setBackendStatus('ok'))
      .catch(() => setBackendStatus('error'))
  }, [])

  useEffect(() => {
    supabase
      .rpc('health_check')
      .then(({ error }) => setDbStatus(error ? 'error' : 'ok'))
  }, [])

  useEffect(() => {
    fetch(`${API_URL}/api/health/db`)
      .then(res => {
        if (!res.ok) throw new Error()
      })
      .then(() => setBackendDbStatus('ok'))
      .catch(() => setBackendDbStatus('error'))
  }, [])

  return (
    <div className="p-8">
      <img src={logo} alt="DnD Hub" />
      <p>Frontend → Backend: {STATUS_LABEL[backendStatus]}</p>
      <p>Frontend → Database: {STATUS_LABEL[dbStatus]}</p>
      <p>Backend → Database: {STATUS_LABEL[backendDbStatus]}</p>
    </div>
  )
}

export default App
