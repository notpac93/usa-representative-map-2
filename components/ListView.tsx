
import React from 'react';
import { StateRecord } from '../types';
import { IconChevronRight } from './Icons';

interface ListViewProps {
  states: StateRecord[];
  onStateSelect: (stateId: string) => void;
}

const ListView: React.FC<ListViewProps> = ({ states, onStateSelect }) => {
  return (
    <div className="w-full h-full overflow-y-auto bg-panel">
      <ul className="divide-y divide-soft">
        {states.map((state) => (
          <li key={state.id}>
            <button
              onClick={() => onStateSelect(state.id)}
              className="w-full flex justify-between items-center px-6 py-4 text-left hover:bg-primary-soft transition-colors duration-150"
            >
              <span className="text-lg font-medium">{state.name}</span>
              <IconChevronRight className="w-5 h-5 text-muted" />
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
};

export default ListView;
