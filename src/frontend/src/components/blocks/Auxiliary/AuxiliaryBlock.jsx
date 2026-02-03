import React from 'react';
import { User, Settings, Bell, List, Power, Activity } from 'lucide-react';
import { cn } from '../../../utils/cn';

const AuxiliaryBlock = ({ time, date, status, isExpanded, isMinimal, onToggleExpand, t }) => {
  return (
    <div
      className={cn(
        'flex h-full flex-col rounded-[2.5rem] bg-surface p-[1.5rem] border border-white/5 shadow-premium overflow-hidden transition-all duration-300',
        isMinimal && 'px-[1rem] pt-[2rem]',
        isExpanded && 'bg-surface-light border-white/10'
      )}
    >
      {/* Header / User Profile */}
      <div className={cn('flex justify-center mb-[1rem]', isMinimal && 'mb-0')}>
        <div
          onClick={onToggleExpand}
          className={cn(
            'rounded-full bg-surface-light border-2 border-white/10 flex items-center justify-center active:scale-95 active:bg-surface-active transition-all cursor-pointer shadow-premium',
            isMinimal ? 'h-[3rem] w-[3rem]' : 'h-[4.5rem] w-[4.5rem]'
          )}
        >
          <User
            className={cn(
              'text-text-secondary',
              isMinimal ? 'w-[1.25rem] h-[1.25rem]' : 'w-[2rem] h-[2rem]'
            )}
          />
        </div>
      </div>

      {!isExpanded ? (
        // Standard / Minimal View
        <div className="flex-1 flex flex-col">
          <div className="flex flex-col items-center justify-center flex-1 text-center">
            <span
              className={cn(
                'font-black font-display text-text-primary tracking-tighter flex items-baseline justify-center',
                isMinimal
                  ? 'text-[1.75rem] -rotate-90 py-[0.5rem] leading-none whitespace-nowrap my-[2rem]'
                  : 'text-[4.5rem] leading-none'
              )}
            >
              {time.split(' ')[0]}
              {time.split(' ')[1] && (
                <span
                  className={cn(
                    'font-black ml-[0.5rem] opacity-50',
                    isMinimal ? 'text-[0.875rem]' : 'text-[1.75rem]'
                  )}
                >
                  {time.split(' ')[1]}
                </span>
              )}
            </span>
            <span
              className={cn(
                'font-bold text-text-muted uppercase tracking-[0.2em]',
                isMinimal
                  ? 'text-[0.625rem] -rotate-90 mt-[2rem] whitespace-nowrap'
                  : 'text-[0.75rem] mt-[0.5rem]'
              )}
            >
              {date}
            </span>
          </div>

          <div
            className={cn(
              'mt-auto flex flex-col items-center gap-[1rem]',
              isMinimal ? 'pt-0 pb-[0.5rem]' : 'pt-[1rem] border-t border-white/5'
            )}
          >
            {isMinimal ? (
              <div
                className={cn(
                  'h-[0.75rem] w-[0.75rem] rounded-full mt-[1.5rem]',
                  status.status === 'ok'
                    ? 'bg-green-500 shadow-[0_0_10px_rgba(34,197,94,0.6)] animate-pulse'
                    : status.status === 'error'
                      ? 'bg-red-500 shadow-[0_0_10px_rgba(239,68,68,0.6)]'
                      : 'bg-yellow-500 animate-pulse'
                )}
              />
            ) : (
              <div className="flex items-center gap-[0.75rem] px-[1.5rem] py-[0.75rem] rounded-[1rem] bg-white/5 border border-white/5">
                <div
                  className={cn(
                    'h-[0.625rem] w-[0.625rem] rounded-full',
                    status.status === 'ok'
                      ? 'bg-green-500 shadow-[0_0_10px_rgba(34,197,94,0.4)]'
                      : status.status === 'error'
                        ? 'bg-red-500'
                        : 'bg-yellow-500'
                  )}
                />
                <span className="text-[0.75rem] font-black text-text-secondary uppercase tracking-widest transition-opacity truncate">
                  {status.status === 'ok'
                    ? t('ok')
                    : status.status === 'error'
                      ? t('error')
                      : t('connecting')}
                </span>
              </div>
            )}
            {!isMinimal && (
              <span className="text-[0.625rem] font-bold text-text-muted opacity-40 uppercase tracking-widest">
                SYSTEM NODE v{status.version}
              </span>
            )}
          </div>
        </div>
      ) : (
        // Expanded View (Settings / Services)
        <div className="flex-1 flex flex-col animate-in fade-in duration-300">
          <div className="grid grid-cols-2 gap-[1.5rem] mt-[1rem]">
            <div className="bg-white/5 p-[1.5rem] rounded-[1.5rem] border border-white/5">
              <Settings className="w-[1.5rem] h-[1.5rem] text-text-muted mb-[0.5rem]" />
              <h4 className="text-text-primary font-black uppercase text-[1rem]">
                {t('settings') || 'Настройки'}
              </h4>
            </div>
            <div className="bg-white/5 p-[1.5rem] rounded-[1.5rem] border border-white/5">
              <Activity className="w-[1.5rem] h-[1.5rem] text-text-muted mb-[0.5rem]" />
              <h4 className="text-text-primary font-black uppercase text-[1rem]">
                {t('diagnostics') || 'Диагностика'}
              </h4>
            </div>
            <div className="bg-white/5 p-[1.5rem] rounded-[1.5rem] border border-white/5">
              <Bell className="w-[1.5rem] h-[1.5rem] text-text-muted mb-[0.5rem]" />
              <h4 className="text-text-primary font-black uppercase text-[1rem]">
                {t('notifications') || 'Логи'}
              </h4>
            </div>
            <div className="bg-white/5 p-[1.5rem] rounded-[1.5rem] border border-white/5">
              <List className="w-[1.5rem] h-[1.5rem] text-text-muted mb-[0.5rem]" />
              <h4 className="text-text-primary font-black uppercase text-[1rem]">
                {t('users') || 'Сервис'}
              </h4>
            </div>
          </div>

          <div className="mt-auto pt-[2rem]">
            <button
              onClick={onToggleExpand}
              className="w-full h-[4rem] rounded-[1.5rem] bg-accent-red text-white font-black uppercase tracking-widest active:scale-95 transition-all shadow-glow-red"
            >
              {t('close') || 'ЗАКРЫТЬ СЕРВИС'}
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default AuxiliaryBlock;
