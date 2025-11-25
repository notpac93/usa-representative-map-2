import React from 'react';
import { useTheme } from '../contexts/ThemeContext';

const THEME_OPTIONS = [
  {
    value: 'system' as const,
    label: 'Match device',
    description: 'Automatically follow your OS appearance setting.',
  },
  {
    value: 'light' as const,
    label: 'Light',
    description: 'Bright, high-contrast surfaces inspired by civic portals.',
  },
  {
    value: 'dark' as const,
    label: 'Dark',
    description: 'Dim surfaces ideal for low-light viewing.',
  },
];

const SettingsPanel: React.FC = () => {
  const { preference, resolvedTheme, setPreference } = useTheme();

  return (
    <div className="space-y-8">
      <section>
        <div className="flex items-center justify-between mb-3">
          <div>
            <h3 className="text-base font-semibold">Appearance</h3>
            <p className="text-xs text-muted">Resolved theme: <span className="font-medium">{resolvedTheme}</span></p>
          </div>
        </div>
        <div className="space-y-2">
          {THEME_OPTIONS.map(option => (
            <button
              key={option.value}
              type="button"
              onClick={() => setPreference(option.value)}
              className={`w-full text-left p-3 rounded-lg border transition-colors ${
                preference === option.value
                  ? 'border-[hsl(var(--color-primary))] bg-primary-soft'
                  : 'border-soft hover:bg-panel'
              }`}
            >
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-semibold">{option.label}</p>
                  <p className="text-xs text-muted">{option.description}</p>
                </div>
                {preference === option.value && (
                  <span className="text-[10px] uppercase tracking-wide text-primary">Selected</span>
                )}
              </div>
            </button>
          ))}
        </div>
      </section>

      <section>
        <h3 className="text-base font-semibold mb-2">Upcoming controls</h3>
        <p className="text-sm text-muted">
          This settings hub is designed to scale. Expect options for alt color palettes, accessibility
          tweaks, and performance features soon.
        </p>
      </section>
    </div>
  );
};

export default SettingsPanel;
