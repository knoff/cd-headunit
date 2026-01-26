import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react-swc'

// https://vitejs.dev/config/
export default defineConfig({
    plugins: [react()],
    base: './', // Важно для работы со статики
    build: {
        outDir: 'dist',
        emptyOutDir: true
    }
})
