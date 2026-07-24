import { createSignal } from 'solid-js';

// Defect: the setup body runs once per instance — including during the server
// render. Should be a warning, not a hard failure: it is wrong here, but the
// same shape is legitimate inside a client:only island.
export default function Broken() {
  const stored = localStorage.getItem('theme');
  const [theme] = createSignal(stored ?? 'light');
  return <span>{theme()}</span>;
}
