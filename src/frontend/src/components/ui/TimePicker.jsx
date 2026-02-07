import React, { useState, useEffect, useRef } from 'react';
import { X, Check, ChevronUp, ChevronDown } from 'lucide-react';
import { cn } from '../../utils/cn';

const TimePicker = ({ isOpen, initialValue, is24Hour = true, onClose, onSave, t }) => {
  const [selectedDate, setSelectedDate] = useState(new Date());

  // Initialize state from initialValue
  useEffect(() => {
    if (isOpen) {
      const date = initialValue ? new Date(initialValue) : new Date();
      if (!isNaN(date.getTime())) {
        setSelectedDate(date);
      }
    }
  }, [isOpen]);

  if (!isOpen) return null;

  // Helper to update date
  const updateDate = (updates) => {
    const newDate = new Date(selectedDate);
    if (updates.year !== undefined) newDate.setFullYear(updates.year);
    if (updates.month !== undefined) newDate.setMonth(updates.month);
    if (updates.date !== undefined) newDate.setDate(updates.date);
    if (updates.hours !== undefined) newDate.setHours(updates.hours);
    if (updates.minutes !== undefined) newDate.setMinutes(updates.minutes);
    setSelectedDate(newDate);
  };

  const years = Array.from({ length: 11 }, (_, i) => new Date().getFullYear() - 5 + i);
  const months = Array.from({ length: 12 }, (_, i) => i);
  const daysInMonth = new Date(
    selectedDate.getFullYear(),
    selectedDate.getMonth() + 1,
    0
  ).getDate();
  const days = Array.from({ length: daysInMonth }, (_, i) => i + 1);

  const hours24 = Array.from({ length: 24 }, (_, i) => i);
  const hours12 = Array.from({ length: 12 }, (_, i) => (i === 0 ? 12 : i));
  const minutes = Array.from({ length: 60 }, (_, i) => i);

  const currentHour = selectedDate.getHours();
  const isPm = currentHour >= 12;
  const displayHour = is24Hour ? currentHour : currentHour % 12 || 12;

  const handleHourChange = (newHour) => {
    if (is24Hour) {
      updateDate({ hours: newHour });
    } else {
      // Translate 12h back to 24h
      let setH = newHour === 12 ? 0 : newHour;
      if (isPm) setH += 12;
      updateDate({ hours: setH });
    }
  };

  const toggleAmPm = () => {
    let newH = currentHour;
    if (isPm) {
      newH -= 12; // PM -> AM
    } else {
      newH += 12; // AM -> PM
    }
    updateDate({ hours: newH });
  };

  const handleSave = () => {
    // Format YYYY-MM-DD HH:MM:SS
    const pad = (n) => n.toString().padStart(2, '0');
    const YYYY = selectedDate.getFullYear();
    const MM = pad(selectedDate.getMonth() + 1);
    const DD = pad(selectedDate.getDate());
    const HH = pad(selectedDate.getHours());
    const mm = pad(selectedDate.getMinutes());
    const SS = pad(selectedDate.getSeconds()); // Keep seconds as is or reset to 00? Let's keep 00 for cleanliness or current

    onSave(`${YYYY}-${MM}-${DD} ${HH}:${mm}:00`);
    onClose();
  };

  const Spinner = ({ label, items, value, onChange, formatLabel, className }) => {
    const currentIndex = items.indexOf(value);

    const handleNext = () => {
      const nextIndex = (currentIndex + 1) % items.length;
      onChange(items[nextIndex]);
    };

    const handlePrev = () => {
      const prevIndex = (currentIndex - 1 + items.length) % items.length;
      onChange(items[prevIndex]);
    };

    return (
      <div
        className={cn(
          'flex flex-col h-full items-center justify-between bg-black/20 rounded-2xl p-2',
          className
        )}
      >
        <div className="text-[0.65rem] font-bold text-text-muted uppercase tracking-wider mb-2">
          {label}
        </div>

        <button
          onClick={handleNext}
          className="p-2 rounded-full transition-colors text-text-muted active:text-accent-red active:bg-white/10"
        >
          <ChevronUp className="w-6 h-6" />
        </button>

        <div className="flex-1 flex items-center justify-center">
          <span className="text-3xl font-black font-display text-text-primary">
            {formatLabel ? formatLabel(value) : value.toString().padStart(2, '0')}
          </span>
        </div>

        <button
          onClick={handlePrev}
          className="p-2 rounded-full transition-colors text-text-muted active:text-accent-red active:bg-white/10"
        >
          <ChevronDown className="w-6 h-6" />
        </button>
      </div>
    );
  };

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center p-[2rem] select-none">
      <div
        className="absolute inset-0 bg-black/85 animate-in fade-in duration-300"
        onClick={onClose}
      />

      <div className="relative z-10 flex flex-col w-[40rem] bg-surface-light border border-white/10 rounded-[2.5rem] shadow-2xl animate-in zoom-in-95 duration-300 overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-white/5 bg-white/5">
          <h2 className="text-lg font-black uppercase text-text-primary tracking-wide">
            {t('sys_set_time') || 'Set Time'}
          </h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-white/10 rounded-full transition-colors text-text-muted"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 flex gap-4 p-6 h-[18rem]">
          {/* DATE */}
          <div className="flex-[4] flex flex-col gap-2">
            <div className="flex-1 flex gap-2">
              <Spinner
                label={t('year')}
                items={years}
                value={selectedDate.getFullYear()}
                onChange={(v) => updateDate({ year: v })}
                formatLabel={(v) => v}
                className="flex-1"
              />
              <Spinner
                label={t('month')}
                items={months}
                value={selectedDate.getMonth()}
                onChange={(v) => updateDate({ month: v })}
                formatLabel={(v) =>
                  new Date(2000, v, 1)
                    .toLocaleDateString(t('language') === 'ru' ? 'ru' : 'en', { month: 'short' })
                    .toUpperCase()
                }
                className="flex-1"
              />
              <Spinner
                label={t('day')}
                items={days}
                value={selectedDate.getDate()}
                onChange={(v) => updateDate({ date: v })}
                formatLabel={(v) => v}
                className="flex-1"
              />
            </div>
          </div>

          <div className="w-[1px] bg-white/10 my-2" />

          {/* TIME */}
          <div className="flex-[3] flex flex-col gap-2">
            <div className="flex-1 flex gap-2">
              <Spinner
                label={t('hour')}
                items={is24Hour ? hours24 : hours12}
                value={displayHour}
                onChange={handleHourChange}
                className="flex-1"
              />

              <div className="self-center text-xl font-black text-text-muted pb-8">:</div>

              <Spinner
                label={t('minute')}
                items={minutes}
                value={selectedDate.getMinutes()}
                onChange={(v) => updateDate({ minutes: v })}
                className="flex-1"
              />

              {!is24Hour && (
                <div className="flex flex-col justify-center gap-2 ml-1">
                  <button
                    className={cn(
                      'px-2 py-3 rounded-lg font-black text-xs border transition-all',
                      !isPm
                        ? 'bg-accent-red text-white border-accent-red'
                        : 'bg-white/5 text-text-muted border-transparent hover:bg-white/10'
                    )}
                    onClick={() => isPm && toggleAmPm()}
                  >
                    AM
                  </button>
                  <button
                    className={cn(
                      'px-2 py-3 rounded-lg font-black text-xs border transition-all',
                      isPm
                        ? 'bg-accent-red text-white border-accent-red'
                        : 'bg-white/5 text-text-muted border-transparent hover:bg-white/10'
                    )}
                    onClick={() => !isPm && toggleAmPm()}
                  >
                    PM
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="p-6 border-t border-white/5 flex justify-end gap-4 bg-black/20">
          <button
            onClick={onClose}
            className="px-8 h-[3.5rem] bg-white/5 border border-white/5 rounded-2xl text-text-muted font-bold uppercase text-sm hover:bg-white/10 transition-all"
          >
            {t('cancel') || 'Cancel'}
          </button>
          <button
            onClick={handleSave}
            className="px-8 h-[3.5rem] bg-accent-red text-white rounded-2xl font-black uppercase tracking-wider shadow-glow-red hover:brightness-110 active:scale-95 transition-all text-sm flex items-center gap-2"
          >
            <Check className="w-5 h-5" />
            <span>{t('apply')}</span>
          </button>
        </div>
      </div>
    </div>
  );
};

export default TimePicker;
