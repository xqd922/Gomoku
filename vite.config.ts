import { defineConfig } from 'vite'
import electron from 'vite-plugin-electron'
import path from 'node:path'

export default defineConfig(({ command }) => {
  const isDev = command === 'serve'
  return {
    root: '.',
    base: './',
    build: { outDir: 'dist' },
    server: { port: 5173, strictPort: true },
    plugins: [
      electron([
        { entry: 'electron/main.ts' },
        { entry: 'electron/preload.ts' },
      ]),
    ],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, 'src'),
      },
    },
  }
})
