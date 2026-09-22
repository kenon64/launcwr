/**
 * Конфигурация сборки electron-vite.
 * Три целевых бандла: main (Node), preload (мост), renderer (Chromium/React).
 */
import { resolve } from 'node:path'
import { defineConfig, externalizeDepsPlugin } from 'electron-vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  // ─── Главный процесс (Node.js) ────────────────────────────────────────────
  main: {
    plugins: [externalizeDepsPlugin()],
    resolve: {
      alias: {
        '@shared': resolve(__dirname, 'src/shared'),
        '@main': resolve(__dirname, 'src/main')
      }
    },
    build: {
      sourcemap: true,
      // Единая точка входа главного процесса
      rollupOptions: { input: resolve(__dirname, 'src/main/index.ts') }
    }
  },

  // ─── Preload-скрипт (contextBridge) ───────────────────────────────────────
  preload: {
    plugins: [externalizeDepsPlugin()],
    resolve: {
      alias: { '@shared': resolve(__dirname, 'src/shared') }
    },
    build: {
      sourcemap: true,
      rollupOptions: { input: resolve(__dirname, 'src/preload/index.ts') }
    }
  },

  // ─── Renderer (React + Vite) ──────────────────────────────────────────────
  renderer: {
    root: resolve(__dirname, 'src/renderer'),
    plugins: [react()],
    resolve: {
      alias: {
        '@shared': resolve(__dirname, 'src/shared'),
        '@renderer': resolve(__dirname, 'src/renderer/src')
      }
    },
    build: {
      // Агрессивная минификация и инлайнинг мелких ассетов
      assetsInlineLimit: 8192,
      rollupOptions: { input: resolve(__dirname, 'src/renderer/index.html') }
    }
  }
})
