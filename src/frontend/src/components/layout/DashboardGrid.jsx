import React, { useMemo } from 'react';
import { AppStates } from '../../state/machines/appMachine';

const DashboardGrid = ({ children, activeState }) => {
  const gridTemplate = useMemo(() => {
    const compactWidth = '15rem';
    const centerWidth = '7.5rem';
    const expandedWidth = '1fr';
    const normalL = '1fr';
    const normalAux = '0.7fr';

    switch (activeState) {
      case AppStates.FOCUS_LEFT:
        return `${expandedWidth} ${compactWidth} ${centerWidth} ${compactWidth} ${compactWidth}`;
      case AppStates.FOCUS_RIGHT:
        return `${compactWidth} ${compactWidth} ${centerWidth} ${compactWidth} ${expandedWidth}`;
      case AppStates.FOCUS_BOTH:
        return `${expandedWidth} ${compactWidth} ${centerWidth} ${compactWidth} ${expandedWidth}`;
      case AppStates.SYSTEM_EXPANDED:
        return `${compactWidth} ${compactWidth} ${centerWidth} ${expandedWidth} ${compactWidth}`;
      default:
        return `${normalL} ${normalAux} ${centerWidth} ${normalAux} ${normalL}`;
    }
  }, [activeState]);

  return (
    <div
      className="grid-cols-5-segment w-full gap-[1.5rem] transition-all duration-700 ease-in-out"
      style={{
        display: 'grid',
        gridTemplateColumns: gridTemplate,
        width: '100%',
      }}
    >
      {children}
    </div>
  );
};

export default DashboardGrid;
