import { defineConfig } from 'vite'
import { resolve } from 'node:path'

export default defineConfig({
  base: './',
  build: {
    outDir: resolve(import.meta.dirname, '../BundledEditor'),
    emptyOutDir: true,
    sourcemap: true,
    target: 'safari17',
  },
})
