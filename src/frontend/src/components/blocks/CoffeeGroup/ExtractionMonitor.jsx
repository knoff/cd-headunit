import React, { memo } from 'react';
import { Thermometer, Waves, Activity, Droplet, Zap, Power } from 'lucide-react';
import MetricRow from '../../ui/MetricRow';
import IconButton from '../../ui/IconButton';

const ExtractionMonitor = memo(({ data, t, isCompact, onStop, side }) => {
  const progressScale = Math.min(data.yield / data.targetYield || 0, 1);

  return (
    <div className="flex flex-col h-full">
      <div className="grid grid-cols-2 gap-x-[1.5rem] gap-y-[1.25rem] mb-[1.5rem]">
        <MetricRow
          label={t('temp')}
          icon={Thermometer}
          value={data.temp}
          unit={t('unit_temp')}
          compact={isCompact}
        />
        <MetricRow
          label={t('flow_in')}
          icon={Waves}
          value={data.flowIn}
          unit={t('unit_flow')}
          compact={isCompact}
        />
        <MetricRow
          label={t('press')}
          icon={Activity}
          value={data.pressure}
          unit={t('unit_press')}
          compact={isCompact}
        />
        <MetricRow
          label={t('flow_out')}
          icon={Droplet}
          value={data.flowOut}
          unit={t('unit_flow')}
          compact={isCompact}
        />
      </div>
      <div className="flex justify-center mb-[2rem]">
        <MetricRow
          label={t('energy')}
          icon={Zap}
          value={data.energy}
          unit={t('unit_energy')}
          compact={isCompact}
        />
      </div>

      <div className="mt-auto flex items-end gap-[1rem]">
        <div className="flex-1 min-w-0">
          <div className="flex justify-between items-end mb-[0.5rem] overflow-hidden">
            <span className="text-[1.875rem] font-black font-display text-text-primary italic leading-none whitespace-nowrap">
              {data.yield}/{data.targetYield}
              {t('unit_yield')}
            </span>
            <span className="text-[1.5rem] font-bold text-accent-red font-display mb-1 flex-shrink-0">
              {data.time}
            </span>
          </div>
          <div className="h-[0.75rem] w-full rounded-full bg-surface-active overflow-hidden relative">
            <div
              className="h-full bg-accent-red shadow-[0_0_20px_rgba(240,68,56,0.3)] will-change-transform"
              style={{
                width: '100%',
                transform: `scaleX(${progressScale})`,
                transformOrigin: 'left',
                transition: 'transform 0.1s linear', // Match tick rate roughly
              }}
            />
          </div>
        </div>
        {!isCompact && (
          <IconButton
            icon={Power}
            variant="accent"
            onClick={() => onStop(side)}
            className="h-[3.5rem] w-[3.5rem] rounded-[1.25rem]"
          />
        )}
      </div>
    </div>
  );
});

ExtractionMonitor.displayName = 'ExtractionMonitor';

export default ExtractionMonitor;
