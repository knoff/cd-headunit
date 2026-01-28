/**
 * Машина состояний кофейной группы
 * Независимый цикл для каждой группы.
 */

export const GroupStates = {
  IDLE: 'IDLE',
  READY_TO_START: 'READY_TO_START',
  HEATING: 'HEATING',
  EXTRACTING: 'EXTRACTING',
  SUMMARY: 'SUMMARY',
  CLEANING: 'CLEANING',
};

export const GroupTransitions = {
  SELECT_PROFILE: 'SELECT_PROFILE',
  CONFIRM_START: 'CONFIRM_START',
  HEATING_DONE: 'HEATING_DONE',
  STOP: 'STOP',
  FINISH: 'FINISH',
  START_CLEANING: 'START_CLEANING',
  BACK_TO_IDLE: 'BACK_TO_IDLE',
  ERROR: 'ERROR',
};

export const groupReducer = (state, action) => {
  // state here is { status, profile, data }
  switch (action.type) {
    case GroupTransitions.SELECT_PROFILE:
      return {
        ...state,
        status: GroupStates.READY_TO_START,
        profile: action.payload,
      };

    case GroupTransitions.CONFIRM_START:
      // В реальной жизни тут может быть HEATING сначала
      return {
        ...state,
        status: GroupStates.EXTRACTING,
      };

    case GroupTransitions.STOP:
    case GroupTransitions.FINISH:
      return {
        ...state,
        status: GroupStates.SUMMARY,
      };

    case GroupTransitions.BACK_TO_IDLE:
      return {
        status: GroupStates.IDLE,
        profile: null,
        data: null,
      };

    case GroupTransitions.START_CLEANING:
      return {
        ...state,
        status: GroupStates.CLEANING,
      };

    case GroupTransitions.ERROR:
      return {
        ...state,
        status: GroupStates.IDLE, // Or a dedicated error state
      };

    default:
      return state;
  }
};
