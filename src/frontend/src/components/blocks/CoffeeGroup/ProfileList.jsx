import React, { memo } from 'react';
import { Coffee } from 'lucide-react';
import { COFFEE_PROFILES } from '../../../constants/profiles';
import { cn } from '../../../utils/cn';

const ProfileList = memo(({ onSelect, t, contentHeight }) => {
  return (
    <div
      className={cn(
        'overflow-y-auto pr-[0.5rem] -mr-[0.5rem] no-scrollbar touch-pan-y overscroll-contain select-none snap-y snap-mandatory',
        contentHeight
      )}
    >
      <div className="grid grid-cols-2 gap-[0.5rem]">
        {COFFEE_PROFILES.map((p) => (
          <div
            key={p.id}
            onClick={() => onSelect(p)}
            className="flex flex-col p-[0.75rem] h-[6.75rem] rounded-[1.25rem] bg-white/5 border border-white/5 active:border-white/20 active:bg-white/10 cursor-pointer transition-all shrink-0 overflow-hidden snap-start"
          >
            <div className="mb-[0.5rem] border-b border-white/5 pb-[0.25rem]">
              <span className="text-[0.8125rem] font-black text-text-primary uppercase leading-none truncate block">
                {p.name}
              </span>
            </div>

            <div className="flex flex-1 gap-[0.75rem] items-center">
              <div className="shrink-0 flex items-center justify-center bg-surface-active/30 rounded-[0.5rem] px-[0.5rem] py-[0.3rem] min-w-[2.75rem]">
                <span className="text-[0.8125rem] font-black text-text-secondary font-display tracking-tighter leading-none">
                  {p.targetYield}
                  <span className="text-[0.5625rem] ml-[2px] opacity-60">
                    {t('unit_yield').toUpperCase()}
                  </span>
                </span>
              </div>
              <div className="flex-1 overflow-hidden">
                <span className="text-[0.8125rem] font-normal text-text-secondary italic leading-[1.2] line-clamp-3">
                  {p.desc}
                </span>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
});

ProfileList.displayName = 'ProfileList';

export default ProfileList;
