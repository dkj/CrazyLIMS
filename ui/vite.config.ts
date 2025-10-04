import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

const browserBase = process.env.VITE_POSTGREST_BROWSER_BASE ?? "/api";
const proxyTarget =
  process.env.VITE_POSTGREST_SERVER_TARGET ??
  process.env.VITE_POSTGREST_URL ??
  "http://localhost:3000";

export default defineConfig({
  plugins: [react()],
  server: {
    host: "0.0.0.0",
    port: 5173,
    proxy: {
      "/api": {
        target: proxyTarget,
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, "")
      }
    }
  },
  define: {
    __POSTGREST_URL__: JSON.stringify(browserBase)
  }
});
