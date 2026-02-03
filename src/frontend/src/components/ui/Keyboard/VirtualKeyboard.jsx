import React, { useRef } from 'react';
import {
  X,
  CornerDownLeft,
  Globe,
  Delete,
  ChevronLeft,
  ChevronRight,
  ChevronUp,
  ChevronDown,
} from 'lucide-react';
import { cn } from '../../../utils/cn';
import { useKeyboard } from '../../../hooks/useKeyboard';
import KeyButton from './KeyButton';

const LAYOUTS = {
  ru: [
    ['Й', 'Ц', 'У', 'К', 'Е', 'Н', 'Г', 'Ш', 'Щ', 'З', 'Х', 'Ъ'],
    ['Ф', 'Ы', 'В', 'А', 'П', 'Р', 'О', 'Л', 'Д', 'Ж', 'Э'],
    ['SHIFT', 'Я', 'Ч', 'С', 'М', 'И', 'Т', 'Ь', 'Б', 'Ю', '.', ','],
    ['123', '#+=', 'GLOBE', 'SPACE', 'BACKSPACE', 'ENTER'],
  ],
  en: [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['SHIFT', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '.', ','],
    ['123', '#+=', 'GLOBE', 'SPACE', 'BACKSPACE', 'ENTER'],
  ],
  num: [
    ['1', '2', '3', '.'],
    ['4', '5', '6', '-'],
    ['7', '8', '9', '0'],
    ['ABC', 'BACKSPACE', 'ENTER'],
  ],
  sym: [
    ['[', ']', '{', '}', '#', '%', '^', '*', '+', '='],
    ['_', '\\', '|', '~', '<', '>', '€', '£', '¥', '•'],
    ['SHIFT', '.', ',', '?', '!', "'", '"', 'BACKSPACE'],
    ['ABC', '123', 'GLOBE', 'SPACE', 'ENTER'],
  ],
};

const VirtualKeyboard = ({ t }) => {
  const {
    isOpen,
    layout,
    setLayout,
    buffer,
    activeField,
    isShifted,
    cursorPos,
    setCursorPos,
    handleKeyPress,
    closeKeyboard,
  } = useKeyboard();

  if (!isOpen) return null;

  const currentLayout = LAYOUTS[layout] || LAYOUTS.ru;
  const isNum = layout === 'num';

  const getKeyLabel = (key) => {
    if (key.length > 1) return key;
    return isShifted ? key.toUpperCase() : key.toLowerCase();
  };

  const isLayoutAllowed = (targetLayout) => {
    if (!activeField?.allowedLayouts) return true;
    return activeField.allowedLayouts.includes(targetLayout);
  };

  const renderBufferWithCursor = () => {
    const items = [];
    const cursorEl = (
      <span
        key="cursor"
        className="inline-block w-[3px] h-[1.75rem] bg-accent-red animate-pulse align-middle mx-[1px]"
      />
    );

    // Initial slot
    items.push(
      <span
        key="slot-0"
        onClick={(e) => {
          e.stopPropagation();
          setCursorPos(0);
        }}
        className="inline-block w-[8px] h-[2rem] hover:bg-white/5 cursor-pointer rounded"
      />
    );
    if (cursorPos === 0) items.push(cursorEl);

    buffer.split('').forEach((char, i) => {
      const nextPos = i + 1;
      if (char === '\n') {
        items.push(<div key={`br-${i}`} className="w-full h-0" />);
        if (cursorPos === nextPos) items.push(cursorEl);
      } else {
        items.push(
          <span
            key={`char-${i}`}
            onClick={(e) => {
              e.stopPropagation();
              setCursorPos(nextPos);
            }}
            className="inline-block font-bold font-display cursor-pointer hover:bg-white/10 px-[1px] text-[1.75rem] leading-[2rem] transition-colors rounded"
          >
            {char}
          </span>
        );
        if (cursorPos === nextPos) items.push(cursorEl);
      }
    });

    return <div className="flex flex-wrap items-center w-full min-h-[2rem]">{items}</div>;
  };

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center p-[2rem] select-none">
      <div
        className="absolute inset-0 bg-black/85 animate-in fade-in duration-500"
        onClick={closeKeyboard}
      />

      <div className="relative z-10 flex flex-row items-stretch gap-[2rem] w-fit max-w-[98rem] h-[22rem] animate-in fade-in slide-in-from-bottom-10 duration-500">
        {/* ЛЕВАЯ КОЛОНКА: Клавиатура */}
        <div
          className={cn(
            'flex flex-col bg-surface/60 border border-white/10 rounded-[2.5rem] p-[1.5rem] shadow-premium transition-all duration-300 relative',
            isNum ? 'w-[32rem]' : 'w-[65rem]'
          )}
        >
          <div className="absolute top-[-0.75rem] left-[2rem] px-[1rem] py-[0.25rem] bg-accent-red rounded-full text-[0.625rem] font-black uppercase tracking-widest text-white shadow-glow-red">
            {layout === 'ru'
              ? 'RU / РУС'
              : layout === 'en'
                ? 'EN / АНГ'
                : layout === 'num'
                  ? '123 / ЦИФ'
                  : '#+= / СИМ'}
          </div>

          <div className="flex flex-col h-full gap-[0.75rem] justify-center text-white">
            {currentLayout.map((row, rowIndex) => (
              <div key={rowIndex} className="flex gap-[0.6rem] justify-center">
                {row.map((key) => {
                  const label = getKeyLabel(key);

                  if (key === 'BACKSPACE') {
                    return (
                      <KeyButton
                        key={key}
                        label={<Delete className="w-[1.25rem] h-[1.25rem]" />}
                        value="BACKSPACE"
                        variant="special"
                        width={isNum ? 'w-[8rem]' : 'w-[6rem]'}
                        onClick={handleKeyPress}
                      />
                    );
                  }
                  if (key === 'ENTER') {
                    if (!activeField?.isMultiline) return null;
                    return (
                      <KeyButton
                        key={key}
                        label={<CornerDownLeft className="w-[1.25rem] h-[1.25rem]" />}
                        value="ENTER"
                        variant="special"
                        width={isNum ? 'w-[12rem]' : 'w-[8rem]'}
                        onClick={handleKeyPress}
                      />
                    );
                  }
                  if (key === 'SPACE') {
                    return (
                      <KeyButton
                        key={key}
                        label=""
                        value=" "
                        width={isNum ? 'w-0 hidden' : 'w-[18rem]'}
                        onClick={handleKeyPress}
                      />
                    );
                  }
                  if (key === 'GLOBE') {
                    const disabled = !isLayoutAllowed('en') && !isLayoutAllowed('ru');
                    return (
                      <KeyButton
                        key={key}
                        label={<Globe className="w-[1.25rem] h-[1.25rem]" />}
                        value="GLOBE"
                        variant="special"
                        className={disabled ? 'opacity-20 pointer-events-none' : ''}
                        width="w-[5rem]"
                        onClick={() => setLayout((prev) => (prev === 'ru' ? 'en' : 'ru'))}
                      />
                    );
                  }
                  if (key === '123') {
                    const disabled = !isLayoutAllowed('num');
                    return (
                      <KeyButton
                        key={key}
                        label="123"
                        value="123"
                        variant="special"
                        className={disabled ? 'opacity-20 pointer-events-none' : ''}
                        width="w-[5rem]"
                        onClick={() => setLayout('num')}
                      />
                    );
                  }
                  if (key === '#+=') {
                    const disabled = !isLayoutAllowed('sym');
                    return (
                      <KeyButton
                        key={key}
                        label="#+="
                        value="#+="
                        variant="special"
                        className={disabled ? 'opacity-20 pointer-events-none' : ''}
                        width="w-[5rem]"
                        onClick={() => setLayout('sym')}
                      />
                    );
                  }
                  if (key === 'ABC') {
                    const disabled = !isLayoutAllowed('ru') && !isLayoutAllowed('en');
                    return (
                      <KeyButton
                        key={key}
                        label="ABC"
                        value="ABC"
                        variant="special"
                        className={disabled ? 'opacity-20 pointer-events-none' : ''}
                        width="w-[7rem]"
                        onClick={() =>
                          setLayout(activeField.allowedLayouts?.includes('en') ? 'en' : 'ru')
                        }
                      />
                    );
                  }
                  if (key === 'SHIFT') {
                    return (
                      <KeyButton
                        key={key}
                        label="⇧"
                        value="SHIFT"
                        variant={isShifted ? 'action' : 'special'}
                        width="w-[6rem]"
                        onClick={() => handleKeyPress('SHIFT')}
                      />
                    );
                  }

                  return (
                    <KeyButton key={key} label={label} value={label} onClick={handleKeyPress} />
                  );
                })}
              </div>
            ))}
          </div>
        </div>

        {/* ЦЕНТРАЛЬНАЯ КОЛОНКА: Окно ввода */}
        <div className="w-[30rem] flex flex-col bg-surface-light border border-white/20 rounded-[2.5rem] p-[1.5rem] shadow-premium overflow-hidden">
          <div className="flex justify-between items-center mb-[1rem]">
            <div className="flex flex-col">
              <span className="text-text-muted font-bold uppercase tracking-widest text-[0.875rem]">
                {activeField?.label || 'Ввод данных'}
              </span>
            </div>
            <button
              onClick={closeKeyboard}
              className="p-[0.5rem] bg-white/5 hover:bg-white/10 rounded-full transition-colors"
            >
              <X className="w-[1rem] h-[1rem] text-text-muted" />
            </button>
          </div>

          <div
            className="flex-1 flex flex-col items-start bg-black/40 rounded-[1.5rem] p-[1.5rem] border border-white/5 overflow-y-auto no-scrollbar cursor-text"
            onClick={() => setCursorPos(buffer.length)}
          >
            <div className="text-[1.75rem] font-bold font-display text-text-primary leading-relaxed whitespace-pre-wrap w-full">
              {renderBufferWithCursor()}
            </div>
          </div>

          <div className="mt-[1.25rem] flex gap-[1rem]">
            <button
              onClick={() => handleKeyPress('CLOSE')}
              className="flex-[0.4] h-[3.5rem] bg-white/5 border border-white/5 rounded-[1.25rem] text-text-muted font-bold uppercase text-[0.75rem] hover:bg-white/10 transition-all font-display"
            >
              {t('clear') || 'CLEAR'}
            </button>
            <button
              onClick={() => handleKeyPress('CONFIRM')}
              className="flex-1 h-[3.5rem] bg-accent-red text-white rounded-[1.25rem] font-black uppercase tracking-wider shadow-glow-red hover:brightness-110 active:scale-95 transition-all text-[0.875rem] font-display"
            >
              {t('done') || 'DONE'}
            </button>
          </div>
        </div>

        {/* ПРАВАЯ КОЛОНКА: Cursor Pad */}
        <div className="w-[10rem] flex flex-col bg-surface/40 border border-white/10 rounded-[2.5rem] p-[1rem] shadow-premium justify-center items-center gap-[1rem]">
          <div className="text-text-muted font-black text-[0.625rem] uppercase tracking-widest mb-2 opacity-50 font-display">
            Cursor
          </div>
          <div className="grid grid-cols-3 gap-2">
            <div />
            <KeyButton
              label={<ChevronUp />}
              value="UP"
              variant="special"
              className="h-[3rem] w-[3rem] p-0"
              onClick={handleKeyPress}
            />
            <div />
            <KeyButton
              label={<ChevronLeft />}
              value="LEFT"
              variant="special"
              className="h-[3rem] w-[3rem] p-0"
              onClick={handleKeyPress}
            />
            <div />
            <KeyButton
              label={<ChevronRight />}
              value="RIGHT"
              variant="special"
              className="h-[3rem] w-[3rem] p-0"
              onClick={handleKeyPress}
            />
            <div />
            <KeyButton
              label={<ChevronDown />}
              value="DOWN"
              variant="special"
              className="h-[3rem] w-[3rem] p-0"
              onClick={handleKeyPress}
            />
            <div />
          </div>
          <div className="mt-4 flex flex-col items-center gap-1 font-display">
            <span className="text-[0.625rem] text-text-muted font-bold uppercase text-center leading-tight">
              Pos / Lth
            </span>
            <span className="text-[1.25rem] text-text-primary font-black">
              {cursorPos} / {buffer.length}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
};

export default VirtualKeyboard;
