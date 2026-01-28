import { useReducer, useCallback } from 'react';

/**
 * Простой хук для управления машиной состояний
 */
export const useMachine = (reducer, initialState) => {
  const [state, dispatch] = useReducer(reducer, initialState);

  const send = useCallback((type, payload) => {
    dispatch({ type, payload });
  }, []);

  return [state, send];
};
