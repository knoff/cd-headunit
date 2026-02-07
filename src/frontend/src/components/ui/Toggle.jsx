import React from 'react';
import { cn } from '../../utils/cn';

const Toggle = ({ checked, onChange, disabled }) => {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      disabled={disabled}
      onClick={() => !disabled && onChange(!checked)}
      className={cn(
        'relative inline-flex h-[1.75rem] w-[3.25rem] shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus-visible:ring-2 focus-visible:ring-white focus-visible:ring-offset-2 focus-visible:ring-offset-black',
        checked ? 'bg-accent-red' : 'bg-white/10',
        disabled && 'opacity-50 cursor-not-allowed'
      )}
    >
      <span className="sr-only">Use setting</span>
      <span
        className={cn(
          'pointer-events-none inline-block h-[1.5rem] w-[1.5rem] transform rounded-full bg-white shadow-lg ring-0 transition duration-200 ease-in-out',
          checked ? 'translate-x-[1.5rem]' : 'translate-x-0'
        )}
      />
    </button>
  );
};

export default Toggle;
