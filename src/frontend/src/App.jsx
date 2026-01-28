import React, { useState, useEffect, useRef } from 'react';
import { Settings, Bell, List, Power } from 'lucide-react';
import IconButton from './components/ui/IconButton';
import DashboardGrid from './components/layout/DashboardGrid';
import CoffeeGroup from './components/blocks/CoffeeGroup/CoffeeGroup';
import TeaGroupCard from './components/blocks/TeaGroup/TeaGroup';
import AuxiliaryBlock from './components/blocks/Auxiliary/AuxiliaryBlock';
import { useMachine } from './hooks/useMachine';
import { AppStates, AppTransitions, appReducer } from './state/machines/appMachine';
import { TRANSLATIONS } from './constants/translations';

// Репликация хука данных для совместимости с текущим состоянием симуляции
const useRealTimeData = () => {
  const [leftData, setLeftData] = useState(null);
  const [rightData, setRightData] = useState(null);
  const [teaData, setTeaData] = useState({
    temp: 84.1,
    timer: '2:10',
    yield: 250,
    targetYield: 500,
  });

  // Используем useRef для хранения идентификаторов интервалов
  const leftInterval = useRef(null);
  const rightInterval = useRef(null);

  const interpolate = (t, points, key) => {
    if (!points || points.length === 0) return 0;
    if (t <= points[0].t) return points[0][key];
    if (t >= points[points.length - 1].t) return points[points.length - 1][key];

    for (let i = 0; i < points.length - 1; i++) {
      const p0 = points[i];
      const p1 = points[i + 1];
      if (t >= p0.t && t <= p1.t) {
        const ratio = (t - p0.t) / (p1.t - p0.t);
        return p0[key] + (p1[key] - p0[key]) * ratio;
      }
    }
    return 0;
  };

  const addNoise = (val, percent = 0.02) => {
    const noise = val * percent * (Math.random() * 2 - 1);
    return val + noise;
  };

  const round = (val) => Math.round(val * 10) / 10;

  const stopSimulation = (side) => {
    if (side === 'left' && leftInterval.current) {
      clearInterval(leftInterval.current);
      leftInterval.current = null;
    } else if (side === 'right' && rightInterval.current) {
      clearInterval(rightInterval.current);
      rightInterval.current = null;
    }
  };

  const startSimulation = (side, profile) => {
    const setData = side === 'left' ? setLeftData : setRightData;

    // Важно: Сначала останавливаем любой текущий процесс для этой стороны
    stopSimulation(side);

    const intervalBucket = side === 'left' ? leftInterval : rightInterval;
    let elapsedMs = 0;
    let currentYieldAccumulator = 0;
    const startTime = Date.now();
    const tickRate = 100;

    intervalBucket.current = setInterval(() => {
      // Если интервал был очищен в процессе, выходим
      if (!intervalBucket.current) return;

      const now = Date.now();
      elapsedMs = now - startTime;
      const t = elapsedMs / 1000;

      const lastPoint = profile.points[profile.points.length - 1];
      const isDone = t >= lastPoint.t;

      const baseTemp = interpolate(t, profile.points, 'temp');
      const basePress = interpolate(t, profile.points, 'press');
      const baseFlowIn = interpolate(t, profile.points, 'flowIn');
      const baseFlowOut = interpolate(t, profile.points, 'flowOut');
      const baseEnergy = interpolate(t, profile.points, 'energy');

      currentYieldAccumulator += baseFlowOut * (tickRate / 1000);

      const result = {
        temp: round(addNoise(baseTemp, 0.005)),
        pressure: round(addNoise(basePress, 0.02)),
        flowIn: round(addNoise(baseFlowIn, 0.02)),
        flowOut: round(addNoise(baseFlowOut, 0.02)),
        energy: round(addNoise(baseEnergy, 0.01)),
        yield: round(currentYieldAccumulator),
        targetYield: profile.targetYield,
        time: `${Math.floor(t / 60)}:${Math.floor(t % 60)
          .toString()
          .padStart(2, '0')}`,
        done: isDone,
      };

      setData(result);

      if (isDone) {
        stopSimulation(side);
      }
    }, tickRate);
  };

  // Очистка при размонтировании
  useEffect(() => {
    return () => {
      stopSimulation('left');
      stopSimulation('right');
    };
  }, []);

  return {
    left: leftData,
    right: rightData,
    tea: teaData,
    startSimulation,
    stopSimulation,
  };
};

const App = () => {
  const [time, setTime] = useState(new Date());
  const [systemStatus, setSystemStatus] = useState({ status: 'ok', version: '0.1.0' });
  const [language, setLanguage] = useState('ru');

  const [appState, sendApp] = useMachine(appReducer, AppStates.DASHBOARD);
  const { left, right, tea, startSimulation, stopSimulation } = useRealTimeData();

  useEffect(() => {
    const timer = setInterval(() => setTime(new Date()), 1000);
    return () => clearInterval(timer);
  }, []);

  const t = (key) => TRANSLATIONS[language][key] || key;

  const formattedTime = time.toLocaleTimeString(language === 'ru' ? 'ru-RU' : 'en-US', {
    hour: '2-digit',
    minute: '2-digit',
  });
  const formattedDate = time.toLocaleDateString(language === 'ru' ? 'ru-RU' : 'en-US', {
    day: 'numeric',
    month: 'long',
  });

  return (
    <div className="app-viewport flex items-stretch p-[1.5rem] font-sans select-none overflow-hidden bg-black text-text-primary">
      <DashboardGrid activeState={appState}>
        {/* BLOCK 1: LEFT COFFEE GROUP */}
        <CoffeeGroup
          side="left"
          title={t('group_l')}
          isCompact={
            appState !== AppStates.DASHBOARD &&
            appState !== AppStates.FOCUS_LEFT &&
            appState !== AppStates.FOCUS_BOTH
          }
          isExpanded={appState === AppStates.FOCUS_LEFT || appState === AppStates.FOCUS_BOTH}
          isMinimal={appState === AppStates.SYSTEM_EXPANDED}
          onToggleExpand={() => sendApp(AppTransitions.TOGGLE_EXPAND_LEFT)}
          onStartSimulation={(profile) => startSimulation('left', profile)}
          onStopSimulation={() => stopSimulation('left')}
          realTimeData={left}
          t={t}
        />

        {/* BLOCK 2: TEA GROUP */}
        <TeaGroupCard data={tea} isMinimal={appState !== AppStates.DASHBOARD} t={t} />

        {/* BLOCK 3: CENTRAL SYSTEM PANEL */}
        <div className="flex flex-col items-center p-[2rem] bg-surface-active/20 rounded-[2rem] border border-white/5 backdrop-blur-md overflow-hidden transition-all">
          <div className="flex flex-1 flex-col justify-start items-center gap-[1.25rem]">
            <IconButton
              icon={Settings}
              size="w-[1.75rem] h-[1.75rem]"
              className="h-[4.5rem] w-[4.5rem] rounded-[1.75rem]"
            />
            <IconButton
              icon={Bell}
              size="w-[1.75rem] h-[1.75rem]"
              className="h-[4.5rem] w-[4.5rem] rounded-[1.75rem]"
            />
            <IconButton
              icon={List}
              size="w-[1.75rem] h-[1.75rem]"
              className="h-[4.5rem] w-[4.5rem] rounded-[1.75rem]"
            />
            <IconButton
              icon={Power}
              size="w-[1.75rem] h-[1.75rem]"
              className="h-[4.5rem] w-[4.5rem] rounded-[1.75rem]"
              onClick={() => sendApp(AppTransitions.RESET_VIEW)}
            />
          </div>
        </div>

        {/* BLOCK 4: AUXILIARY BLOCK (SYSTEM STATUS & TIME) */}
        <AuxiliaryBlock
          time={formattedTime}
          date={formattedDate}
          status={systemStatus}
          isMinimal={appState !== AppStates.DASHBOARD && appState !== AppStates.SYSTEM_EXPANDED}
          isExpanded={appState === AppStates.SYSTEM_EXPANDED}
          onToggleExpand={() => sendApp(AppTransitions.TOGGLE_SYSTEM)}
          t={t}
        />

        {/* BLOCK 5: RIGHT COFFEE GROUP */}
        <CoffeeGroup
          side="right"
          title={t('group_r')}
          isCompact={
            appState !== AppStates.DASHBOARD &&
            appState !== AppStates.FOCUS_RIGHT &&
            appState !== AppStates.FOCUS_BOTH
          }
          isExpanded={appState === AppStates.FOCUS_RIGHT || appState === AppStates.FOCUS_BOTH}
          isMinimal={appState === AppStates.SYSTEM_EXPANDED}
          onToggleExpand={() => sendApp(AppTransitions.TOGGLE_EXPAND_RIGHT)}
          onStartSimulation={(profile) => startSimulation('right', profile)}
          onStopSimulation={() => stopSimulation('right')}
          realTimeData={right}
          t={t}
        />
      </DashboardGrid>
    </div>
  );
};

export default App;
