import React, { useMemo } from 'react';
import { AppStates } from '../../state/machines/appMachine';

const DashboardGrid = ({ children, activeState }) => {
  const gridTemplate = useMemo(() => {
    const base = 'fr'; // Используем fr для пропорций
    const groupStd = `6${base}`;
    const auxStd = `4${base}`;
    const centerStd = `2${base}`;
    const min = `1${base}`;
    const expanded = '1fr'; // Для расширенного состояния все еще используем жадный 1fr, если остальные фиксированы

    switch (activeState) {
      case AppStates.FOCUS_LEFT:
        return `9fr 4fr 2fr 1fr 6fr`;
      case AppStates.FOCUS_RIGHT:
        return `6fr 4fr 2fr 1fr 9fr`;
      case AppStates.FOCUS_BOTH:
        return `9fr 1fr 2fr 1fr 9fr`;
      case AppStates.SYSTEM_EXPANDED:
        return `1fr 1fr 2fr 17fr 1fr`;
      default:
        // Стандарт: 6-4-2-4-6
        return `6fr 4fr 2fr 4fr 6fr`;
    }
  }, [activeState]);

  return (
    <div
      className="grid-cols-5-segment w-full gap-[0.75rem]"
      style={{
        display: 'grid',
        gridTemplateColumns: gridTemplate,
        width: '100%',
        transition: 'none', // Explicitly disable any transitions
      }}
    >
      {children}
    </div>
  );
};

export default DashboardGrid;
