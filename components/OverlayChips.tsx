import React from 'react';

export interface OverlayControlMeta {
  key: string;
  label: string;
  active: boolean;
  toggle: () => void | Promise<void>;
}

interface OverlayChipsProps {
  controls: OverlayControlMeta[];
  className?: string;
}

function shortLabel(key: string, label: string): string {
  const map: Record<string, string> = {
    'urban-areas': 'Urban',
    'congressional-districts': 'Districts',
    'counties': 'Counties',
  };
  if (map[key]) return map[key];
  // Fallback: drop parenthetical and truncate to ~18 chars
  const base = label.replace(/\s*\([^)]*\)\s*/g, '').trim();
  return base.length > 18 ? base.slice(0, 16) + '…' : base;
}

const OverlayChips: React.FC<OverlayChipsProps> = ({ controls, className }) => {
  if (!controls || controls.length === 0) return null;
  return (
    <div className={`flex flex-wrap items-center justify-end gap-2 ${className || ''}`}>
      {controls.map((ctrl) => (
        <button
          key={ctrl.key}
          onClick={() => ctrl.toggle()}
          aria-pressed={ctrl.active}
          title={ctrl.label}
          className={`px-3 py-1.5 rounded-full text-xs font-semibold shadow-sm border transition-colors backdrop-blur-sm focus:outline-none focus-visible:ring-2 focus-visible:ring-[hsl(var(--color-primary))] focus-visible:ring-offset-2 focus-visible:ring-offset-transparent select-none ${
            ctrl.active
              ? 'bg-[hsl(var(--color-primary))] text-white border-[hsl(var(--color-primary))]'
              : 'bg-panel text-muted border-soft hover:bg-surface'
          }`}
        >
          {shortLabel(ctrl.key, ctrl.label)}
        </button>
      ))}
    </div>
  );
};

export default React.memo(OverlayChips);
