import React, { createContext, useContext, useState, useCallback } from 'react';

const KeyboardContext = createContext(null);

export const KeyboardProvider = ({ children }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [layout, setLayout] = useState('ru'); // 'ru', 'en', 'num', 'sym'
  const [buffer, setBuffer] = useState('');
  const [activeField, setActiveField] = useState(null); // { id, label, type, value, onSave, allowedLayouts, isMultiline }
  const [isShifted, setIsShifted] = useState(false);
  const [cursorPos, setCursorPos] = useState(0);

  const openKeyboard = useCallback((fieldConfig) => {
    setActiveField(fieldConfig);
    const initialValue = fieldConfig.value || '';
    setBuffer(initialValue);
    setCursorPos(initialValue.length);

    // Set default layout based on config or type
    if (fieldConfig.defaultLayout) {
      setLayout(fieldConfig.defaultLayout);
    } else if (fieldConfig.type === 'num') {
      setLayout('num');
    } else {
      setLayout('ru');
    }

    setIsOpen(true);
  }, []);

  const closeKeyboard = useCallback(() => {
    setIsOpen(false);
    setActiveField(null);
    setBuffer('');
    setCursorPos(0);
  }, []);

  const moveCursor = useCallback(
    (delta) => {
      setCursorPos((prev) => Math.max(0, Math.min(buffer.length, prev + delta)));
    },
    [buffer.length]
  );

  const moveCursorLine = useCallback(
    (direction) => {
      const lines = buffer.split('\n');
      let accumulated = 0;
      let currentLineIdx = 0;
      let offsetInLine = 0;

      for (let i = 0; i < lines.length; i++) {
        const lineLen = lines[i].length;
        if (cursorPos <= accumulated + lineLen) {
          currentLineIdx = i;
          offsetInLine = cursorPos - accumulated;
          break;
        }
        accumulated += lineLen + 1; // +1 for newline character
      }

      const targetLineIdx = currentLineIdx + direction;
      if (targetLineIdx < 0 || targetLineIdx >= lines.length) return;

      let newPos = 0;
      for (let i = 0; i < targetLineIdx; i++) {
        newPos += lines[i].length + 1;
      }
      const targetLineLen = lines[targetLineIdx].length;
      newPos += Math.min(offsetInLine, targetLineLen);

      setCursorPos(newPos);
    },
    [buffer, cursorPos]
  );

  const handleKeyPress = useCallback(
    (key) => {
      if (key === 'BACKSPACE') {
        if (cursorPos > 0) {
          setBuffer((prev) => prev.slice(0, cursorPos - 1) + prev.slice(cursorPos));
          setCursorPos((prev) => prev - 1);
        }
      } else if (key === 'ENTER') {
        if (activeField?.isMultiline) {
          setBuffer((prev) => prev.slice(0, cursorPos) + '\n' + prev.slice(cursorPos));
          setCursorPos((prev) => prev + 1);
        }
      } else if (key === 'SHIFT') {
        setIsShifted((prev) => !prev);
      } else if (key === 'CONFIRM') {
        if (activeField?.onSave) {
          activeField.onSave(buffer);
        }
        closeKeyboard();
      } else if (key === 'CLOSE') {
        closeKeyboard();
      } else if (key === 'LEFT') {
        moveCursor(-1);
      } else if (key === 'RIGHT') {
        moveCursor(1);
      } else if (key === 'UP') {
        moveCursorLine(-1);
      } else if (key === 'DOWN') {
        moveCursorLine(1);
      } else {
        let char = key;
        if (key.length === 1) {
          char = isShifted ? key.toUpperCase() : key.toLowerCase();
        }
        setBuffer((prev) => prev.slice(0, cursorPos) + char + prev.slice(cursorPos));
        setCursorPos((prev) => prev + 1);
      }
    },
    [activeField, buffer, closeKeyboard, cursorPos, isShifted, moveCursor, moveCursorLine]
  );

  return (
    <KeyboardContext.Provider
      value={{
        isOpen,
        layout,
        setLayout,
        buffer,
        setBuffer,
        activeField,
        isShifted,
        setIsShifted,
        cursorPos,
        setCursorPos,
        openKeyboard,
        closeKeyboard,
        handleKeyPress,
        moveCursor,
      }}
    >
      {children}
    </KeyboardContext.Provider>
  );
};

export const useKeyboard = () => {
  const context = useContext(KeyboardContext);
  if (!context) {
    throw new Error('useKeyboard must be used within a KeyboardProvider');
  }
  return context;
};
