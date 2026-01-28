import React from 'react';
import { Droplets, Thermometer, Timer } from 'lucide-react';
import { cn } from '../../../utils/cn';
import CardHeader from '../../ui/CardHeader';
import MetricRow from '../../ui/MetricRow';

const TeaGroupCard = ({ data, isMinimal, t }) => (
  <div
    className={cn(
      'flex h-full flex-col rounded-[2.5rem] bg-surface p-[1.5rem] border border-white/5 shadow-premium overflow-hidden transition-all duration-500',
      isMinimal && 'px-[1rem] pt-[1.5rem]'
    )}
  >
    <CardHeader
      title={isMinimal ? t('tea').toUpperCase() : 'Дянь Хун'}
      subtitle="Мао Фэн 85°C"
      icon={Droplets}
      isCompact={isMinimal}
    />

    <div className="flex flex-col divide-y divide-white/5">
      <MetricRow
        label={t('temp')}
        icon={Thermometer}
        value={data.temp}
        unit={t('unit_temp')}
        compact={isMinimal}
      />
      <MetricRow label={t('time')} icon={Timer} value={data.timer} unit="" compact={isMinimal} />
    </div>

    <div className={cn('mt-auto', isMinimal ? 'pt-[0.5rem]' : 'pt-[1.5rem]')}>
      {!isMinimal && (
        <div className="flex justify-between items-end mb-[0.5rem]">
          <span className="text-[1.5rem] font-black font-display text-text-primary italic">
            {data.yield}/{data.targetYield}
            {t('unit_yield')}
          </span>
        </div>
      )}
      <div
        className={cn(
          'w-full rounded-full bg-surface-active overflow-hidden',
          isMinimal ? 'h-[0.5rem]' : 'h-[0.625rem]'
        )}
      >
        <div
          className="h-full bg-text-muted shadow-[0_0_15px_rgba(255,255,255,0.1)] transition-all"
          style={{ width: `${(data.yield / data.targetYield) * 100}%` }}
        />
      </div>
    </div>
  </div>
);

export default TeaGroupCard;
