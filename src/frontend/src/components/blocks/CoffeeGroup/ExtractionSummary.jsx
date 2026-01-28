import React from 'react';
import { CheckCircle2, RotateCcw } from 'lucide-react';
import IconButton from '../../ui/IconButton';

const ExtractionSummary = ({ data, profile, onDone, t }) => {
  return (
    <div className="flex flex-col h-full bg-surface-light rounded-[1.5rem] p-[1.5rem] border border-white/10 animate-in slide-in-from-bottom duration-500">
      <div className="flex-1 flex flex-col items-center justify-center text-center">
        <CheckCircle2 className="w-[3rem] h-[3rem] text-green-500 mb-[1rem]" />
        <h3 className="text-text-primary text-[1.5rem] font-black font-display uppercase mb-[0.5rem]">
          {t('ready') || 'Готово'}
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
        className="mt-auto flex h-[3.5rem] w-full items-center justify-center gap-[0.75rem] rounded-[1.25rem] bg-surface-active text-text-primary font-black uppercase tracking-wider active:scale-95 transition-all"
      >
        <RotateCcw className="w-[1.25rem] h-[1.25rem]" />
        {t('ok')}
      </button>
    </div>
  );
};

export default ExtractionSummary;
