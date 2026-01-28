import React from 'react';
import { clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';
import IconButton from './IconButton';

function cn(...inputs) {
  return twMerge(clsx(inputs));
}

const CardHeader = ({
  title,
  titleShort,
  subtitle,
  icon: Icon,
  isCompact,
  isMinimal,
  isAccent = false,
  onIconClick,
  centerAction,
}) => (
  <div
    className={cn(
      'relative flex justify-between items-start',
      isMinimal ? 'mb-[1.5rem] flex-col items-center gap-[1.5rem]' : 'mb-[1rem]'
    )}
  >
    <div
      className={cn(
        'flex flex-col overflow-hidden',
        isMinimal ? 'items-center order-2 pr-0' : 'pr-[4rem]'
      )}
    >
      <h2
        className={cn(
          'font-black font-display text-text-primary uppercase tracking-tight leading-none truncate',
          isMinimal ? 'text-[1.125rem] -rotate-90 whitespace-nowrap my-[2rem]' : 'text-[1.25rem]'
        )}
      >
        {isMinimal && titleShort ? titleShort : title}
      </h2>
      {!isMinimal ? (
        <p
          className={cn(
            'text-[1rem] font-bold italic truncate transition-opacity duration-300',
            isAccent ? 'text-accent-red opacity-100' : 'text-text-muted opacity-80'
          )}
        >
          {subtitle}
        </p>
      ) : (
        <div
          className={cn(
            'h-[0.5rem] w-[0.5rem] rounded-full mt-[0.5rem] transition-all duration-300',
            isAccent
              ? 'bg-accent-red shadow-[0_0_8px_rgba(240,68,56,0.6)] animate-pulse'
              : 'bg-text-muted opacity-30'
          )}
        />
      )}
    </div>

    {centerAction && (
      <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 z-30">
        {centerAction}
      </div>
    )}

    <div className={cn('flex items-start gap-[1rem] shrink-0', isMinimal && 'order-1')}>
      {Icon && (
        <IconButton
          icon={Icon}
          onClick={onIconClick}
          variant="default"
          className={isMinimal ? 'h-[3rem] w-[3rem] p-0' : ''}
        />
      )}
    </div>
  </div>
);

export default CardHeader;
