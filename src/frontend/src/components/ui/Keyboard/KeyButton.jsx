import React from 'react';
import { cn } from '../../../utils/cn';

const KeyButton = ({ label, value, onClick, variant = 'default', className, width = 'flex-1' }) => {
  const isSpecial = variant === 'special';
  const isAction = variant === 'action';

  return (
    <button
      onClick={() => onClick(value || label)}
      className={cn(
        'h-[3.33rem] rounded-[0.75rem] font-display font-bold text-[1.25rem] transition-all active:scale-95 active:brightness-125 touch-none select-none',
        'flex items-center justify-center',
        variant === 'default' && 'bg-white/10 text-text-primary border border-white/5',
        variant === 'special' && 'bg-white/5 text-text-muted border border-white/5',
        variant === 'action' && 'bg-accent-red text-white shadow-glow-red',
        width,
        className
      )}
    >
      {label}
    </button>
  );
};

export default KeyButton;
