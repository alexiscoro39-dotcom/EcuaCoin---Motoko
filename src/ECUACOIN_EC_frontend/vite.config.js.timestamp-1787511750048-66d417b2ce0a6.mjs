// vite.config.js
import { fileURLToPath, URL } from "url";
import { sveltekit } from "file:///mnt/c/Users/USUARIO/ECUACOIN_EC/node_modules/@sveltejs/kit/src/exports/vite/index.js";
import { defineConfig } from "file:///mnt/c/Users/USUARIO/ECUACOIN_EC/src/ECUACOIN_EC_frontend/node_modules/vite/dist/node/index.js";
import environment from "file:///mnt/c/Users/USUARIO/ECUACOIN_EC/node_modules/vite-plugin-environment/dist/index.js";
import dotenv from "file:///mnt/c/Users/USUARIO/ECUACOIN_EC/node_modules/dotenv/lib/main.js";
var __vite_injected_original_import_meta_url = "file:///mnt/c/Users/USUARIO/ECUACOIN_EC/src/ECUACOIN_EC_frontend/vite.config.js";
dotenv.config({ path: "../../.env" });
var vite_config_default = defineConfig({
  build: {
    emptyOutDir: true
  },
  optimizeDeps: {
    esbuildOptions: {
      define: {
        global: "globalThis"
      }
    }
  },
  server: {
    proxy: {
      "/api": {
        target: "http://127.0.0.1:4943",
        changeOrigin: true
      }
    }
  },
  plugins: [
    sveltekit(),
    environment("all", { prefix: "CANISTER_" }),
    environment("all", { prefix: "DFX_" })
  ],
  resolve: {
    alias: [
      {
        find: "declarations",
        replacement: fileURLToPath(
          new URL("../declarations", __vite_injected_original_import_meta_url)
        )
      }
    ],
    dedupe: ["@dfinity/agent"]
  },
  css: {
    postcss: "./postcss.config.js"
    // Asegúrate de que Vite use tu configuración de PostCSS
  }
});
export {
  vite_config_default as default
};
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsidml0ZS5jb25maWcuanMiXSwKICAic291cmNlc0NvbnRlbnQiOiBbImNvbnN0IF9fdml0ZV9pbmplY3RlZF9vcmlnaW5hbF9kaXJuYW1lID0gXCIvbW50L2MvVXNlcnMvVVNVQVJJTy9FQ1VBQ09JTl9FQy9zcmMvRUNVQUNPSU5fRUNfZnJvbnRlbmRcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZmlsZW5hbWUgPSBcIi9tbnQvYy9Vc2Vycy9VU1VBUklPL0VDVUFDT0lOX0VDL3NyYy9FQ1VBQ09JTl9FQ19mcm9udGVuZC92aXRlLmNvbmZpZy5qc1wiO2NvbnN0IF9fdml0ZV9pbmplY3RlZF9vcmlnaW5hbF9pbXBvcnRfbWV0YV91cmwgPSBcImZpbGU6Ly8vbW50L2MvVXNlcnMvVVNVQVJJTy9FQ1VBQ09JTl9FQy9zcmMvRUNVQUNPSU5fRUNfZnJvbnRlbmQvdml0ZS5jb25maWcuanNcIjtpbXBvcnQgeyBmaWxlVVJMVG9QYXRoLCBVUkwgfSBmcm9tICd1cmwnO1xuaW1wb3J0IHsgc3ZlbHRla2l0IH0gZnJvbSAnQHN2ZWx0ZWpzL2tpdC92aXRlJztcbmltcG9ydCB7IGRlZmluZUNvbmZpZyB9IGZyb20gJ3ZpdGUnO1xuaW1wb3J0IGVudmlyb25tZW50IGZyb20gJ3ZpdGUtcGx1Z2luLWVudmlyb25tZW50JztcbmltcG9ydCBkb3RlbnYgZnJvbSAnZG90ZW52JztcblxuZG90ZW52LmNvbmZpZyh7IHBhdGg6ICcuLi8uLi8uZW52JyB9KTtcblxuZXhwb3J0IGRlZmF1bHQgZGVmaW5lQ29uZmlnKHtcbiAgYnVpbGQ6IHtcbiAgICBlbXB0eU91dERpcjogdHJ1ZSxcbiAgfSxcbiAgb3B0aW1pemVEZXBzOiB7XG4gICAgZXNidWlsZE9wdGlvbnM6IHtcbiAgICAgIGRlZmluZToge1xuICAgICAgICBnbG9iYWw6IFwiZ2xvYmFsVGhpc1wiLFxuICAgICAgfSxcbiAgICB9LFxuICB9LFxuICBzZXJ2ZXI6IHtcbiAgICBwcm94eToge1xuICAgICAgXCIvYXBpXCI6IHtcbiAgICAgICAgdGFyZ2V0OiBcImh0dHA6Ly8xMjcuMC4wLjE6NDk0M1wiLFxuICAgICAgICBjaGFuZ2VPcmlnaW46IHRydWUsXG4gICAgICB9LFxuICAgIH0sXG4gIH0sXG4gIHBsdWdpbnM6IFtcbiAgICBzdmVsdGVraXQoKSxcbiAgICBlbnZpcm9ubWVudChcImFsbFwiLCB7IHByZWZpeDogXCJDQU5JU1RFUl9cIiB9KSxcbiAgICBlbnZpcm9ubWVudChcImFsbFwiLCB7IHByZWZpeDogXCJERlhfXCIgfSksXG4gIF0sXG4gIHJlc29sdmU6IHtcbiAgICBhbGlhczogW1xuICAgICAge1xuICAgICAgICBmaW5kOiBcImRlY2xhcmF0aW9uc1wiLFxuICAgICAgICByZXBsYWNlbWVudDogZmlsZVVSTFRvUGF0aChcbiAgICAgICAgICBuZXcgVVJMKFwiLi4vZGVjbGFyYXRpb25zXCIsIGltcG9ydC5tZXRhLnVybClcbiAgICAgICAgKSxcbiAgICAgIH0sXG4gICAgXSxcbiAgICBkZWR1cGU6IFsnQGRmaW5pdHkvYWdlbnQnXSxcbiAgfSxcbiAgY3NzOiB7XG4gICAgcG9zdGNzczogJy4vcG9zdGNzcy5jb25maWcuanMnLCAvLyBBc2VnXHUwMEZBcmF0ZSBkZSBxdWUgVml0ZSB1c2UgdHUgY29uZmlndXJhY2lcdTAwRjNuIGRlIFBvc3RDU1NcbiAgfSxcbn0pOyJdLAogICJtYXBwaW5ncyI6ICI7QUFBNlYsU0FBUyxlQUFlLFdBQVc7QUFDaFksU0FBUyxpQkFBaUI7QUFDMUIsU0FBUyxvQkFBb0I7QUFDN0IsT0FBTyxpQkFBaUI7QUFDeEIsT0FBTyxZQUFZO0FBSnVNLElBQU0sMkNBQTJDO0FBTTNRLE9BQU8sT0FBTyxFQUFFLE1BQU0sYUFBYSxDQUFDO0FBRXBDLElBQU8sc0JBQVEsYUFBYTtBQUFBLEVBQzFCLE9BQU87QUFBQSxJQUNMLGFBQWE7QUFBQSxFQUNmO0FBQUEsRUFDQSxjQUFjO0FBQUEsSUFDWixnQkFBZ0I7QUFBQSxNQUNkLFFBQVE7QUFBQSxRQUNOLFFBQVE7QUFBQSxNQUNWO0FBQUEsSUFDRjtBQUFBLEVBQ0Y7QUFBQSxFQUNBLFFBQVE7QUFBQSxJQUNOLE9BQU87QUFBQSxNQUNMLFFBQVE7QUFBQSxRQUNOLFFBQVE7QUFBQSxRQUNSLGNBQWM7QUFBQSxNQUNoQjtBQUFBLElBQ0Y7QUFBQSxFQUNGO0FBQUEsRUFDQSxTQUFTO0FBQUEsSUFDUCxVQUFVO0FBQUEsSUFDVixZQUFZLE9BQU8sRUFBRSxRQUFRLFlBQVksQ0FBQztBQUFBLElBQzFDLFlBQVksT0FBTyxFQUFFLFFBQVEsT0FBTyxDQUFDO0FBQUEsRUFDdkM7QUFBQSxFQUNBLFNBQVM7QUFBQSxJQUNQLE9BQU87QUFBQSxNQUNMO0FBQUEsUUFDRSxNQUFNO0FBQUEsUUFDTixhQUFhO0FBQUEsVUFDWCxJQUFJLElBQUksbUJBQW1CLHdDQUFlO0FBQUEsUUFDNUM7QUFBQSxNQUNGO0FBQUEsSUFDRjtBQUFBLElBQ0EsUUFBUSxDQUFDLGdCQUFnQjtBQUFBLEVBQzNCO0FBQUEsRUFDQSxLQUFLO0FBQUEsSUFDSCxTQUFTO0FBQUE7QUFBQSxFQUNYO0FBQ0YsQ0FBQzsiLAogICJuYW1lcyI6IFtdCn0K
