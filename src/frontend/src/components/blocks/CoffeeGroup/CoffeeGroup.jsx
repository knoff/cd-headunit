import React, { useState, useEffect, useCallback, useRef } from 'react';
import { Coffee, Flame, Power, LineChart, LayoutGrid } from 'lucide-react';
import { cn } from '../../../utils/cn';
import CardHeader from '../../ui/CardHeader';
import IconButton from '../../ui/IconButton';
import ProfileList from './ProfileList';
import ExtractionConfirmation from './ExtractionConfirmation';
import ExtractionMonitor from './ExtractionMonitor';
import ExtractionSummary from './ExtractionSummary';
import DetailedGraph from './DetailedGraph';
import { GroupStates, GroupTransitions, groupReducer } from '../../../state/machines/groupMachine';
import { useMachine } from '../../../hooks/useMachine';

const CoffeeGroup = ({
  title,
  titleShort,
  side,
  isCompact,
  isExpanded,
  isMinimal,
  onToggleExpand,
  onStartSimulation,
  onStopSimulation,
  realTimeData,
  t,
}) => {
  const [state, send] = useMachine(groupReducer, { status: GroupStates.IDLE, profile: null });

  // Хендлеры переходов
  const handleSelectProfile = (profile) => send(GroupTransitions.SELECT_PROFILE, profile);

  const handleConfirmStart = () => {
    send(GroupTransitions.CONFIRM_START);
    if (onStartSimulation && state.profile) {
      onStartSimulation(state.profile);
    }
  };
  const handleStop = () => {
    send(GroupTransitions.STOP);
    if (onStopSimulation) {
      onStopSimulation();
    }
    // Если мы были развернуты (график), сворачиваемся при ручной остановке
    if (isExpanded && onToggleExpand) {
      onToggleExpand();
    }
  };

  const handleDone = () => {
    send(GroupTransitions.BACK_TO_IDLE);
    // Сворачиваем блок при выходе из SUMMARY (если еще не свернули при handleStop)
    if (isExpanded && onToggleExpand) {
      onToggleExpand();
    }
  };

  // Синхронизация данных монитора
  useEffect(() => {
    // Изменяем условие: переходим в SUMMARY только если пролив БЫЛ активен и данные пропали,
    // либо по сигналу завершения. Для прототипа добавим небольшую задержку или проверку.
    if (state.status === GroupStates.EXTRACTING && realTimeData && realTimeData.done) {
      send(GroupTransitions.FINISH);
    }
  }, [realTimeData, state.status, send]);

  const isActive = state.status === GroupStates.EXTRACTING || state.status === GroupStates.SUMMARY;
  const contentHeight = isActive ? 'h-[10.625rem]' : 'h-[14rem]';

  return (
    <div
      className={cn(
        'flex h-full flex-col rounded-[2.5rem] bg-surface p-[1.5rem] border border-white/5 shadow-premium overflow-hidden transition-all duration-300',
        isCompact && 'p-[1.5rem]',
        isMinimal && 'px-[0.5rem] py-[1.5rem] items-center',
        isExpanded && 'bg-surface-light border-white/10'
      )}
    >
      <CardHeader
        title={title}
        titleShort={titleShort}
        subtitle={isActive && state.profile ? state.profile.name : t('standby')}
        icon={isActive ? (isExpanded ? LayoutGrid : LineChart) : Coffee}
        isCompact={isCompact}
        isMinimal={isMinimal}
        isAccent={isActive}
        onIconClick={onToggleExpand}
        centerAction={
          isExpanded && state.status === GroupStates.EXTRACTING ? (
            <IconButton
              icon={Power}
              variant="accent"
              onClick={handleStop}
              className="h-[3.5rem] w-[3.5rem] rounded-[1.25rem] shadow-glow-red"
            />
          ) : null
        }
      />

      <div
        className={cn(
          'flex-1 flex flex-col min-h-0 relative transition-all duration-300',
          isMinimal ? 'opacity-0 scale-95 pointer-events-none' : 'opacity-100 scale-100'
        )}
      >
        {isExpanded ? (
          <DetailedGraph profileName={state.profile?.name} t={t} />
        ) : (
          <>
            {state.status === GroupStates.IDLE && (
              <div className="flex flex-col h-full">
                <ProfileList onSelect={handleSelectProfile} t={t} contentHeight={contentHeight} />
                <div className="mt-auto pt-[0.5rem]">
                  <button className="flex h-[3.25rem] w-full items-center justify-center gap-[0.75rem] rounded-[1.25rem] bg-surface-light border border-white/5 text-[1.125rem] font-black font-display uppercase tracking-wider text-text-primary active:scale-[0.98] active:bg-surface-active transition-all">
                    <Flame className="w-[1.25rem] h-[1.25rem] text-accent-red" />
                    {t('flush')}
                  </button>
                </div>
              </div>
            )}

            {state.status === GroupStates.READY_TO_START && (
              <ExtractionConfirmation
                profile={state.profile}
                onConfirm={handleConfirmStart}
                onCancel={handleDone}
                t={t}
              />
            )}

            {state.status === GroupStates.EXTRACTING && (
              <ExtractionMonitor
                data={realTimeData || {}}
                t={t}
                isCompact={isCompact}
                onStop={handleStop}
                side={side}
              />
            )}

            {state.status === GroupStates.SUMMARY && (
              <ExtractionSummary
                data={realTimeData || { yield: 0, time: '0:00' }}
                profile={state.profile}
                reason={state.endReason || 'done'}
                onDone={handleDone}
                t={t}
              />
            )}
          </>
        )}
      </div>
    </div>
  );
};

export default CoffeeGroup;
