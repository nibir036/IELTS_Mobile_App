'use client';

import { useRouter } from 'next/navigation';
import { useRef, useState, type ReactNode } from 'react';
import { PrimaryButton } from '@/components/ui';
import d from '@/components/dialog.module.css';
import { Avatar } from './avatar';
import h from './home.module.css';
import { Portal } from '@/components/portal';

const BANDS = [5, 5.5, 6, 6.5, 7, 7.5, 8, 8.5, 9];

export interface ProfileBasics {
  name: string;
  targetBand: number | null;
  examDate: string | null;
  photo: string | null;
}

const localKey = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

/** PATCH /v1/me (name + profile keys; null removes a key), like Store.updateProfile. */
export async function patchMe(body: { name?: string; profile?: Record<string, unknown> }): Promise<string | null> {
  const res = await fetch('/api/v1/me', { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }).catch(() => null);
  if (!res) return 'Can’t reach the IELTS AI server. Please try again.';
  if (res.ok) return null;
  const data = (await res.json().catch(() => ({}))) as { error?: string };
  return data.error ?? 'Your profile could not be saved.';
}

/** A photo file → a 400 px JPEG as base64 (the app's image_picker settings). */
async function shrink(file: File): Promise<string> {
  const url = URL.createObjectURL(file);
  try {
    const img = await new Promise<HTMLImageElement>((resolve, reject) => {
      const i = new Image();
      i.onload = () => resolve(i);
      i.onerror = reject;
      i.src = url;
    });
    const scale = Math.min(1, 400 / Math.max(img.width, img.height));
    const c = document.createElement('canvas');
    c.width = Math.max(1, Math.round(img.width * scale));
    c.height = Math.max(1, Math.round(img.height * scale));
    c.getContext('2d')!.drawImage(img, 0, 0, c.width, c.height);
    return c.toDataURL('image/jpeg', 0.75).split(',')[1] ?? '';
  } finally {
    URL.revokeObjectURL(url);
  }
}

/** Edit profile (profile_sheet.dart): photo, name, target band, exam date. */
export function EditProfileDialog({ initial, onClose }: { initial: ProfileBasics; onClose: () => void }) {
  const router = useRouter();
  const [name, setName] = useState(initial.name);
  const [target, setTarget] = useState<number | null>(initial.targetBand);
  const [exam, setExam] = useState(initial.examDate ?? '');
  const [photo, setPhoto] = useState<string | null>(initial.photo);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const file = useRef<HTMLInputElement>(null);
  const today = new Date();
  const max = new Date(today.getTime() + 730 * 86_400_000);

  const save = async () => {
    if (!name.trim()) {
      setError('Name cannot be empty.');
      return;
    }
    setBusy(true);
    setError(null);
    const profile: Record<string, unknown> = { testType: 'Academic' };
    if (target != null) profile.targetBand = target;
    if (exam) profile.examDate = exam;
    if (photo !== initial.photo) profile.photo = photo;
    const err = await patchMe({ name: name.trim(), profile });
    setBusy(false);
    if (err) {
      setError(err);
      return;
    }
    onClose();
    router.refresh();
  };

  return (
    <Portal><div className={d.backdrop} role="dialog" aria-modal="true" aria-labelledby="edit-profile-title" onClick={onClose}>
      <div className={`${d.sheet} ${h.dialogScroll}`} onClick={(e) => e.stopPropagation()}>
        <h2 id="edit-profile-title" className={d.title}>
          Edit profile
        </h2>
        <div className={h.form}>
          <div className={h.identity}>
            <Avatar name={name} photo={photo} size={56} />
            <span className={h.label} style={{ flex: 1 }}>
              Profile photo
            </span>
            <button type="button" className={h.outlineBtn} style={{ height: 40, padding: '0 14px', fontSize: 13 }} onClick={() => file.current?.click()}>
              Change photo
            </button>
            {photo && (
              <button type="button" className={h.linkBtn} onClick={() => setPhoto(null)}>
                Remove
              </button>
            )}
            <input
              ref={file}
              type="file"
              accept="image/*"
              hidden
              onChange={async (e) => {
                const f = e.target.files?.[0];
                e.target.value = '';
                if (!f) return;
                try {
                  setPhoto(await shrink(f));
                } catch {
                  setError('That photo could not be opened.');
                }
              }}
            />
          </div>
          <label className={h.form} style={{ gap: 6 }}>
            <span className={h.fieldLabel}>Full name</span>
            <input className={h.input} value={name} maxLength={80} onChange={(e) => setName(e.target.value)} autoComplete="name" />
          </label>
          <span className={h.fieldLabel} id="tb-label">
            Target band
          </span>
          <div className={h.pillChips} role="radiogroup" aria-labelledby="tb-label">
            {BANDS.map((b) => (
              <button
                key={b}
                type="button"
                role="radio"
                aria-checked={target === b}
                className={`${h.pillChip} ${target === b ? h.pillChipOn : ''}`}
                onClick={() => setTarget(b)}
              >
                {b.toFixed(1)}
              </button>
            ))}
          </div>
          <label className={h.form} style={{ gap: 6 }}>
            <span className={h.fieldLabel}>Exam date</span>
            <input className={h.input} type="date" value={exam} min={localKey(today)} max={localKey(max)} onChange={(e) => setExam(e.target.value)} />
          </label>
          {error && <p className={h.error}>{error}</p>}
          <PrimaryButton block onClick={save} disabled={busy}>
            {busy ? 'Saving…' : 'Save changes'}
          </PrimaryButton>
          <button type="button" className={h.outlineBtn} onClick={onClose}>
            Cancel
          </button>
        </div>
      </div>
    </div></Portal>
  );
}

/** A button that opens the edit-profile dialog. */
export function EditProfileButton({ initial, className, label, children }: { initial: ProfileBasics; className?: string; label?: string; children: ReactNode }) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button type="button" className={className} aria-label={label} title={label} onClick={() => setOpen(true)}>
        {children}
      </button>
      {open && <EditProfileDialog initial={initial} onClose={() => setOpen(false)} />}
    </>
  );
}
