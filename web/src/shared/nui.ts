import { useEffect, useRef } from 'react';

export const isBrowser = typeof (window as unknown as { GetParentResourceName?: unknown }).GetParentResourceName !== 'function';
const resource = isBrowser ? 'free-preview' : (window as unknown as { GetParentResourceName: () => string }).GetParentResourceName();

export interface NuiMessage<T = unknown> { action: string; data: T }

/** One listener for all NUI messages; the handler always sees the latest state. */
export function useNuiMessage(handler: (m: NuiMessage) => void) {
  const ref = useRef(handler);
  ref.current = handler;
  useEffect(() => {
    const on = (e: MessageEvent) => {
      const m = e.data;
      if (m && typeof m.action === 'string') ref.current(m as NuiMessage);
    };
    window.addEventListener('message', on);
    return () => window.removeEventListener('message', on);
  }, []);
}

/** Keyboard handler that always sees the latest state. */
export function useKeys(handler: (e: KeyboardEvent) => void, active = true) {
  const ref = useRef(handler);
  ref.current = handler;
  useEffect(() => {
    if (!active) return;
    const on = (e: KeyboardEvent) => ref.current(e);
    window.addEventListener('keydown', on);
    return () => window.removeEventListener('keydown', on);
  }, [active]);
}

/** POST to a RegisterNUICallback and read the answer. The browser preview answers with `mock`. */
export async function nui<T = unknown>(name: string, data: unknown = {}, mock?: T): Promise<T | null> {
  if (isBrowser) return (mock ?? null) as T | null;
  try {
    const r = await fetch(`https://${resource}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) });
    return (await r.json()) as T;
  } catch {
    return null;
  }
}
