import React from 'react';
import { CheckCircle2, RotateCcw, XCircle } from 'lucide-react';
import { cn } from '../../../utils/cn';

const ExtractionSummary = ({ data, profile, reason = 'done', onDone, t }) => {
  const isCancelled = reason === 'cancelled';
  const isError = reason === 'error';

  return (
    <div
      className={cn(
        'flex flex-col h-full rounded-[1.5rem] p-[1.5rem] border animate-in fade-in duration-300',
        isCancelled || isError
          ? 'bg-accent-red/5 border-accent-red/20'
          : 'bg-surface-light border-white/10'
      )}
    >
      <div className="flex-1 flex flex-col items-center justify-center text-center">
        {isCancelled || isError ? (
          <XCircle className="w-[3rem] h-[3rem] text-accent-red mb-[1rem]" />
        ) : (
          <CheckCircle2 className="w-[3rem] h-[3rem] text-green-500 mb-[1rem]" />
        )}
        <h3 className="text-text-primary text-[1.5rem] font-black font-display uppercase mb-[0.5rem]">
          {isCancelled ? t('stopped') : isError ? t('error') : t('ready')}
        </h3>
        <p className="text-text-muted italic mb-[1.5rem]">{profile.name}</p>

        <div className="grid grid-cols-2 gap-[2rem] w-full max-w-[15rem]">
          <div className="flex flex-col">
            <span className="text-[1.5rem] font-black text-text-primary">{data.yield}</span>
            <span className="text-[0.625rem] font-bold text-text-muted uppercase">
              {t('yield')} (мл)
            </span>
          </div>
          <div className="flex flex-col">
            <span className="text-[1.5rem] font-black text-text-primary">{data.time}</span>
            <span className="text-[0.625rem] font-bold text-text-muted uppercase">{t('time')}</span>
          </div>
        </div>
      </div>

      <button
        onClick={onDone}
        className={cn(
          'mt-auto flex h-[3.5rem] w-full items-center justify-center gap-[0.75rem] rounded-[1.25rem] font-black uppercase tracking-wider active:scale-95 transition-all',
          isCancelled || isError
            ? 'bg-accent-red text-white shadow-glow-red'
            : 'bg-surface-active text-text-primary'
        )}
      >
        <RotateCcw className="w-[1.25rem] h-[1.25rem]" />
        {t('ok')}
      </button>
    </div>
  );
};

export default ExtractionSummary;
