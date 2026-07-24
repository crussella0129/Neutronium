import { useState } from 'react';

export default function Bad() {
  const [n] = useState(0);
  return <span>{n}</span>;
}
