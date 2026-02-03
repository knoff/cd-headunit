import React, { createContext, useContext, useState, useEffect, useRef } from 'react';

const RealTimeDataContext = createContext(null);

export const RealTimeDataProvider = ({ children }) => {
  const [leftData, setLeftData] = useState(null);
  const [rightData, setRightData] = useState(null);
  const [machineData, setMachineData] = useState(null);
  const [teaData] = useState({
    temp: 84.1,
    timer: '2:10',
    yield: 250,
    targetYield: 500,
  });

  const ws = useRef(null);

  useEffect(() => {
    const connectWS = () => {
      const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
      const host = window.location.host || 'localhost:8000'; // Fallback for dev
      ws.current = new WebSocket(`${protocol}//${host}/ws/telemetry`);

      ws.current.onmessage = (event) => {
        try {
          const { topic, payload } = JSON.parse(event.data);
          if (topic === 'left') setLeftData(payload);
          if (topic === 'right') setRightData(payload);
          if (topic === 'machine') setMachineData(payload);
        } catch (e) {
          console.error('[WS] Parse error:', e);
        }
      };

      ws.current.onclose = () => {
        console.log('[WS] Disconnected, retrying...');
        setTimeout(connectWS, 2000);
      };
    };

    connectWS();
    return () => {
      if (ws.current) ws.current.close();
    };
  }, []);

  const stopSimulation = async (side) => {
    try {
      await fetch(`/api/control/stop/${side}`, { method: 'POST' });
    } catch (e) {
      console.error(`[CONTROL] Stop ${side} failed:`, e);
    }
  };

  const startSimulation = async (side, profile) => {
    try {
      await fetch(`/api/control/start/${side}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(profile),
      });
    } catch (e) {
      console.error(`[CONTROL] Start ${side} failed:`, e);
    }
  };

  const startFlush = async (side) => {
    try {
      await fetch(`/api/control/flush/${side}`, { method: 'POST' });
    } catch (e) {
      console.error(`[CONTROL] Flush ${side} failed:`, e);
    }
  };

  const startCleaning = async (side) => {
    try {
      await fetch(`/api/control/cleaning/${side}`, { method: 'POST' });
    } catch (e) {
      console.error(`[CONTROL] Cleaning ${side} failed:`, e);
    }
  };

  const resetGroup = async (side) => {
    try {
      await fetch(`/api/control/reset/${side}`, { method: 'POST' });
    } catch (e) {
      console.error(`[CONTROL] Reset ${side} failed:`, e);
    }
  };

  return (
    <RealTimeDataContext.Provider
      value={{
        left: leftData,
        right: rightData,
        machine: machineData,
        tea: teaData,
        startSimulation,
        stopSimulation,
        startFlush,
        startCleaning,
        resetGroup,
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
