import React from 'react';
import SettingsPanel from './SettingsPanel';
import { AboutContent } from './AboutView';
import { IconX } from './Icons';

export type InfoPanelTab = 'settings' | 'about';

interface InfoPanelProps {
  open: boolean;
  activeTab: InfoPanelTab;
  onTabChange: (tab: InfoPanelTab) => void;
  onClose: () => void;
}

const tabs: Array<{ id: InfoPanelTab; label: string }> = [
  { id: 'settings', label: 'Settings' },
  { id: 'about', label: 'About' },
];

const InfoPanel: React.FC<InfoPanelProps> = ({ open, activeTab, onTabChange, onClose }) => {
  React.useEffect(() => {
    if (!open) return;
    const handleKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKey);
    return () => window.removeEventListener('keydown', handleKey);
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex" role="dialog" aria-modal="true">
      <div
        aria-hidden="true"
        onClick={onClose}
        className="absolute inset-0 bg-black/40 backdrop-blur-[1px]"
      />
      <aside className="relative ml-auto h-full w-full max-w-lg bg-panel border-l border-soft shadow-2xl flex flex-col">
        <header className="p-4 border-b border-soft flex items-center justify-between">
          <nav className="flex gap-2" aria-label="Info panel tabs">
            {tabs.map(tab => (
              <button
                key={tab.id}
                onClick={() => onTabChange(tab.id)}
                className={`px-3 py-1.5 rounded-full text-sm font-semibold transition-colors ${
                  activeTab === tab.id
                    ? 'bg-[hsl(var(--color-primary))] text-white'
                    : 'bg-panel hover:bg-primary-soft'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </nav>
          <button
            onClick={onClose}
            aria-label="Close info panel"
            className="p-2 rounded-full hover:bg-primary-soft"
          >
            <IconX className="w-5 h-5" />
          </button>
        </header>
        <div className="flex-1 overflow-y-auto p-5">
          {activeTab === 'settings' ? <SettingsPanel /> : <AboutContent />}
        </div>
      </aside>
    </div>
  );
};

export default InfoPanel;
