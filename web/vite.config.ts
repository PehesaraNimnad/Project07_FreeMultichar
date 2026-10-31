import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// one workspace, three free UIs: vite build --mode multichar | spawn | pause -> build/<mode>/<mode>.html
export default defineConfig(({ mode }) => ({
  plugins: [react()],
  base: './',
  build: {
    outDir: `build/${mode}`,
    emptyOutDir: true,
    assetsDir: 'assets',
    target: 'chrome87',
    cssTarget: 'chrome87',
    rollupOptions: { input: `${mode}.html` },
  },
}));
