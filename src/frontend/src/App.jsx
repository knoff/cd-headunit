import React, { useState, useEffect } from 'react';
import { Settings, Bell, List, Power } from 'lucide-react';
import IconButton from './components/ui/IconButton';
import DashboardGrid from './components/layout/DashboardGrid';
import CoffeeGroup from './components/blocks/CoffeeGroup/CoffeeGroup';
import TeaGroupCard from './components/blocks/TeaGroup/TeaGroup';
import AuxiliaryBlock from './components/blocks/Auxiliary/AuxiliaryBlock';
import { useMachine } from './hooks/useMachine';
import { AppStates, AppTransitions, appReducer } from './state/machines/appMachine';
import { TRANSLATIONS } from './constants/translations';
import { KeyboardProvider } from './hooks/useKeyboard';
import { RealTimeDataProvider, useRealTimeData } from './state/RealTimeDataContext';
import VirtualKeyboard from './components/ui/Keyboard/VirtualKeyboard';
import SettingsView from './views/Settings/SettingsView';

const App = () => {
  const [time, setTime] = useState(new Date());
  const [systemStatus, setSystemStatus] = useState({ status: 'ok', version: '0.1.2' });
  const [uiSettings, setUiSettings] = useState(() => {
    const saved = localStorage.getItem('hu_ui_settings');
    return saved ? JSON.parse(saved) : { language: 'ru', summary_timeout: 15 };
  });

  const language = uiSettings.language;
  const summaryTimeout = uiSettings.summary_timeout;

  const [appState, sendApp] = useMachine(appReducer, AppStates.DASHBOARD);
  const {
    left,
    right,
    tea,
    startSimulation,
    stopSimulation,
    startFlush,
    startCleaning,
    resetGroup,
  } = useRealTimeData();

  useEffect(() => {
    const timer = setInterval(() => setTime(new Date()), 1000);

    // Fetch version from backend
    fetch('/api/health')
      .then((r) => r.json())
      .then((data) => {
        setSystemStatus({ status: data.status, version: data.version });
      })
      .catch((e) => console.error('[APP] Health check failed:', e));

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
        <CoffeeGroup
          side="left"
          title={t('group_l')}
          titleShort={t('group_l_short')}
          isCompact={
            (appState === AppStates.FOCUS_RIGHT || appState === AppStates.FOCUS_BOTH) &&
            appState !== AppStates.SYSTEM_EXPANDED
          }
          isExpanded={appState === AppStates.FOCUS_LEFT || appState === AppStates.FOCUS_BOTH}
          isMinimal={appState === AppStates.SYSTEM_EXPANDED}
          onToggleExpand={() => sendApp(AppTransitions.TOGGLE_EXPAND_LEFT)}
          onStartSimulation={(profile) => startSimulation('left', profile)}
          onStopSimulation={() => stopSimulation('left')}
          onStartFlush={() => startFlush('left')}
          onStartCleaning={() => startCleaning('left')}
          onResetGroup={() => resetGroup('left')}
          realTimeData={left}
          summaryTimeout={summaryTimeout}
          t={t}
        />

        <TeaGroupCard
          data={tea}
          titleShort={t('tea_short')}
          isMinimal={appState === AppStates.FOCUS_BOTH || appState === AppStates.SYSTEM_EXPANDED}
          t={t}
        />

        <div className="flex flex-col items-center p-[2rem] bg-surface-active/20 rounded-[2rem] border border-white/5 overflow-hidden transition-all">
          <div className="flex flex-1 flex-col justify-start items-center gap-[1.25rem]">
            <IconButton
              icon={Settings}
              size="w-[1.75rem] h-[1.75rem]"
              className="h-[4.5rem] w-[4.5rem] rounded-[1.75rem]"
              onClick={() => {
                const isLeftActive = left?.state !== 'IDLE' && left?.state !== undefined;
                const isRightActive = right?.state !== 'IDLE' && right?.state !== undefined;
                if (!isLeftActive && !isRightActive) {
                  sendApp(AppTransitions.TOGGLE_SYSTEM);
                }
              }}
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

        <AuxiliaryBlock
          time={formattedTime}
          date={formattedDate}
          status={systemStatus}
          isMinimal={
            appState === AppStates.FOCUS_LEFT ||
            appState === AppStates.FOCUS_RIGHT ||
            appState === AppStates.FOCUS_BOTH
          }
          isExpanded={appState === AppStates.SYSTEM_EXPANDED}
          onToggleExpand={() => sendApp(AppTransitions.TOGGLE_SYSTEM)}
          t={t}
        />

        <CoffeeGroup
          side="right"
          title={t('group_r')}
          titleShort={t('group_r_short')}
          isCompact={
            (appState === AppStates.FOCUS_LEFT || appState === AppStates.FOCUS_BOTH) &&
            appState !== AppStates.SYSTEM_EXPANDED
          }
          isExpanded={appState === AppStates.FOCUS_RIGHT || appState === AppStates.FOCUS_BOTH}
          isMinimal={appState === AppStates.SYSTEM_EXPANDED}
          onToggleExpand={() => sendApp(AppTransitions.TOGGLE_EXPAND_RIGHT)}
          onStartSimulation={(profile) => startSimulation('right', profile)}
          onStopSimulation={() => stopSimulation('right')}
          onStartFlush={() => startFlush('right')}
          onStartCleaning={() => startCleaning('right')}
          onResetGroup={() => resetGroup('right')}
          realTimeData={right}
          summaryTimeout={summaryTimeout}
          t={t}
        />
      </DashboardGrid>

      {appState === AppStates.SYSTEM_EXPANDED && (
        <div className="fixed inset-0 z-50 p-[3rem] bg-black/80 flex items-center justify-center animate-in fade-in duration-300">
          <div className="w-full max-w-[80rem]">
            <SettingsView
              onClose={() => sendApp(AppTransitions.TOGGLE_SYSTEM)}
              t={t}
              uiSettings={uiSettings}
              onUpdateUiSettings={(newSettings) => {
                setUiSettings(newSettings);
                localStorage.setItem('hu_ui_settings', JSON.stringify(newSettings));
              }}
            />
          </div>
        </div>
      )}

      <VirtualKeyboard t={t} />
    </div>
  );
};

const AppWrapper = () => (
  <KeyboardProvider>
    <RealTimeDataProvider>
      <App />
    </RealTimeDataProvider>
  </KeyboardProvider>
);

export default AppWrapper;
