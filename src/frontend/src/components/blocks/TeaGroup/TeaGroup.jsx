import React from 'react';
import { Droplets, Thermometer, Timer } from 'lucide-react';
import { cn } from '../../../utils/cn';
import CardHeader from '../../ui/CardHeader';
import MetricRow from '../../ui/MetricRow';

const TeaGroupCard = ({ data, titleShort, isMinimal, t }) => (
  <div
    className={cn(
      'flex h-full flex-col rounded-[2.5rem] bg-surface p-[1.5rem] border border-white/5 shadow-premium overflow-hidden transition-all duration-300',
      isMinimal && 'px-[0.5rem] py-[1.5rem] items-center'
    )}
  >
    <CardHeader
      title={t('tea').toUpperCase()}
      titleShort={titleShort}
      subtitle="Дянь Хун"
      icon={Droplets}
      isCompact={false}
      isMinimal={isMinimal}
      isAccent={data.yield > 0 && data.yield < data.targetYield}
    />

    <div
      className={cn(
        'flex flex-col divide-y divide-white/5 flex-1 transition-all duration-300',
        isMinimal ? 'opacity-0 scale-95 pointer-events-none h-0' : 'opacity-100 scale-100'
      )}
    >
      <MetricRow
        label={t('temp')}
        icon={Thermometer}
        value={data.temp}
        unit={t('unit_temp')}
        compact={false}
      />
      <MetricRow label={t('time')} icon={Timer} value={data.timer} unit="" compact={false} />
    </div>

    <div
      className={cn(
        'mt-auto w-full transition-all duration-300',
        isMinimal ? 'opacity-0 scale-95' : 'opacity-100 scale-100'
      )}
    >
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
          'w-full rounded-full bg-surface-active overflow-hidden transition-all duration-500',
          isMinimal ? 'h-[1.5rem] rounded-[0.5rem]' : 'h-[0.625rem]'
        )}
      >
        <div
          className={cn(
            'h-full transition-all duration-500',
            isMinimal ? 'bg-accent-red/40' : 'bg-text-muted shadow-[0_0_15px_rgba(255,255,255,0.1)]'
          )}
          style={{ width: `${(data.yield / data.targetYield) * 100}%` }}
        />
      </div>
    </div>
  </div>
);

export default TeaGroupCard;
