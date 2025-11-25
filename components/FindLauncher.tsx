import React from 'react';
import { IconSearch, IconX } from './Icons';

interface FindLauncherProps {
  onSubmit: (query: string) => void;
  busy?: boolean;
  placement?: 'global' | 'state';
}

const FindLauncher: React.FC<FindLauncherProps> = ({ onSubmit, busy = false, placement = 'global' }) => {
  const [expanded, setExpanded] = React.useState(false);
  const [value, setValue] = React.useState('');
  const inputRef = React.useRef<HTMLInputElement>(null);

  React.useEffect(() => {
    if (expanded) {
      inputRef.current?.focus();
    }
  }, [expanded]);

  function handleToggle() {
    setExpanded((prev) => !prev);
  }

  function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    if (!value.trim()) return;
    onSubmit(value.trim());
  }

  const isStatePlacement = placement === 'state';
  const containerClass = isStatePlacement
    ? 'fixed z-30 pointer-events-none flex justify-end'
    : 'fixed inset-x-0 z-30 flex justify-center pointer-events-none';
  const containerStyle = isStatePlacement
    ? {
        top: 'calc(env(safe-area-inset-top, 0px) + 1rem)',
        right: 'calc(env(safe-area-inset-right, 0px) + 1rem)',
      }
    : {
        paddingBottom: 'env(safe-area-inset-bottom)',
        bottom: expanded ? 'clamp(6rem, 10vh, 7rem)' : 'clamp(3.5rem, 6vh, 4.5rem)',
      };

  return (
    <div className={containerClass} style={containerStyle}>
      <div
        className={`backdrop-blur-md border border-soft rounded-full flex items-center gap-2 px-3 py-2 transition-all pointer-events-auto ${
          isStatePlacement ? 'shadow-xl' : 'shadow-2xl'
        }`}
        style={{
          minWidth: expanded ? 320 : 64,
          backgroundColor: 'hsla(var(--color-panel) / 0.95)',
        }}
      >
        {expanded ? (
          <form onSubmit={handleSubmit} className="flex items-center gap-2 w-full">
            <IconSearch className="w-5 h-5 text-muted" />
            <input
              ref={inputRef}
              type="text"
              className="bg-transparent text-sm flex-grow focus:outline-none placeholder:text-muted"
              placeholder="Zip code, city, state, official"
              value={value}
              onChange={(e) => setValue(e.target.value)}
              disabled={busy}
            />
            <button
              type="submit"
              className="text-sm font-semibold px-3 py-1 rounded-full bg-[hsl(var(--color-primary))] text-white shadow disabled:opacity-50"
              disabled={busy || !value.trim()}
            >
              Find
            </button>
            <button
              type="button"
              onClick={handleToggle}
              className="p-1 rounded-full hover:bg-primary-soft focus:outline-none"
              aria-label="Close finder"
            >
              <IconX className="w-5 h-5" />
            </button>
          </form>
        ) : (
          <button
            type="button"
            onClick={handleToggle}
            className="flex items-center gap-2 text-sm font-semibold"
            aria-label="Open finder"
          >
            <span className="inline-flex items-center justify-center w-10 h-10 rounded-full bg-[hsl(var(--color-primary))] text-white shadow">
              <IconSearch className="w-5 h-5" />
            </span>
            <span className="hidden md:inline text-muted">Find</span>
          </button>
        )}
      </div>
    </div>
  );
};

export default FindLauncher;
