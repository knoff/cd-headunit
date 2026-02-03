import React from 'react';
import { Power, Check, X } from 'lucide-react';
import { cn } from '../../utils/cn';
import IconButton from './IconButton';

const Select = ({ isOpen, title, options, value, onSelect, onClose }) => {
  if (!isOpen) return null;

  return (
    <div className="absolute inset-0 z-[100] bg-black/90 flex items-center justify-center p-[2rem] animate-in fade-in duration-200">
      <div className="bg-surface-light border border-white/10 rounded-[3rem] p-[3rem] w-full max-w-[40rem] flex flex-col gap-[2rem] shadow-2xl overflow-hidden max-h-[90%]">
        <div className="flex justify-between items-center">
          <h2 className="text-[1.75rem] font-black uppercase text-text-primary tracking-tighter">
            {title}
          </h2>
          <IconButton icon={X} variant="ghost" onClick={onClose} />
        </div>

        <div className="flex flex-col gap-[0.75rem] overflow-y-auto pr-[0.5rem] no-scrollbar">
          {options.map((option) => {
            const isSelected = option.value === value;
            return (
              <button
                key={option.value}
                onClick={() => {
                  onSelect(option.value);
                  onClose();
                }}
                className={cn(
                  'flex items-center justify-between p-[1.5rem] rounded-[1.5rem] transition-all text-left',
                  isSelected
                    ? 'bg-accent-red text-white shadow-glow-red'
                    : 'bg-white/5 text-text-muted hover:bg-white/10'
                )}
              >
                <span className="text-[1.25rem] font-bold uppercase tracking-tight">
                  {option.label}
                </span>
                {isSelected && <Check className="w-[1.5rem] h-[1.5rem]" />}
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
};

export default Select;
