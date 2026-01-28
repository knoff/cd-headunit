import React from 'react';
import { clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';
import IconButton from './IconButton';

function cn(...inputs) {
  return twMerge(clsx(inputs));
}

const CardHeader = ({
  title,
  subtitle,
  icon: Icon,
  isCompact,
  isAccent = false,
  onIconClick,
  centerAction,
}) => (
  <div
    className={cn(
      'relative flex justify-between items-start',
      isCompact ? 'mb-[1rem]' : 'mb-[1rem]'
    )}
  >
    <div className="flex flex-col overflow-hidden pr-[4rem]">
      <h2
        className={cn(
          'font-black font-display text-text-primary uppercase tracking-tight leading-none truncate',
          isCompact ? 'text-[1.25rem]' : 'text-[1.25rem]'
        )}
      >
        {title}
      </h2>
      <p
        className={cn(
          'text-[1rem] font-bold italic truncate transition-opacity',
          isAccent ? 'text-accent-red opacity-100' : 'text-text-muted opacity-80',
          isCompact && 'hidden'
        )}
      >
        {subtitle}
      </p>
    </div>

    {centerAction && (
      <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 z-30">
        {centerAction}
      </div>
    )}

    <div className="flex items-start gap-[1rem] shrink-0">
      {Icon && !isCompact && <IconButton icon={Icon} onClick={onIconClick} variant="default" />}
      {isCompact && isAccent && (
        <div className="h-[1.5rem] w-[1.5rem] rounded-[0.5rem] bg-accent-red/20 border border-accent-red/30 shrink-0" />
      )}
    </div>
  </div>
);

export default CardHeader;
