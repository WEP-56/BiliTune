import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  base: './', // Electron file:// needs relative paths
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
      '@bilitune/shared': path.resolve(__dirname, '../../packages/shared/src'),
      '@bilitune/api': path.resolve(__dirname, '../../packages/api/src'),
      '@bilitune/store': path.resolve(__dirname, '../../packages/store/src'),
    },
  },
  server: {
    port: 3000,
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
});
