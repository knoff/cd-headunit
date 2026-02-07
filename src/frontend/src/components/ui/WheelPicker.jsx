import React, { useRef, useEffect, useState, useMemo } from 'react';
import { X } from 'lucide-react';
import { cn } from '../../utils/cn';

const ITEM_HEIGHT = 80; // Larger items ~5rem
const VISIBLE_ITEMS = 3; // Height for 3 items (so we can see neighbors clearly)

// Actual visible items in viewport might be less if we mask them,
// but user asked for "visible area = 2 blocks" but "displayed block always in center".
// If we set height to 2 * ITEM_HEIGHT, the center is at 1 * ITEM_HEIGHT.
// Let's stick closer to the visual logic:
// We render a list.
// We want the center item to be "Active" (Red).
// Neighbors "Inactive" (Grey).

const WheelPicker = ({ isOpen, title, options, value, onSave, onClose }) => {
  const containerRef = useRef(null);
  const [visualValue, setVisualValue] = useState(value);
  const scrollTimeout = useRef(null);

  const LOOP_COUNT = 20;
  const loopedOptions = useMemo(() => {
    return Array.from({ length: LOOP_COUNT }).flatMap((_, i) =>
      options.map((opt) => ({ ...opt, loopIndex: i, uniqueId: `${i}-${opt.value}` }))
    );
  }, [options]);

  // Sync visual value if prop changes
  useEffect(() => {
    setVisualValue(value);
  }, [value]);

  // Initial Scroll
  useEffect(() => {
    if (isOpen && containerRef.current) {
      const middleLoop = Math.floor(LOOP_COUNT / 2);
      const targetIndex = middleLoop * options.length + options.findIndex((o) => o.value === value);

      // Center the item
      // Visible height is controlled by surrounding div.
      const containerHeight = VISIBLE_ITEMS * ITEM_HEIGHT;
      const scrollTop = targetIndex * ITEM_HEIGHT - containerHeight / 2 + ITEM_HEIGHT / 2;

      containerRef.current.scrollTop = scrollTop;
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const handleScroll = (e) => {
    if (!containerRef.current) return;

    // setIsScrolling(true); // unnecessary state calc for now if we use visualValue
    clearTimeout(scrollTimeout.current);

    let scrollTop = containerRef.current.scrollTop;
    const totalHeight = loopedOptions.length * ITEM_HEIGHT;
    const singleSetHeight = options.length * ITEM_HEIGHT;

    // Infinite Loop Jump
    if (scrollTop < singleSetHeight) {
      scrollTop = scrollTop + singleSetHeight * 5;
      containerRef.current.scrollTop = scrollTop;
    } else if (scrollTop > totalHeight - singleSetHeight * 2) {
      scrollTop = scrollTop - singleSetHeight * 5;
      containerRef.current.scrollTop = scrollTop;
    }

    // Calculate Active Item immediately for visual feedback
    const containerHeight = VISIBLE_ITEMS * ITEM_HEIGHT;
    const centerLine = scrollTop + containerHeight / 2;
    const index = Math.floor(centerLine / ITEM_HEIGHT);
    const clampedIndex = Math.max(0, Math.min(index, loopedOptions.length - 1));
    const currentOption = loopedOptions[clampedIndex];

    if (currentOption && currentOption.value !== visualValue) {
      setVisualValue(currentOption.value);
    }

    scrollTimeout.current = setTimeout(() => {
      // setIsScrolling(false);
      snapToClosest();
    }, 100);
  };

  const snapToClosest = () => {
    if (!containerRef.current) return;

    const containerHeight = VISIBLE_ITEMS * ITEM_HEIGHT;
    const scrollTop = containerRef.current.scrollTop;
    const centerLine = scrollTop + containerHeight / 2;

    const index = Math.floor(centerLine / ITEM_HEIGHT);
    const clampedIndex = Math.max(0, Math.min(index, loopedOptions.length - 1));

    const targetScrollTop = clampedIndex * ITEM_HEIGHT - containerHeight / 2 + ITEM_HEIGHT / 2;
    containerRef.current.scrollTo({
      top: targetScrollTop,
      behavior: 'smooth',
    });

    const selectedOption = loopedOptions[clampedIndex];
    if (selectedOption && selectedOption.value !== value) {
      onSave(selectedOption.value);
    }
    // Ensure visual sync
    if (selectedOption) {
      setVisualValue(selectedOption.value);
    }
  };

  return (
    <div
      className="fixed inset-0 z-[100] bg-black/90 flex items-center justify-center p-8 animate-in fade-in duration-200 select-none"
      onClick={onClose}
    >
      <div
        className="relative bg-surface-light border border-white/10 rounded-[3rem] w-full max-w-[24rem] shadow-2xl overflow-hidden flex flex-col items-center animate-in zoom-in-95 duration-300"
        onClick={(e) => e.stopPropagation()} // Prevent close when clicking inside
      >
        {/* Header */}
        <div className="absolute top-0 left-0 right-0 z-20 flex items-center justify-between p-6 bg-gradient-to-b from-surface-light via-surface-light/90 to-transparent">
          <h2 className="text-lg font-black uppercase text-text-primary tracking-wide">{title}</h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-white/10 rounded-full transition-colors text-text-muted"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        {/* Picker Area */}
        <div className="relative w-full" style={{ height: `${VISIBLE_ITEMS * ITEM_HEIGHT}px` }}>
          {/* Gradients to mask edges slightly if needed, but keeping it simpler as requested */}
          <div className="absolute top-0 left-0 right-0 h-[20%] bg-gradient-to-b from-surface-light to-transparent z-10 pointer-events-none" />
          <div className="absolute bottom-0 left-0 right-0 h-[20%] bg-gradient-to-t from-surface-light to-transparent z-10 pointer-events-none" />

          <div
            ref={containerRef}
            className="absolute inset-0 overflow-y-auto no-scrollbar"
            onScroll={handleScroll}
            style={{ scrollBehavior: 'auto' }}
          >
            {/*
                   We need spacers? No, math handles centering.
                */}
            <div style={{ height: 0 }} />

            {loopedOptions.map((option, idx) => {
              const isSelected = option.value === visualValue;
              return (
                <div
                  key={option.uniqueId}
                  className="flex items-center justify-center w-full px-8 py-2"
                  style={{ height: `${ITEM_HEIGHT}px` }}
                  onClick={() => {
                    // Scroll to this item
                    const containerHeight = VISIBLE_ITEMS * ITEM_HEIGHT;
                    const targetScrollTop =
                      idx * ITEM_HEIGHT - containerHeight / 2 + ITEM_HEIGHT / 2;
                    containerRef.current.scrollTo({ top: targetScrollTop, behavior: 'smooth' });
                    onSave(option.value);
                  }}
                >
                  <div
                    className={cn(
                      'flex items-center justify-between w-full h-full px-6 rounded-[1.5rem] transition-all duration-200',
                      isSelected
                        ? 'bg-accent-red text-white shadow-glow-red scale-100 opacity-100 z-10'
                        : 'bg-white/5 text-text-muted hover:bg-white/10 scale-95 opacity-60'
                    )}
                  >
                    <span className="text-xl font-bold uppercase tracking-wider">
                      {option.label}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        <div className="w-full h-6 bg-surface-light" />
      </div>
    </div>
  );
};

export default WheelPicker;
