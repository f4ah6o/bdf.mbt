import { createExportUI } from './export-ui.js';

const root = document.querySelector('#exports');
if (root) {
  createExportUI({
    root,
    getDocument: () => window.bdfDemo,
    getViewer: () => window.bdfDemo?.viewer,
    loadApi: async () => {
      const bridge = await import('./export.js');
      return {
        exportPdf: (base64, tagged) => JSON.parse(bridge.bdf_wasm_export_pdf(base64, tagged ? 1 : 0)),
        markdown: (base64, images) => JSON.parse(bridge.bdf_wasm_markdown(base64, images)),
        searchText: base64 => JSON.parse(bridge.bdf_wasm_search_text(base64)),
      };
    },
  });
}
