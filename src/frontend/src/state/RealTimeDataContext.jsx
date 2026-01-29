import React, { createContext, useContext, useState, useEffect, useRef } from 'react';

const RealTimeDataContext = createContext(null);

export const RealTimeDataProvider = ({ children }) => {
  const [leftData, setLeftData] = useState(null);
  const [rightData, setRightData] = useState(null);
  const [teaData] = useState({
    temp: 84.1,
    timer: '2:10',
    yield: 250,
    targetYield: 500,
  });

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
    const setData = side === 'left' ? setLeftData : setRightData;
    setData((prev) => (prev ? { ...prev, done: true } : null));

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
    stopSimulation(side);
    setData(null);

    const intervalBucket = side === 'left' ? leftInterval : rightInterval;
    let currentYieldAccumulator = 0;
    const startTime = Date.now();
    const tickRate = 100;

    intervalBucket.current = setInterval(() => {
      if (!intervalBucket.current) return;

      const elapsedMs = Date.now() - startTime;
      const t = elapsedMs / 1000;
      const lastPoint = profile.points[profile.points.length - 1];
      const isDone = t >= lastPoint.t;

      const baseFlowOut = interpolate(t, profile.points, 'flowOut');
      currentYieldAccumulator += baseFlowOut * (tickRate / 1000);

      const result = {
        temp: round(addNoise(interpolate(t, profile.points, 'temp'), 0.005)),
        pressure: round(addNoise(interpolate(t, profile.points, 'press'), 0.02)),
        flowIn: round(addNoise(interpolate(t, profile.points, 'flowIn'), 0.02)),
        flowOut: round(addNoise(baseFlowOut, 0.02)),
        energy: round(addNoise(interpolate(t, profile.points, 'energy'), 0.01)),
        yield: round(currentYieldAccumulator),
        targetYield: profile.targetYield,
        time: `${Math.floor(t / 60)}:${Math.floor(t % 60)
          .toString()
          .padStart(2, '0')}`,
        done: isDone,
      };

      setData(result);
      if (isDone) stopSimulation(side);
    }, tickRate);
  };

  useEffect(() => {
    return () => {
      stopSimulation('left');
      stopSimulation('right');
    };
  }, []);

  return (
    <RealTimeDataContext.Provider
      value={{
        left: leftData,
        right: rightData,
        tea: teaData,
        startSimulation,
        stopSimulation,
      }}
    >
      {children}
    </RealTimeDataContext.Provider>
  );
};

export const useRealTimeData = () => {
  const context = useContext(RealTimeDataContext);
  if (!context) {
    throw new Error('useRealTimeData must be used within a RealTimeDataProvider');
  }
  return context;
};
