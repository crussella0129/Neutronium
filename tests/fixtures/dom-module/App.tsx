import { createSignal } from 'solid-js';

// Defect: evaluated the moment the module is imported, including on the
// server. This is the unconditional SSR break — the audit must FAIL.
const initial = document.documentElement.dataset.theme ?? 'light';

export default function Broken() {
  const [theme] = createSignal(initial);
  return <span>{theme()}</span>;
}
