import React from 'react';
import { createPortal } from 'react-dom';

export interface OverlayControlMeta {
  key: string;
  label: string;
  active: boolean;
  toggle: () => void | Promise<void>;
}

interface OverlayPanelProps {
  controls: OverlayControlMeta[];
  className?: string;
  title?: string;
}

function formatLabel(key: string, label: string): string {
  const aliases: Record<string, string> = {
    'urban-areas': 'Urban areas',
    'congressional-districts': 'Congressional districts',
    counties: 'Counties',
  };
  if (aliases[key]) return aliases[key];
  return label.replace(/\s*\([^)]*\)\s*/g, '').trim();
}

const OverlayPanel: React.FC<OverlayPanelProps> = ({ controls, className, title = 'Data overlays' }) => {
  const [open, setOpen] = React.useState(false);
  const [mounted, setMounted] = React.useState(false);
  const [menuRect, setMenuRect] = React.useState<{ top: number; right: number } | null>(null);
  const wrapperRef = React.useRef<HTMLDivElement | null>(null);
  const menuRef = React.useRef<HTMLDivElement | null>(null);
  const activeCount = React.useMemo(() => controls.filter((c) => c.active).length, [controls]);

  React.useEffect(() => {
    setMounted(true);
  }, []);

  const updateMenuPosition = React.useCallback(() => {
    if (!wrapperRef.current || typeof window === 'undefined') return;
    const rect = wrapperRef.current.getBoundingClientRect();
    const gutter = 12;
    const right = Math.max(gutter, window.innerWidth - rect.right);
    const top = rect.bottom + 10;
    setMenuRect({ top, right });
  }, []);

  React.useEffect(() => {
    if (!open || typeof document === 'undefined') return;
    const handlePointer = (event: MouseEvent | TouchEvent) => {
      if (!wrapperRef.current) return;
      const target = event.target as Node | null;
      if (target && (wrapperRef.current.contains(target) || (menuRef.current?.contains(target) ?? false))) return;
      setOpen(false);
    };
    const handleKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setOpen(false);
      }
    };
    document.addEventListener('mousedown', handlePointer);
    document.addEventListener('touchstart', handlePointer);
    document.addEventListener('keydown', handleKey);
    return () => {
      document.removeEventListener('mousedown', handlePointer);
      document.removeEventListener('touchstart', handlePointer);
      document.removeEventListener('keydown', handleKey);
    };
  }, [open]);

  React.useEffect(() => {
    if (!open || typeof window === 'undefined') {
      setMenuRect(null);
      return;
    }
    updateMenuPosition();
    const handle = () => updateMenuPosition();
    window.addEventListener('resize', handle);
    window.addEventListener('scroll', handle, true);
    return () => {
      window.removeEventListener('resize', handle);
      window.removeEventListener('scroll', handle, true);
    };
  }, [open, updateMenuPosition]);

  if (!controls || controls.length === 0) return null;

  return (
    <div className={`pointer-events-auto ${className || ''}`}>
      <div className="relative inline-flex flex-col items-end" ref={wrapperRef}>
        <button
        type="button"
        onClick={() => setOpen((prev) => !prev)}
        aria-expanded={open}
        className="flex items-center gap-2 rounded-full border border-soft bg-panel/90 px-4 py-2 text-sm font-semibold shadow backdrop-blur-sm transition-colors hover:border-[hsl(var(--color-primary))]"
      >
        <span>Overlays</span>
        {activeCount > 0 && (
          <span className="inline-flex min-w-[1.75rem] items-center justify-center rounded-full bg-[hsl(var(--color-primary))]/15 text-[11px] font-semibold text-[hsl(var(--color-primary))]">
            {activeCount}
          </span>
        )}
        <span className={`text-xs text-muted transition-transform ${open ? 'rotate-180' : ''}`}>▾</span>
        </button>
      </div>
      {open && mounted && menuRect && typeof document !== 'undefined'
        ? createPortal(
            <div
              ref={menuRef}
              className="fixed z-[999] w-[14.5rem] max-w-[90vw] rounded-2xl border border-soft bg-panel/95 p-3 shadow-2xl backdrop-blur-lg"
              style={{ top: menuRect.top, right: menuRect.right }}
            >
              <div className="text-[11px] uppercase tracking-[0.12em] text-muted font-semibold mb-2">
                {title}
              </div>
              <div className="flex flex-col gap-1 overflow-y-auto max-h-[65vh]">
                {controls.map((ctrl) => (
                  <button
                    key={ctrl.key}
                    type="button"
                    onClick={() => ctrl.toggle()}
                    aria-pressed={ctrl.active}
                    className={`group flex items-center justify-between gap-3 rounded-xl border px-3 py-2 text-sm text-left transition-all focus:outline-none focus-visible:ring-2 focus-visible:ring-[hsl(var(--color-primary))] focus-visible:ring-offset-1 focus-visible:ring-offset-transparent ${
                      ctrl.active
                        ? 'text-[hsl(var(--color-primary))] font-semibold bg-[hsl(var(--color-primary))]/12 border-[hsl(var(--color-primary))]/60 shadow-sm'
                        : 'text-muted hover:text-foreground hover:bg-white/5 border-transparent'
                    }`}
                  >
                    <span className="flex-1 leading-tight text-[0.95rem]">{formatLabel(ctrl.key, ctrl.label)}</span>
                  </button>
                ))}
              </div>
            </div>,
            document.body
          )
        : null}
    </div>
  );
};

export default React.memo(OverlayPanel);
