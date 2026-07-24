import { createSignal, onMount } from 'solid-js';

type Theme = 'light' | 'dark';

// Correct: every browser global is reached from onMount or an event handler,
// so none of it runs during SSR. The audit must stay silent on this file.
export default function ThemeToggle() {
  const [theme, setTheme] = createSignal<Theme>('light');

  onMount(() => {
    setTheme((document.documentElement.dataset.theme as Theme) ?? 'light');
  });

  const toggle = () => {
    const next: Theme = theme() === 'dark' ? 'light' : 'dark';
    document.documentElement.dataset.theme = next;
    localStorage.setItem('theme', next);
    setTheme(next);
  };

  return <button onClick={toggle}>{theme()}</button>;
}
