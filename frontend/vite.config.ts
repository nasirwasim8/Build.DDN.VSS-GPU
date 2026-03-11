import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

const backendProxy = {
  '/api': {
    target: 'http://localhost:8001',
    changeOrigin: true,
  },
  '/health': {
    target: 'http://localhost:8001',
    changeOrigin: true,
  },
  '/metrics': {
    target: 'http://localhost:8001',
    changeOrigin: true,
  },
}

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: backendProxy,
  },
  // preview.proxy enables the same proxying for `vite preview` (production static serving)
  // Without this, /api calls in production go to port 5175 (frontend) and get HTML back
  preview: {
    port: 5175,
    proxy: backendProxy,
  },
})
