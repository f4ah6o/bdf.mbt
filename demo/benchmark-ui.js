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

  function render(data, upstream) {
    if (!body) return;
    const upstreamResults = new Map((upstream?.results ?? []).map(result => [result.id, result]));
    body.replaceChildren();
    for (const result of data.results ?? []) {
      const row = document.createElement('tr');
      const label = document.createElement('th');
      label.scope = 'row';
      label.textContent = result.label;
      const upstreamCell = document.createElement('td');
      upstreamCell.className = 'benchmark-number';
      const upstreamResult = upstreamResults.get(result.id);
      upstreamCell.textContent = formatMs(upstreamResult?.ms);
      upstreamCell.title = upstreamResult ? '上流 BDF CLI（プロセス起動込み）' : '上流の対応する計測なし';
      const js = document.createElement('td');
      js.className = 'benchmark-number';
      js.textContent = formatMs(result.js);
      const wasm = document.createElement('td');
      wasm.className = 'benchmark-number';
      wasm.textContent = formatMs(result.wasm);
      const detail = document.createElement('td');
      detail.className = 'benchmark-detail';
      detail.textContent = result.detail ?? '';
      row.append(label, upstreamCell, js, wasm, detail);
      body.append(row);
    }
    if (meta) {
      const methodology = data.methodology ?? {};
      const input = [methodology.inputBdf, methodology.inputPdf].filter(Boolean).join(' / ');
      const upstreamEnvironment = upstream?.environment ?? {};
      meta.textContent = [
        formatEnvironment(data),
        upstreamEnvironment.go ? '上流 BDF: ' + upstreamEnvironment.go + (upstreamEnvironment.upstreamRevision ? ' (' + upstreamEnvironment.upstreamRevision + ')' : '') : '',
        input ? '入力: ' + input : '',
        data.results?.some(result => result.wasm == null) ? 'MiniSearch は JS のみ' : '',
      ].filter(Boolean).join(' · ');
    }
    if (stamp) stamp.textContent = data.environment?.browser ?? '';
  }

  Promise.all([
    fetch('./benchmarks.json', { cache: 'no-store' }).then(response => {
      if (!response.ok) throw new Error('HTTP ' + response.status);
      return response.json();
    }),
    fetch('./benchmarks-upstream.json', { cache: 'no-store' })
      .then(response => response.ok ? response.json() : null)
      .catch(() => null),
  ])
    .then(([data, upstream]) => render(data, upstream))
    .catch(error => {
      if (body) {
        const row = document.createElement('tr');
        const cell = document.createElement('td');
        cell.colSpan = 5;
        cell.className = 'benchmark-error';
        cell.textContent = '計測データを読み込めませんでした: ' + String(error.message ?? error);
        row.append(cell);
        body.replaceChildren(row);
      }
      if (meta) meta.textContent = '';
    });
}
