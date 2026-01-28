import React from 'react';
import { Play, X } from 'lucide-react';
import IconButton from '../../ui/IconButton';

const ExtractionConfirmation = ({ profile, onConfirm, onCancel, t }) => {
  return (
    <div className="flex flex-col h-full bg-accent-red/5 rounded-[1.5rem] p-[1.5rem] border border-accent-red/10 animate-in fade-in zoom-in duration-300">
      <div className="flex-1 flex flex-col items-center justify-center text-center">
        <span className="text-text-muted text-[0.75rem] font-black uppercase tracking-widest mb-[0.5rem]">
          {t('ready_to_start') || 'Готов к запуску'}
        </span>
        <h3 className="text-text-primary text-[1.5rem] font-black font-display uppercase leading-tight mb-[1rem]">
          {profile.name}
        </h3>
        <div className="flex gap-[2rem] mb-[2rem]">
          <div className="flex flex-col items-center">
            <span className="text-[1.25rem] font-black text-text-primary">
              {profile.targetYield}мл
            </span>
            <span className="text-[0.625rem] font-bold text-text-muted uppercase">
              {t('yield')}
            </span>
          </div>
          <div className="w-[1px] bg-white/10" />
          <div className="flex flex-col items-center">
            <span className="text-[1.25rem] font-black text-text-primary">92°C</span>
            <span className="text-[0.625rem] font-bold text-text-muted uppercase">{t('temp')}</span>
          </div>
        </div>
      </div>

      <div className="flex gap-[1rem]">
        <button
          onClick={onCancel}
          className="flex-1 h-[3.5rem] rounded-[1rem] bg-surface-light border border-white/5 text-text-secondary font-black uppercase tracking-wider active:scale-95 transition-transform"
        >
          {t('cancel') || 'ОТМЕНА'}
        </button>
        <IconButton
          icon={Play}
          variant="accent"
          onClick={onConfirm}
          className="h-[3.5rem] w-[3.5rem] rounded-[1rem] shadow-glow-red"
        />
      </div>
    </div>
  );
};

export default ExtractionConfirmation;
