
import React from 'react';
import { IconArrowLeft, IconCode, IconDatabase } from './Icons';

interface AboutViewProps {
  onBack: () => void;
}

export const AboutContent: React.FC = () => (
  <div className="space-y-8">
    <div>
      <h3 className="text-xl font-bold mb-2 flex items-center"><IconDatabase className="w-5 h-5 mr-2" />Data & Methodology</h3>
      <p className="mb-2">
        This application aims to provide clear, accessible civics information. All data is sourced from public, official portals to ensure accuracy and integrity.
      </p>
      <ul className="list-disc list-inside space-y-1 pl-2">
        <li><strong>Map Geometry:</strong> Based on U.S. Census Bureau "Cartographic Boundary Files" for states, which are in the public domain. The map is a pre-processed Albers USA projection.</li>
        <li><strong>Civic Information:</strong> Sourced from official state government and federal websites. Each state's detail page lists its specific sources.</li>
        <li><strong>Offline First:</strong> All essential data is bundled with the application, allowing it to function without an internet connection.</li>
      </ul>
    </div>

    <div>
      <h3 className="text-xl font-bold mb-2 flex items-center"><IconCode className="w-5 h-5 mr-2" />Technology</h3>
      <p className="mb-2">
        Built with modern web technologies to be fast, responsive, and maintainable.
      </p>
      <ul className="list-disc list-inside space-y-1 pl-2">
        <li><strong>Framework:</strong> React with TypeScript</li>
        <li><strong>Styling:</strong> Tailwind CSS</li>
        <li><strong>Map Interaction:</strong> D3.js for robust pan and zoom functionality on SVG elements.</li>
      </ul>
    </div>

    <div>
       <h3 className="text-xl font-bold mb-2">Privacy</h3>
       <p>This application does not collect or store any personal information. No location tracking is used. All operations are performed on your device.</p>
    </div>
  </div>
);

const AboutView: React.FC<AboutViewProps> = ({ onBack }) => {
  return (
    <div className="w-full h-full flex flex-col bg-panel">
      <header className="p-4 border-b border-soft flex items-center flex-shrink-0 sticky top-0 bg-panel/90 backdrop-blur-sm z-10">
        <button onClick={onBack} className="p-2 rounded-full hover:bg-primary-soft transition-colors mr-2" aria-label="Back to main view">
          <IconArrowLeft className="w-6 h-6" />
        </button>
        <h2 className="text-2xl font-bold tracking-tight">About & Sources</h2>
      </header>
      <div className="flex-grow overflow-y-auto p-6">
        <AboutContent />
      </div>
    </div>
  );
};

export default AboutView;
