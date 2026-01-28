import React from 'react';
import { Thermometer, Waves, Activity, Droplet, Zap, Power } from 'lucide-react';
import MetricRow from '../../ui/MetricRow';
import IconButton from '../../ui/IconButton';

const ExtractionMonitor = ({ data, t, isCompact, onStop, side }) => {
  return (
    <div className="flex flex-col h-full animate-in fade-in duration-500">
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
        <div className="flex-1">
          <div className="flex justify-between items-end mb-[0.5rem]">
            <span className="text-[1.875rem] font-black font-display text-text-primary italic leading-none">
              {data.yield}/{data.targetYield}
              {t('unit_yield')}
            </span>
            <span className="text-[1.5rem] font-bold text-accent-red font-display transition-all mb-1">
              {data.time}
            </span>
          </div>
          <div className="h-[0.75rem] w-full rounded-full bg-surface-active overflow-hidden">
            <div
              className="h-full bg-accent-red shadow-[0_0_20px_rgba(240,68,56,0.3)] transition-all duration-300"
              style={{
                width: `${Math.min((data.yield / data.targetYield) * 100, 100)}%`,
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
};

export default ExtractionMonitor;
