const root = document.querySelector('[data-benchmark-measured]');
if (root) {
  const body = root.querySelector('[data-benchmark-table] tbody');
  const meta = root.querySelector('[data-benchmark-meta]');
  const stamp = root.querySelector('[data-benchmark-stamp]');

  function formatMs(value) {
    if (value === null || value === undefined) return '—';
    const digits = value < 1 ? 2 : 1;
    return new Intl.NumberFormat('ja-JP', { maximumFractionDigits: digits, minimumFractionDigits: digits }).format(value) + ' ms';
  }

  function formatEnvironment(data) {
    const environment = data.environment ?? {};
    const methodology = data.methodology ?? {};
    const measured = data.measuredAt ? new Date(data.measuredAt) : null;
    const when = measured && !Number.isNaN(measured.getTime())
      ? measured.toLocaleString('ja-JP', { dateStyle: 'medium', timeStyle: 'short' })
      : '';
    const parts = [
      environment.browser,
      environment.cpu,
      environment.platform,
      methodology.statistic === 'median' ? '中央値 ' + (methodology.iterations ?? '?') + ' 回' : '',
      when,
    ].filter(Boolean);
    return parts.join(' · ');
  }

  function render(data) {
    if (!body) return;
    body.replaceChildren();
    for (const result of data.results ?? []) {
      const row = document.createElement('tr');
      const label = document.createElement('th');
      label.scope = 'row';
      label.textContent = result.label;
      const js = document.createElement('td');
      js.className = 'benchmark-number';
      js.textContent = formatMs(result.js);
      const wasm = document.createElement('td');
      wasm.className = 'benchmark-number';
      wasm.textContent = formatMs(result.wasm);
      const detail = document.createElement('td');
      detail.className = 'benchmark-detail';
      detail.textContent = result.detail ?? '';
      row.append(label, js, wasm, detail);
      body.append(row);
    }
    if (meta) {
      const methodology = data.methodology ?? {};
      const input = [methodology.inputBdf, methodology.inputPdf].filter(Boolean).join(' / ');
      meta.textContent = [
        formatEnvironment(data),
        input ? '入力: ' + input : '',
        data.results?.some(result => result.wasm == null) ? 'MiniSearch は JS のみ' : '',
      ].filter(Boolean).join(' · ');
    }
    if (stamp) stamp.textContent = data.environment?.browser ?? '';
  }

  fetch('./benchmarks.json', { cache: 'no-store' })
    .then(response => {
      if (!response.ok) throw new Error('HTTP ' + response.status);
      return response.json();
    })
    .then(render)
    .catch(error => {
      if (body) {
        const row = document.createElement('tr');
        const cell = document.createElement('td');
        cell.colSpan = 4;
        cell.className = 'benchmark-error';
        cell.textContent = '計測データを読み込めませんでした: ' + String(error.message ?? error);
        row.append(cell);
        body.replaceChildren(row);
      }
      if (meta) meta.textContent = '';
    });
}
