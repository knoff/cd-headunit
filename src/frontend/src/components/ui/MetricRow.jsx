import React, { memo } from 'react';
import { clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

function cn(...inputs) {
  return twMerge(clsx(inputs));
}

const MetricRow = memo(
  ({ icon: Icon, label, value, unit, compact = false, colorClass = 'text-text-primary' }) => (
    <div className={cn('flex items-center justify-between', compact ? 'h-[2rem]' : 'h-[3.5rem]')}>
      <div className="flex items-center gap-[1rem] overflow-hidden">
        <div
          className={cn(
            'flex items-center justify-center rounded-[0.75rem] bg-surface-active/50 text-text-secondary shrink-0',
            compact ? 'h-[1.5rem] w-[1.5rem]' : 'h-[2.5rem] w-[2.5rem]'
          )}
        >
          <Icon className={compact ? 'w-[0.75rem] h-[0.75rem]' : 'w-[1.125rem] h-[1.125rem]'} />
        </div>
        <div className="flex flex-col">
          {!compact && (
            <span className="text-[0.625rem] font-black uppercase text-text-muted tracking-wide leading-tight">
              {label}
            </span>
          )}
          <div className="flex items-baseline gap-[0.375rem] overflow-hidden">
            <span
              className={cn(
                'font-display font-black truncate' /* Removed transition-all */,
                compact ? 'text-[1.125rem]' : 'text-[1.375rem]',
                colorClass
              )}
            >
              {value !== undefined
                ? typeof value === 'number'
                  ? value.toFixed(1)
                  : value
                : '--.-'}
            </span>
            <span
              className={cn(
                'font-bold text-text-muted' /* Removed transition-all */,
                compact ? 'text-[0.625rem]' : 'text-[0.75rem]'
              )}
            >
              {unit}
            </span>
          </div>
        </div>
      </div>
    </div>
  )
);

MetricRow.displayName = 'MetricRow';

export default MetricRow;
