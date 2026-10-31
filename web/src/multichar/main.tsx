import { useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { isBrowser, nui, useKeys, useNuiMessage } from '../shared/nui';
import '../shared/cine.css';

interface Char { citizenid: string; slot: number; firstname: string; lastname: string; birthdate: string; nationality: string; gender: number; job: string; cash: number; bank: number; lastSeen?: number }
interface Open { characters: Char[]; maxSlots: number; allowDelete: boolean }
interface Answer { ok: boolean; error?: string; characters?: Char[]; maxSlots?: number }
type Row = { kind: 'char'; char: Char } | { kind: 'new' };

const money = (n: number) => '$' + Math.round(n).toLocaleString('en-US');
const ago = (t?: number) => {
  if (!t) return 'Never';
  const d = Math.floor((Date.now() / 1000 - t) / 86400);
  return d <= 0 ? 'Today' : d === 1 ? 'Yesterday' : `${d} days ago`;
};

const DEMO: Open = {
  maxSlots: 4,
  allowDelete: true,
  characters: [
    { citizenid: 'ABC123', slot: 1, firstname: 'Nimal', lastname: 'Perera', birthdate: '1994-03-11', nationality: 'Sri Lankan', gender: 0, job: 'Mechanic', cash: 1250, bank: 48210, lastSeen: Date.now() / 1000 - 3600 },
    { citizenid: 'DEF456', slot: 2, firstname: 'Ayesha', lastname: 'Fernando', birthdate: '1998-07-24', nationality: 'Sri Lankan', gender: 1, job: 'Police', cash: 300, bank: 12900, lastSeen: Date.now() / 1000 - 86400 * 4 },
  ],
};

function App() {
  const [data, setData] = useState<Open | null>(null);
  const [sel, setSel] = useState(0);
  const [busy, setBusy] = useState(false);
  const [form, setForm] = useState<null | { firstname: string; lastname: string; birthdate: string; nationality: string; gender: number }>(null);
  const [error, setError] = useState('');
  const [armed, setArmed] = useState(false);

  useNuiMessage((m) => {
    if (m.action === 'open') { setData(m.data as Open); setSel(0); setForm(null); setError(''); }
    else if (m.action === 'close') setData(null);
    else if (m.action === 'busy') setBusy(m.data === true);
  });
  useEffect(() => { if (isBrowser) { document.body.classList.add('demo-bg'); setData(DEMO); } }, []);

  const rows: Row[] = useMemo(() => {
    if (!data) return [];
    const list: Row[] = data.characters.map((c) => ({ kind: 'char', char: c }));
    if (data.characters.length < data.maxSlots) list.push({ kind: 'new' });
    return list;
  }, [data]);
  const row = rows[sel];

  // the world shows the picked character (or an empty body for "new")
  useEffect(() => {
    if (!row || form) return;
    setArmed(false);
    if (row.kind === 'char') void nui('select', { slot: row.char.slot });
    else void nui('preview', { gender: 0 });
  }, [sel, rows.length]); // eslint-disable-line react-hooks/exhaustive-deps

  const play = async () => {
    if (!row || row.kind !== 'char' || busy) return;
    setBusy(true);
    const r = await nui<Answer>('play', { slot: row.char.slot }, { ok: true });
    setBusy(false);
    if (r && !r.ok) setError(r.error || 'Could not load this character');
  };
  const del = async () => {
    if (!row || row.kind !== 'char' || !data?.allowDelete) return;
    if (!armed) return setArmed(true);
    const r = await nui<Answer>('delete', { slot: row.char.slot }, { ok: true, characters: data.characters.filter((c) => c.slot !== row.char.slot), maxSlots: data.maxSlots });
    setArmed(false);
    if (!r || !r.ok) return setError(r?.error || 'Could not delete');
    setData({ ...data, characters: r.characters || [], maxSlots: r.maxSlots || data.maxSlots });
    setSel(0);
  };
  const startCreate = () => { setForm({ firstname: '', lastname: '', birthdate: '', nationality: '', gender: 0 }); setError(''); };
  const create = async () => {
    if (!form) return;
    setBusy(true);
    const r = await nui<Answer>('create', form, { ok: true });
    setBusy(false);
    if (!r || !r.ok) setError(r?.error || 'Could not create the character');
  };

  useKeys((e) => {
    if (!data || busy) return;
    if (form) {
      if (e.key === 'Escape') { setForm(null); setError(''); }
      if (e.key === 'Enter') void create();
      return;
    }
    if (e.key === 'ArrowDown') setSel((s) => Math.min(rows.length - 1, s + 1));
    else if (e.key === 'ArrowUp') setSel((s) => Math.max(0, s - 1));
    else if (e.key === 'Enter') { if (row?.kind === 'new') startCreate(); else void play(); }
    else if (e.key === 'Delete') void del();
  });

  if (!data) return null;
  const c = row && row.kind === 'char' ? row.char : null;

  return (
    <div className={`cine ${busy ? 'busy' : ''}`}>
      <div className="bar top"><small>Project07</small><small>{data.characters.length} / {data.maxSlots} characters</small></div>
      <div className="side">
        <div className="eyebrow">{form ? 'New character' : 'Choose a character'}</div>
        {form ? (
          <>
            <div className="form">
              <div className="row">
                <label className="field"><small>First name</small><input autoFocus value={form.firstname} maxLength={16} onChange={(e) => setForm({ ...form, firstname: e.target.value })} /></label>
                <label className="field"><small>Last name</small><input value={form.lastname} maxLength={16} onChange={(e) => setForm({ ...form, lastname: e.target.value })} /></label>
              </div>
              <div className="row">
                <label className="field"><small>Birth date</small><input className="mono" placeholder="1995-06-21" value={form.birthdate} maxLength={10} onChange={(e) => setForm({ ...form, birthdate: e.target.value.replace(/[^0-9-]/g, '') })} /></label>
                <label className="field"><small>Nationality</small><input value={form.nationality} maxLength={30} onChange={(e) => setForm({ ...form, nationality: e.target.value })} /></label>
              </div>
              <div className="field"><small>Body</small>
                <div className="choice">
                  {['Male', 'Female'].map((g, i) => (
                    <button key={g} className={form.gender === i ? 'on' : ''} onClick={() => { setForm({ ...form, gender: i }); void nui('preview', { gender: i }); }}>{g}</button>
                  ))}
                </div>
              </div>
            </div>
            <div className="actions">
              <button className="act primary" onClick={create} disabled={busy}>Create</button>
              <button className="act" onClick={() => { setForm(null); setError(''); }}>Back</button>
            </div>
          </>
        ) : (
          <>
            <div className="list">
              {rows.map((r, i) => (
                <button key={r.kind === 'char' ? r.char.citizenid : 'new'} className={`item ${i === sel ? 'on' : ''} ${r.kind === 'new' ? 'ghost' : ''}`} onClick={() => (i === sel && r.kind === 'new' ? startCreate() : setSel(i))} onDoubleClick={() => r.kind === 'char' && play()}>
                  <span className="n">{String(i + 1).padStart(2, '0')}</span>
                  <b>{r.kind === 'char' ? `${r.char.firstname} ${r.char.lastname}` : 'New character'}</b>
                </button>
              ))}
            </div>
            {c && (
              <div className="details" key={c.citizenid}>
                <span><small>Job</small><b>{c.job}</b></span>
                <span><small>Born</small><b>{c.birthdate}</b></span>
                <span><small>Cash</small><b className="mono">{money(c.cash)}</b></span>
                <span><small>Bank</small><b className="mono">{money(c.bank)}</b></span>
                <span><small>Nationality</small><b>{c.nationality}</b></span>
                <span><small>Last seen</small><b>{ago(c.lastSeen)}</b></span>
              </div>
            )}
            <div className="actions">
              {c ? <button className="act primary" onClick={play}>Play</button> : <button className="act primary" onClick={startCreate}>Create</button>}
              {c && data.allowDelete && <button className={`act danger ${armed ? 'armed' : ''}`} onClick={del}>{armed ? 'Press again to delete' : 'Delete'}</button>}
              <button className="act" onClick={() => nui('exit')}>Leave</button>
            </div>
          </>
        )}
        <div className="error">{error}</div>
      </div>
      <div className="bar bottom">
        <small>{c ? c.citizenid : ' '}</small>
        <div className="keys">
          {form ? (
            <><span className="key"><kbd>Enter</kbd>Create</span><span className="key"><kbd>Esc</kbd>Back</span></>
          ) : (
            <><span className="key"><kbd>↑ ↓</kbd>Choose</span><span className="key"><kbd>Enter</kbd>{c ? 'Play' : 'Create'}</span>{c && data.allowDelete && <span className="key"><kbd>Del</kbd>Delete</span>}</>
          )}
        </div>
      </div>
    </div>
  );
}

createRoot(document.getElementById('root')!).render(<App />);
