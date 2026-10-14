import { initials } from '@/lib/home/stats';
import h from './home.module.css';

/** The student's photo (profile.photo, a small base64 JPEG) or initials (UserAvatar). */
export function Avatar({ name, photo, size = 48, className }: { name: string; photo: string | null; size?: number; className?: string }) {
  return (
    <span className={`${h.avatar} ${className ?? ''}`} style={{ width: size, height: size, fontSize: Math.round(size * 0.36) }} aria-hidden>
      {photo ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={photo.startsWith('data:') ? photo : `data:image/jpeg;base64,${photo}`} alt="" />
      ) : (
        initials(name)
      )}
    </span>
  );
}
