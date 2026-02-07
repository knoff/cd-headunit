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
  onStartFlush,
  onStartCleaning,
  onResetGroup,
  realTimeData,
  summaryTimeout = 15,
  t,
}) => {
  // Локальные UI-состояния
  const [selectedProfile, setSelectedProfile] = useState(null);
  const [showConfirmation, setShowConfirmation] = useState(false);
  const [summarySnapshot, setSummarySnapshot] = useState(null);
  const [showSummary, setShowSummary] = useState(false);

  const serverState = realTimeData?.state || 'IDLE';
  const lastExtractionDataRef = useRef(null);
  const [isStarting, setIsStarting] = useState(false);

  // Сбрасываем флаг старта, как только сервер подтвердил начало процесса
  useEffect(() => {
    if (serverState !== 'IDLE' && isStarting) {
      setIsStarting(false);
      setShowConfirmation(false);
    }
  }, [serverState, isStarting]);

  // Сохраняем последний кадр экстракции до того, как бэкенд вышлет нули в IDLE
  useEffect(() => {
    if (serverState === 'EXTRACTION' && realTimeData) {
      lastExtractionDataRef.current = { ...realTimeData };
    }
  }, [serverState, realTimeData]);

  // Следим за переходом EXTRACTION -> IDLE для показа Summary
  const prevServerStateRef = useRef(serverState);
  useEffect(() => {
    const prev = prevServerStateRef.current;

    // Переход из EXTRACTION в DONE или STOPPED
    if (prev === 'EXTRACTION' && (serverState === 'DONE' || serverState === 'STOPPED')) {
      if (lastExtractionDataRef.current) {
        // Обязательно фиксируем финальное состояние (DONE/STOPPED) в снимке
        setSummarySnapshot({
          ...lastExtractionDataRef.current,
          state: serverState,
        });
        setShowSummary(true);
      }
    }

    // Если начался новый пролив, флаш, или сервер вернулся в IDLE (таймаут) - закрываем Summary
    if (
      (serverState === 'EXTRACTION' || serverState === 'FLUSH' || serverState === 'IDLE') &&
      showSummary
    ) {
      setShowSummary(false);
      setSummarySnapshot(null);
    }

    prevServerStateRef.current = serverState;
  }, [serverState, realTimeData, showSummary]);

  // Хендлеры
  const handleSelectProfile = (profile) => {
    setSelectedProfile(profile);
    setShowConfirmation(true);
  };

  const handleConfirmStart = () => {
    setIsStarting(true);
    if (onStartSimulation && selectedProfile) {
      onStartSimulation(selectedProfile);
    }
  };

  const handleStop = () => {
    if (onStopSimulation) {
      onStopSimulation();
    }
    if (isExpanded && onToggleExpand) {
      onToggleExpand();
    }
  };

  const handleDone = () => {
    setShowSummary(false);
    setSummarySnapshot(null);
    if (onResetGroup) onResetGroup();

    if (isExpanded && onToggleExpand) {
      onToggleExpand();
    }
  };

  const handleFlush = () => {
    if (onStartFlush) onStartFlush(side);
  };

  const isActuallyActive = serverState !== 'IDLE' || showSummary;
  const contentHeight = isActuallyActive ? 'h-[10.625rem]' : 'h-[14rem]';

  // Определяем подзаголовок
  let subtitle = t('standby');
  if (serverState === 'HEATING') subtitle = t('heating');
  if (serverState === 'EXTRACTION' && selectedProfile) subtitle = selectedProfile.name;
  if (serverState === 'CLEANING') subtitle = t('cleaning');
  if (serverState === 'FLUSH') subtitle = t('flush');
  if (serverState === 'ERROR') subtitle = t('error');
  if (serverState === 'DONE') subtitle = t('ready');
  if (serverState === 'STOPPED') subtitle = t('stopped');

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
        subtitle={subtitle}
        icon={isActuallyActive ? (isExpanded ? LayoutGrid : LineChart) : Coffee}
        isCompact={isCompact}
        isMinimal={isMinimal}
        isAccent={isActuallyActive}
        onIconClick={onToggleExpand}
        centerAction={
          isExpanded &&
          (serverState === 'EXTRACTION' ||
            serverState === 'FLUSH' ||
            serverState === 'CLEANING') ? (
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
          <DetailedGraph profileName={selectedProfile?.name} t={t} />
        ) : (
          <>
            {/* Состояние IDLE (Выбор профилей) */}
            {serverState === 'IDLE' && !showConfirmation && !showSummary && !isStarting && (
              <div className="flex flex-col h-full">
                <ProfileList onSelect={handleSelectProfile} t={t} contentHeight={contentHeight} />
                <div className="mt-auto pt-[0.5rem]">
                  <button
                    onClick={handleFlush}
                    className="flex h-[3.25rem] w-full items-center justify-center gap-[0.75rem] rounded-[1.25rem] bg-surface-light border border-white/5 text-[1.125rem] font-black font-display uppercase tracking-wider text-text-primary active:scale-[0.98] active:bg-surface-active transition-all"
                  >
                    <Flame className="w-[1.25rem] h-[1.25rem] text-accent-red" />
                    {t('flush')}
                  </button>
                </div>
              </div>
            )}

            {/* Подтверждение старта или ожидание бэкенда */}
            {(showConfirmation || isStarting) && serverState === 'IDLE' && (
              <ExtractionConfirmation
                profile={selectedProfile}
                onConfirm={handleConfirmStart}
                onCancel={() => {
                  setShowConfirmation(false);
                  setIsStarting(false);
                }}
                t={t}
                isPending={isStarting}
              />
            )}

            {/* Активная экстракция/флаш/очистка */}
            {(serverState === 'EXTRACTION' ||
              serverState === 'FLUSH' ||
              serverState === 'CLEANING') && (
              <ExtractionMonitor
                data={realTimeData || {}}
                t={t}
                isCompact={isCompact}
                onStop={handleStop}
                side={side}
              />
            )}

            {/* ERROR или HEATING */}
            {(serverState === 'ERROR' || serverState === 'HEATING') && !showSummary && (
              <div className="flex-1 flex flex-col items-center justify-center gap-[1rem]">
                <div
                  className={cn(
                    'w-[4rem] h-[4rem] rounded-full flex items-center justify-center',
                    serverState === 'ERROR'
                      ? 'bg-accent-red/20 text-accent-red'
                      : 'bg-white/10 text-text-muted animate-pulse'
                  )}
                >
                  {serverState === 'ERROR' ? (
                    <Power className="w-[2rem] h-[2rem]" />
                  ) : (
                    <Flame className="w-[2rem] h-[2rem]" />
                  )}
                </div>
                <span className="text-[1.25rem] font-bold uppercase tracking-tight">
                  {subtitle}
                </span>
              </div>
            )}

            {/* SUMMARY (Оверлей) */}
            {showSummary && (
              <ExtractionSummary
                data={summarySnapshot || { yield: 0, time: '0:00' }}
                profile={selectedProfile}
                reason={summarySnapshot?.state === 'DONE' ? 'done' : 'cancelled'}
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
