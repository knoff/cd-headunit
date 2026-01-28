import React, { useState, useEffect, useMemo, useRef, useCallback } from 'react';
import {
  Bell,
  List,
  Settings,
  Power,
  ChevronRight,
  Thermometer,
  Zap,
  Droplets,
  Droplet,
  Waves,
  Timer,
  User,
  Coffee,
  History as HistoryIcon,
  Flame,
  Wind,
  Activity,
  LineChart,
  LayoutGrid,
} from 'lucide-react';
import { clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';
import { ResponsiveContainer, AreaChart, Area, XAxis, YAxis, CartesianGrid } from 'recharts';

function cn(...inputs) {
  return twMerge(clsx(inputs));
}

// --- i18n ---

const TRANSLATIONS = {
  ru: {
    group_l: 'Группа 1',
    group_r: 'Группа 2',
    tea: 'Чай',
    history: 'История',
    hist_short: 'ИСТ',
    recent_brews: 'Последние проливы',
    select_profile: 'Выбор профиля',
    select: 'Выбрать',
    temp: 'Температура',
    press: 'Давление',
    flow_in: 'Поток вх.',
    flow_out: 'Поток вых.',
    energy: 'Энергия',
    time: 'Время',
    yield: 'Объем',
    unit_temp: '°C',
    unit_press: 'бар',
    unit_flow: 'мл/с',
    unit_energy: 'Вт',
    unit_yield: 'мл',
    start: 'СТАРТ',
    finish: 'ФИНИШ',
    connecting: 'Подключение',
    ok: 'ОК',
    error: 'Ошибка',
    version: 'Версия',
    standby: 'Ожидание',
    flush: 'Пролив',
  },
  en: {
    group_l: 'Group 1',
    group_r: 'Group 2',
    tea: 'Tea',
    history: 'History',
    hist_short: 'HIST',
    recent_brews: 'Recent brews',
    select_profile: 'Select Profile',
    select: 'Select',
    temp: 'Temperature',
    press: 'Pressure',
    flow_in: 'Flow In',
    flow_out: 'Flow Out',
    energy: 'Energy',
    time: 'Time',
    yield: 'Yield',
    unit_temp: '°C',
    unit_press: 'bar',
    unit_flow: 'ml/s',
    unit_energy: 'W',
    unit_yield: 'ml',
    start: 'START',
    finish: 'FINISH',
    connecting: 'Connecting',
    ok: 'OK',
    error: 'Error',
    version: 'Version',
    standby: 'Standby',
    flush: 'Flush',
  },
};

// --- CONSTANTS & MOCK DATA ---

const COFFEE_PROFILES = [
  {
    id: 1,
    name: 'Classic Espresso',
    desc: 'Balanced and sweet',
    targetYield: 36,
    points: [
      { t: 0, temp: 92, press: 0, flowIn: 0, flowOut: 0, energy: 0 },
      { t: 2, temp: 93, press: 3, flowIn: 1, flowOut: 0, energy: 1200 },
      { t: 5, temp: 94, press: 9, flowIn: 2, flowOut: 1.5, energy: 1500 },
      { t: 25, temp: 94, press: 9, flowIn: 2.2, flowOut: 2.2, energy: 1000 },
      { t: 30, temp: 93, press: 6, flowIn: 1.5, flowOut: 1.5, energy: 400 },
    ],
  },
  {
    id: 2,
    name: 'Ristretto Intense',
    desc: 'Short and powerful',
    targetYield: 18,
    points: [
      { t: 0, temp: 94, press: 0, flowIn: 0, flowOut: 0, energy: 0 },
      { t: 3, temp: 94, press: 10, flowIn: 1.5, flowOut: 1.0, energy: 1600 },
      { t: 15, temp: 95, press: 10, flowIn: 1.5, flowOut: 1.5, energy: 1400 },
      { t: 20, temp: 94, press: 5, flowIn: 0.5, flowOut: 0.5, energy: 200 },
    ],
  },
  {
    id: 3,
    name: 'Acidic Punch',
    desc: 'High acidity, light roast',
    targetYield: 40,
    points: [
      { t: 0, temp: 88, press: 0, flowIn: 0, flowOut: 0, energy: 0 },
      { t: 8, temp: 90, press: 4, flowIn: 3, flowOut: 0.5, energy: 1800 },
      { t: 22, temp: 92, press: 8, flowIn: 2.5, flowOut: 2.5, energy: 1400 },
      { t: 35, temp: 90, press: 2, flowIn: 1, flowOut: 1, energy: 400 },
    ],
  },
  {
    id: 4,
    name: 'Long Black',
    desc: 'Soft and aromatic',
    targetYield: 120,
    points: [
      { t: 0, temp: 92, press: 0, flowIn: 0, flowOut: 0, energy: 0 },
      { t: 5, temp: 92, press: 7, flowIn: 2, flowOut: 1.8, energy: 1200 },
      { t: 40, temp: 92, press: 7, flowIn: 2.5, flowOut: 2.5, energy: 1200 },
      { t: 45, temp: 90, press: 0, flowIn: 0, flowOut: 0, energy: 0 },
    ],
  },
  {
    id: 5,
    name: 'Gentle Pre-infusion',
    desc: 'Long pre-wetting',
    targetYield: 34,
    points: [
      { t: 0, temp: 93, press: 0, flowIn: 0, flowOut: 0, energy: 0 },
      { t: 10, temp: 93, press: 2, flowIn: 0.5, flowOut: 0, energy: 1400 },
      { t: 15, temp: 93, press: 9, flowIn: 2, flowOut: 1.5, energy: 1600 },
      { t: 35, temp: 93, press: 8, flowIn: 2.2, flowOut: 2.2, energy: 1000 },
    ],
  },
  {
    id: 6,
    name: 'Dark Roast Soul',
    desc: 'Low temp, heavy body',
    targetYield: 32,
    points: [
      { t: 0, temp: 88, press: 0, flowIn: 0, flowOut: 0, energy: 0 },
      { t: 4, temp: 89, press: 9, flowIn: 1.8, flowOut: 1.5, energy: 1400 },
      { t: 28, temp: 89, press: 9, flowIn: 2.0, flowOut: 2.0, energy: 1000 },
    ],
  },
  {
    id: 7,
    name: 'Flow Control Test',
    desc: 'Manual flow simulation',
    targetYield: 45,
    points: [
      { t: 0, temp: 93, press: 0, flowIn: 0, flowOut: 0, energy: 0 },
      { t: 5, temp: 93, press: 6, flowIn: 1.0, flowOut: 0.5, energy: 1300 },
      { t: 15, temp: 93, press: 9, flowIn: 3.0, flowOut: 3.0, energy: 1600 },
      { t: 25, temp: 93, press: 7, flowIn: 1.5, flowOut: 1.5, energy: 1200 },
      { t: 35, temp: 93, press: 4, flowIn: 0.5, flowOut: 0.5, energy: 800 },
    ],
  },
  {
    id: 8,
    name: 'Helsinki Style',
    desc: 'Very light, very fast',
    targetYield: 50,
    points: [
      { t: 0, temp: 95, press: 0, flowIn: 0, flowOut: 0, energy: 0 },
      { t: 3, temp: 96, press: 7, flowIn: 4, flowOut: 4, energy: 1800 },
      { t: 18, temp: 96, press: 6, flowIn: 4.5, flowOut: 4.5, energy: 1400 },
    ],
  },
  {
    id: 9,
    name: 'Italian tradition',
    desc: 'Classic 9 bar',
    targetYield: 30,
    points: [
      { t: 0, temp: 90, press: 0, flowIn: 0, flowOut: 0, energy: 0 },
      { t: 2, temp: 91, press: 9, flowIn: 1.5, flowOut: 1.0, energy: 1200 },
      { t: 25, temp: 92, press: 9, flowIn: 2.0, flowOut: 2.0, energy: 1100 },
      { t: 28, temp: 90, press: 0, flowIn: 0, flowOut: 0, energy: 0 },
    ],
  },
  {
    id: 10,
    name: 'Experimental #9',
    desc: 'Variable pressure profile',
    targetYield: 42,
    points: [
      { t: 0, temp: 92, press: 2, flowIn: 0, flowOut: 0, energy: 0 },
      { t: 10, temp: 93, press: 4, flowIn: 1, flowOut: 0.5, energy: 1400 },
      { t: 20, temp: 94, press: 9, flowIn: 2, flowOut: 2, energy: 1600 },
      { t: 30, temp: 93, press: 11, flowIn: 3, flowOut: 3, energy: 1400 },
      { t: 40, temp: 92, press: 5, flowIn: 1, flowOut: 1, energy: 300 },
    ],
  },
];

const mockGraphData = Array.from({ length: 40 }, (_, i) => ({
  time: i,
  value: 40 + Math.sin(i / 5) * 20 + (i > 20 ? 20 : 0),
  target: 45 + Math.sin(i / 5) * 18 + (i > 20 ? 15 : 0),
}));

// --- SIMULATION HOOK ---

const useRealTimeData = () => {
  const [leftState, setLeftState] = useState({ profile: null, startTime: null, currentData: null });
  const [rightState, setRightState] = useState({
    profile: null,
    startTime: null,
    currentData: null,
  });
  const [teaData, setTeaData] = useState({
    temp: 84.2,
    targetTemp: 85.0,
    yield: 240,
    targetYield: 500,
    timer: '2:15',
    targetTimer: '3:00',
  });

  const simulateGroup = (state, setState) => {
    if (!state.profile || !state.startTime) return;

    const elapsed = (Date.now() - state.startTime) / 1000;
    const profile = state.profile;
    const lastPoint = profile.points[profile.points.length - 1];

    if (elapsed > lastPoint.t) {
      setState({ profile: null, startTime: null, currentData: null });
      return;
    }

    // Find surrounding points
    let p1 = profile.points[0];
    let p2 = profile.points[0];
    for (let i = 0; i < profile.points.length - 1; i++) {
      if (elapsed >= profile.points[i].t && elapsed <= profile.points[i + 1].t) {
        p1 = profile.points[i];
        p2 = profile.points[i + 1];
        break;
      }
    }

    const ratio = p1.t === p2.t ? 0 : (elapsed - p1.t) / (p2.t - p1.t);
    const lerp = (v1, v2) => v1 + (v2 - v1) * ratio;
    const jitter = (v, range) => v + (Math.random() * range - range / 2);

    const flowOut = lerp(p1.flowOut, p2.flowOut);
    const estimatedYield = elapsed * flowOut * 0.9;

    const currentData = {
      profileName: profile.name,
      temp: Number(jitter(lerp(p1.temp, p2.temp), 0.4).toFixed(1)),
      pressure: Number(jitter(lerp(p1.press, p2.press), 0.2).toFixed(1)),
      flowIn: Number(jitter(lerp(p1.flowIn, p2.flowIn), 0.1).toFixed(1)),
      flowOut: Number(jitter(flowOut, 0.1).toFixed(1)),
      energy: Math.floor(jitter(lerp(p1.energy, p2.energy), 50)),
      time: `0:${Math.floor(elapsed).toString().padStart(2, '0')}`,
      targetTime: `0:${Math.floor(lastPoint.t).toString().padStart(2, '0')}`,
      yield: Number(Math.min(estimatedYield, profile.targetYield).toFixed(0)),
      targetYield: profile.targetYield,
      active: true,
    };

    setState((prev) => ({ ...prev, currentData }));
  };

  useEffect(() => {
    const interval = setInterval(() => {
      simulateGroup(leftState, setLeftState);
      simulateGroup(rightState, setRightState);

      setTeaData((prev) => ({
        ...prev,
        temp: Number((prev.temp + (Math.random() * 0.1 - 0.05)).toFixed(1)),
      }));
    }, 200);
    return () => clearInterval(interval);
  }, [leftState, rightState]);

  const startExtraction = (side, profile) => {
    const setter = side === 'left' ? setLeftState : setRightState;
    setter({ profile, startTime: Date.now(), currentData: null });
  };

  const stopExtraction = (side) => {
    const setter = side === 'left' ? setLeftState : setRightState;
    setter({ profile: null, startTime: null, currentData: null });
  };

  return {
    left: leftState.currentData,
    right: rightState.currentData,
    tea: teaData,
    startExtraction,
    stopExtraction,
  };
};

// --- COMPONENTS ---

const IconButton = ({ icon: Icon, variant = 'default', className, onClick, size = 'w-6 h-6' }) => {
  const variants = {
    default: 'bg-surface-light text-text-primary active:bg-surface-active',
    accent:
      'bg-accent-red text-white shadow-[0_0.625rem_1.875rem_-0.625rem_rgba(240,68,56,0.2)] active:brightness-110',
    ghost: 'bg-transparent text-text-muted active:text-text-primary active:bg-white/5',
  };

  return (
    <button
      onClick={onClick}
      className={cn(
        'flex h-[3rem] w-[3rem] items-center justify-center rounded-[1rem] active:scale-95 shrink-0 transition-transform',
        variants[variant],
        className
      )}
    >
      <Icon className={size} strokeWidth={2.5} />
    </button>
  );
};

const MetricRow = ({
  icon: Icon,
  label,
  value,
  unit,
  compact = false,
  colorClass = 'text-text-primary',
}) => (
  <div className={cn('flex items-center justify-between', compact ? 'h-[2rem]' : 'h-[3.5rem]')}>
    <div className="flex items-center gap-[1rem] overflow-hidden">
      <div
        className={cn(
          'flex items-center justify-center rounded-[0.75rem] bg-surface-active/50 text-text-secondary shrink-0',
          compact ? 'h-[1.5rem] w-[1.5rem]' : 'h-[2.5rem] w-[2.5rem]'
        )}
      >
        <Icon className={compact ? 'w-[0.75rem] h-[0.75rem]' : 'w-[1.125rem] h-[1.125rem]'} />
      </div>
      <div className="flex flex-col">
        {!compact && (
          <span className="text-[0.625rem] font-black uppercase text-text-muted tracking-wide leading-tight">
            {label}
          </span>
        )}
        <div className="flex items-baseline gap-[0.375rem] overflow-hidden">
          <span
            className={cn(
              'font-display font-black truncate transition-all',
              compact ? 'text-[1.125rem]' : 'text-[1.375rem]',
              colorClass
            )}
          >
            {value !== undefined ? value : '--.-'}
          </span>
          <span
            className={cn(
              'font-bold text-text-muted transition-all',
              compact ? 'text-[0.625rem]' : 'text-[0.75rem]'
            )}
          >
            {unit}
          </span>
        </div>
      </div>
    </div>
  </div>
);

const CardHeader = ({
  title,
  subtitle,
  icon: Icon,
  isCompact,
  isAccent = false,
  onIconClick,
  centerAction,
}) => (
  <div
    className={cn(
      'relative flex justify-between items-start',
      isCompact ? 'mb-[1rem]' : 'mb-[1rem]'
    )}
  >
    <div className="flex flex-col overflow-hidden pr-[4rem]">
      <h2
        className={cn(
          'font-black font-display text-text-primary uppercase tracking-tight leading-none truncate',
          isCompact ? 'text-[1.25rem]' : 'text-[1.25rem]'
        )}
      >
        {title}
      </h2>
      <p
        className={cn(
          'text-[1rem] font-bold italic truncate transition-opacity',
          isAccent ? 'text-accent-red opacity-100' : 'text-text-muted opacity-80',
          isCompact && 'hidden'
        )}
      >
        {subtitle}
      </p>
    </div>

    {centerAction && (
      <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 z-30">
        {centerAction}
      </div>
    )}

    <div className="flex items-start gap-[1rem] shrink-0">
      {Icon && !isCompact && <IconButton icon={Icon} onClick={onIconClick} variant="default" />}
      {isCompact && isAccent && (
        <div className="h-[1.5rem] w-[1.5rem] rounded-[0.5rem] bg-accent-red/20 border border-accent-red/30 shrink-0" />
      )}
    </div>
  </div>
);

const CoffeeGroupCard = ({
  data,
  title,
  side,
  isCompact,
  isExpanded,
  onSelectProfile,
  onStopExtraction,
  onCloseDetailed,
  t,
}) => {
  const scrollRef = useRef(null);
  const lastScrollTop = useRef(0);
  const [canScrollUp, setCanScrollUp] = useState(false);
  const [canScrollDown, setCanScrollDown] = useState(false);

  const checkScroll = useCallback(() => {
    const el = scrollRef.current;
    if (el) {
      const { scrollTop, scrollHeight, clientHeight } = el;
      lastScrollTop.current = scrollTop;
      setCanScrollUp(scrollTop > 5); // Some threshold
      setCanScrollDown(scrollTop + clientHeight < scrollHeight - 5);
    }
  }, []);

  const isActive = data && data.active;
  const contentHeight = isActive ? 'h-[10.625rem]' : 'h-[14rem]';

  useEffect(() => {
    const el = scrollRef.current;
    if (el) {
      // Restore scroll position
      if (lastScrollTop.current > 0) {
        el.scrollTop = lastScrollTop.current;
      }
      checkScroll();
      el.addEventListener('scroll', checkScroll);
      window.addEventListener('resize', checkScroll);
      return () => {
        el.removeEventListener('scroll', checkScroll);
        window.removeEventListener('resize', checkScroll);
      };
    }
  }, [checkScroll, isActive, isExpanded]);

  return (
    <div
      className={cn(
        'flex h-full flex-col rounded-[2.5rem] bg-surface p-[1.5rem] border border-white/5 shadow-premium overflow-hidden transition-all duration-500',
        isCompact && 'w-[15rem] p-[1.5rem]',
        isExpanded && 'bg-surface-light border-white/10'
      )}
    >
      <CardHeader
        title={title}
        subtitle={isActive ? data.profileName : t('standby')}
        icon={isActive ? (isExpanded ? LayoutGrid : LineChart) : Coffee}
        isCompact={isCompact}
        isAccent={isActive}
        onIconClick={isActive ? () => onSelectProfile({ id: 'expand' }) : undefined}
        centerAction={
          isExpanded && isActive ? (
            <IconButton
              icon={Power}
              variant="accent"
              onClick={() => onStopExtraction(side)}
              className="h-[3.5rem] w-[3.5rem] rounded-[1.25rem] shadow-glow-red"
            />
          ) : null
        }
      />

      <div className="flex-1 flex flex-col min-h-0 relative">
        {isExpanded ? (
          <DetailedGraph profileName={isActive ? data.profileName : ''} t={t} />
        ) : (
          <>
            {isActive ? (
              <div className="flex flex-col h-full">
                <div className="grid grid-cols-2 gap-x-[1.5rem] gap-y-[1.25rem] mb-[1.5rem]">
                  <MetricRow
                    label={t('temp')}
                    icon={Thermometer}
                    value={data.temp}
                    unit={t('unit_temp')}
                    compact={isCompact}
                    status="active"
                  />
                  <MetricRow
                    label={t('flow_in')}
                    icon={Waves}
                    value={data.flowIn}
                    unit={t('unit_flow')}
                    compact={isCompact}
                    status="active"
                  />
                  <MetricRow
                    label={t('press')}
                    icon={Activity}
                    value={data.pressure}
                    unit={t('unit_press')}
                    compact={isCompact}
                    status="active"
                  />
                  <MetricRow
                    label={t('flow_out')}
                    icon={Droplet}
                    value={data.flowOut}
                    unit={t('unit_flow')}
                    compact={isCompact}
                    status="active"
                  />
                </div>
                <div className="flex justify-center mb-[2rem]">
                  <MetricRow
                    label={t('energy')}
                    icon={Zap}
                    value={data.energy}
                    unit={t('unit_energy')}
                    compact={isCompact}
                    status="active"
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
                  <IconButton
                    icon={Power}
                    variant="accent"
                    onClick={() => onStopExtraction(side)}
                    className="h-[3.5rem] w-[3.5rem] rounded-[1.25rem]"
                  />
                </div>
              </div>
            ) : (
              <div className="flex flex-col h-full relative">
                {/* Top Scroll Indicator */}
                <div
                  className={cn(
                    'absolute top-[-1rem] left-1/2 -translate-x-1/2 z-20 transition-all duration-300',
                    canScrollUp ? 'opacity-100 translate-y-0' : 'opacity-0 -translate-y-2'
                  )}
                >
                  <div className="w-[0.375rem] h-[0.375rem] rounded-full bg-text-muted/40 shadow-glow shadow-white/10" />
                </div>

                <div
                  ref={scrollRef}
                  className={cn(
                    'overflow-y-auto pr-[0.5rem] -mr-[0.5rem] no-scrollbar touch-pan-y overscroll-contain select-none snap-y snap-mandatory',
                    contentHeight
                  )}
                >
                  <div className="grid grid-cols-2 gap-[0.5rem]">
                    {COFFEE_PROFILES.map((p) => (
                      <div
                        key={p.id}
                        onClick={() => onSelectProfile(p)}
                        className="flex flex-col p-[0.75rem] h-[6.75rem] rounded-[1.25rem] bg-white/5 border border-white/5 active:border-white/20 active:bg-white/10 cursor-pointer transition-all shrink-0 overflow-hidden snap-start"
                      >
                        <div className="mb-[0.5rem] border-b border-white/5 pb-[0.25rem]">
                          <span className="text-[0.8125rem] font-black text-text-primary uppercase leading-none truncate block">
                            {p.name}
                          </span>
                        </div>

                        <div className="flex flex-1 gap-[0.75rem] items-center">
                          <div className="shrink-0 flex items-center justify-center bg-surface-active/30 rounded-[0.5rem] px-[0.5rem] py-[0.3rem] min-w-[2.75rem]">
                            <span className="text-[0.8125rem] font-black text-text-secondary font-display tracking-tighter leading-none">
                              {p.targetYield}
                              <span className="text-[0.5625rem] ml-[2px] opacity-60">
                                {t('unit_yield').toUpperCase()}
                              </span>
                            </span>
                          </div>
                          <div className="flex-1 overflow-hidden">
                            <span className="text-[0.8125rem] font-normal text-text-secondary italic leading-[1.2] line-clamp-3">
                              {p.desc}
                            </span>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Bottom Scroll Indicator */}
                <div
                  className={cn(
                    'absolute bottom-[3.75rem] left-1/2 -translate-x-1/2 z-20 transition-all duration-300',
                    canScrollDown ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-2'
                  )}
                >
                  <div className="w-[0.375rem] h-[0.375rem] rounded-full bg-text-muted/40 shadow-glow shadow-white/10" />
                </div>

                <div className="mt-auto pt-[0.5rem]">
                  <button className="flex h-[3.25rem] w-full items-center justify-center gap-[0.75rem] rounded-[1.25rem] bg-surface-light border border-white/5 text-[1.125rem] font-black font-display uppercase tracking-wider text-text-primary active:scale-[0.98] active:bg-surface-active transition-all">
                    <Flame className="w-[1.25rem] h-[1.25rem] text-accent-red" />
                    {t('flush')}
                  </button>
                </div>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
};

const TeaGroupCard = ({ data, isCompact, t }) => (
  <div
    className={cn(
      'flex h-full flex-col rounded-[2.5rem] bg-surface p-[1.5rem] border border-white/5 shadow-premium overflow-hidden transition-all',
      isCompact && 'px-[1rem] pt-[1.5rem]'
    )}
  >
    <CardHeader
      title={isCompact ? t('tea').toUpperCase() : 'Дянь Хун'}
      subtitle="Мао Фэн 85°C"
      icon={Droplets}
      isCompact={isCompact}
    />

    <div className="flex flex-col divide-y divide-white/5">
      <MetricRow
        label={t('temp')}
        icon={Thermometer}
        value={data.temp}
        unit={t('unit_temp')}
        compact={isCompact}
      />
      <MetricRow label={t('time')} icon={Timer} value={data.timer} unit="" compact={isCompact} />
    </div>

    <div className={cn('mt-auto', isCompact ? 'pt-[0.5rem]' : 'pt-[1.5rem]')}>
      {!isCompact && (
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
          isCompact ? 'h-[0.5rem]' : 'h-[0.625rem]'
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

const SystemStatusBlock = ({ time, date, status, isCompact, t }) => (
  <div
    className={cn(
      'flex h-full flex-col rounded-[2.5rem] bg-surface p-[1.5rem] border border-white/5 shadow-premium overflow-hidden transition-all',
      isCompact && 'px-[1rem] pt-[2rem]'
    )}
  >
    <div className="flex justify-center mb-[1rem]">
      <div
        className={cn(
          'rounded-full bg-surface-light border-2 border-white/10 flex items-center justify-center active:scale-95 active:bg-surface-active transition-all cursor-pointer shadow-premium',
          isCompact ? 'h-[3.5rem] w-[3.5rem]' : 'h-[4.5rem] w-[4.5rem]'
        )}
      >
        <User
          className={cn(
            'text-text-secondary',
            isCompact ? 'w-[1.5rem] h-[1.5rem]' : 'w-[2rem] h-[2rem]'
          )}
        />
      </div>
    </div>

    <div className="flex flex-col items-center justify-center flex-1 text-center">
      <span
        className={cn(
          'font-black font-display text-text-primary tracking-tighter leading-none',
          isCompact ? 'text-[2.5rem]' : 'text-[4.5rem]'
        )}
      >
        {time}
      </span>
      <span
        className={cn(
          'font-bold text-text-muted uppercase tracking-[0.2em] mt-[0.5rem]',
          isCompact ? 'text-[0.5rem]' : 'text-[0.75rem]'
        )}
      >
        {date}
      </span>
    </div>

    <div className="mt-auto flex flex-col items-center gap-[1rem] pt-[1rem] border-t border-white/5">
      <div className="flex items-center gap-[0.75rem] px-[1.5rem] py-[0.75rem] rounded-[1rem] bg-white/5 border border-white/5">
        <div
          className={cn(
            'h-[0.625rem] w-[0.625rem] rounded-full',
            status.status === 'ok'
              ? 'bg-green-500 shadow-[0_0_10px_rgba(34,197,94,0.4)]'
              : status.status === 'error'
                ? 'bg-red-500'
                : 'bg-yellow-500'
          )}
        />
        <span className="text-[0.75rem] font-black text-text-secondary uppercase tracking-widest transition-opacity truncate">
          {status.status === 'ok'
            ? t('ok')
            : status.status === 'error'
              ? t('error')
              : t('connecting')}
        </span>
      </div>
      {!isCompact && (
        <span className="text-[0.625rem] font-bold text-text-muted opacity-40 uppercase tracking-widest">
          SYSTEM NODE v{status.version}
        </span>
      )}
    </div>
  </div>
);

const DetailedGraph = ({ profileName, t }) => (
  <div className="flex h-full w-full flex-col overflow-hidden">
    <div className="flex-1 relative bg-white/5 rounded-[1.5rem] p-[1.5rem] border border-white/5">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={mockGraphData} margin={{ top: 20, right: 30, left: -20, bottom: 20 }}>
          <defs>
            <linearGradient id="colorValue" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor="#f04438" stopOpacity={0.4} />
              <stop offset="95%" stopColor="#f04438" stopOpacity={0} />
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke="#ffffff05" vertical={false} />
          <XAxis
            dataKey="time"
            axisLine={false}
            tickLine={false}
            tick={{ fill: '#667085', fontSize: 12, fontWeight: 700 }}
            tickFormatter={(v) => `00:${v.toString().padStart(2, '0')}`}
          />
          <YAxis hide domain={[0, 100]} />
          <Area
            type="monotone"
            dataKey="target"
            stroke="#f0443850"
            strokeWidth={2}
            strokeDasharray="10 8"
            fill="transparent"
            dot={false}
          />
          <Area
            type="monotone"
            dataKey="value"
            stroke="#f04438"
            strokeWidth={4}
            fillOpacity={1}
            fill="url(#colorValue)"
            dot={false}
          />
        </AreaChart>
      </ResponsiveContainer>

      <div className="absolute bottom-[1.5rem] left-[3rem] right-[3rem] flex justify-between text-[0.625rem] font-black text-text-muted font-display uppercase tracking-widest opacity-60">
        <span>{t('start')}</span>
        <span>00:26</span>
        <span>00:34 {t('finish')}</span>
      </div>
    </div>
  </div>
);

const App = () => {
  const [time, setTime] = useState(new Date());
  const [activeView, setActiveView] = useState(null);
  const [systemStatus, setSystemStatus] = useState({ status: 'connecting', version: '0.1.0' });
  const [language, setLanguage] = useState('ru');
  const { left, right, tea, startExtraction, stopExtraction } = useRealTimeData();

  useEffect(() => {
    const timer = setInterval(() => setTime(new Date()), 1000);

    const checkHealth = async () => {
      try {
        const response = await fetch('/api/health');
        const data = await response.json();
        setSystemStatus(data);
      } catch (error) {
        setSystemStatus({ status: 'error', version: 'offline' });
      }
    };

    checkHealth();
    const healthInterval = setInterval(checkHealth, 30000);

    return () => {
      clearInterval(timer);
      clearInterval(healthInterval);
    };
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

  const gridTemplate = useMemo(() => {
    const compactWidth = '15rem';
    const centerWidth = '7.5rem';
    const expandedWidth = '1fr';
    const normalL = '1fr';
    const normalAux = '0.7fr';

    switch (activeView) {
      case 'left':
        return `${expandedWidth} ${compactWidth} ${centerWidth} ${compactWidth} ${compactWidth}`;
      case 'right':
        return `${compactWidth} ${compactWidth} ${centerWidth} ${compactWidth} ${expandedWidth}`;
      default:
        return `${normalL} ${normalAux} ${centerWidth} ${normalAux} ${normalL}`;
    }
  }, [activeView]);

  const handleSelectProfile = (side, profile) => {
    startExtraction(side, profile);
  };

  const handleStopExtraction = (side) => {
    stopExtraction(side);
    setActiveView(null);
  };

  return (
    <div className="app-viewport flex items-stretch p-[1.5rem] font-sans select-none overflow-hidden bg-black text-text-primary">
      <div
        className="grid-cols-5-segment w-full gap-[1.5rem]"
        style={{ gridTemplateColumns: gridTemplate }}
      >
        {/* BLOCK 1: LEFT COFFEE GROUP */}
        <CoffeeGroupCard
          data={left}
          title={t('group_l')}
          side="left"
          isCompact={activeView !== null && activeView !== 'left'}
          isExpanded={activeView === 'left'}
          onSelectProfile={(p) =>
            p.id === 'expand'
              ? setActiveView(activeView === 'left' ? null : 'left')
              : handleSelectProfile('left', p)
          }
          onStopExtraction={handleStopExtraction}
          onCloseDetailed={() => setActiveView(null)}
          t={t}
        />

        {/* BLOCK 2: TEA GROUP */}
        <TeaGroupCard data={tea} isCompact={activeView !== null} t={t} />

        {/* BLOCK 3: CENTRAL VERTICAL PORTAL (SYSTEM) */}
        <div className="flex flex-col items-center p-[2rem] bg-surface-active/20 rounded-[2rem] border border-white/5 backdrop-blur-md overflow-hidden transition-all">
          <div className="flex flex-1 flex-col justify-start items-center gap-[1.25rem]">
            <IconButton
              icon={Settings}
              size="w-[1.75rem] h-[1.75rem]"
              variant="default"
              className="h-[4.5rem] w-[4.5rem] rounded-[1.75rem]"
            />
            <IconButton
              icon={Bell}
              size="w-[1.75rem] h-[1.75rem]"
              variant="default"
              className="h-[4.5rem] w-[4.5rem] rounded-[1.75rem]"
            />
            <IconButton
              icon={List}
              size="w-[1.75rem] h-[1.75rem]"
              variant="default"
              className="h-[4.5rem] w-[4.5rem] rounded-[1.75rem]"
            />
            <IconButton
              icon={Power}
              size="w-[1.75rem] h-[1.75rem]"
              variant="default"
              className="h-[4.5rem] w-[4.5rem] rounded-[1.75rem]"
              onClick={() => setActiveView(null)}
            />
          </div>
        </div>

        {/* BLOCK 4: SYSTEM STATUS & TIME */}
        <SystemStatusBlock
          time={formattedTime}
          date={formattedDate}
          status={systemStatus}
          isCompact={activeView !== null}
          t={t}
        />

        {/* BLOCK 5: RIGHT COFFEE GROUP */}
        <CoffeeGroupCard
          data={right}
          title={t('group_r')}
          side="right"
          isCompact={activeView !== null && activeView !== 'right'}
          isExpanded={activeView === 'right'}
          onSelectProfile={(p) =>
            p.id === 'expand'
              ? setActiveView(activeView === 'right' ? null : 'right')
              : handleSelectProfile('right', p)
          }
          onStopExtraction={handleStopExtraction}
          onCloseDetailed={() => setActiveView(null)}
          t={t}
        />
      </div>
    </div>
  );
};

export default App;
