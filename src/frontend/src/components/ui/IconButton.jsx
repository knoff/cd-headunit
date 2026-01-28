import React from 'react';
import { clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs) {
  return twMerge(clsx(inputs));
}

const IconButton = ({ icon: Icon, variant = 'default', className, onClick, size = 'w-6 h-6' }) => {
  const variants = {
    default: 'bg-surface-light text-text-primary active:bg-surface-active',
    accent:
      'bg-accent-red text-white shadow-[0_0.625rem_1.875rem_-0.625rem_rgba(240,68,56,0.2)] active:brightness-110',
    ghost: 'bg-transparent text-text-muted active:text-text-primary active:bg-white/5',
  };

  return (
    <button
      onClick={onClick}
      className={cn(
        'flex h-[3rem] w-[3rem] items-center justify-center rounded-[1rem] active:scale-95 shrink-0 transition-transform',
        variants[variant],
        className
      )}
    >
      <Icon className={size} strokeWidth={2.5} />
    </button>
  );
};

export default IconButton;
