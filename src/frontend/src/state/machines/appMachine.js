/**
 * Глобальная машина интерфейса
 * Управляет компоновкой и активными зонами.
 */

export const AppStates = {
  LOADING: 'LOADING',
  DASHBOARD: 'DASHBOARD',
  FOCUS_LEFT: 'FOCUS_LEFT',
  FOCUS_RIGHT: 'FOCUS_RIGHT',
  FOCUS_BOTH: 'FOCUS_BOTH',
  SYSTEM_EXPANDED: 'SYSTEM_EXPANDED',
  ERROR_SYSTEM: 'ERROR_SYSTEM',
};

export const AppTransitions = {
  TOGGLE_EXPAND_LEFT: 'TOGGLE_EXPAND_LEFT',
  TOGGLE_EXPAND_RIGHT: 'TOGGLE_EXPAND_RIGHT',
  TOGGLE_EXPAND_BOTH: 'TOGGLE_EXPAND_BOTH',
  TOGGLE_SYSTEM: 'TOGGLE_SYSTEM',
  RESET_VIEW: 'RESET_VIEW',
  LOADED_SUCCESS: 'LOADED_SUCCESS',
  CONNECTION_LOST: 'CONNECTION_LOST',
  CONNECTION_RESTORED: 'CONNECTION_RESTORED',
};

export const appReducer = (state, action) => {
  switch (action.type) {
    case AppTransitions.LOADED_SUCCESS:
      return AppStates.DASHBOARD;

    case AppTransitions.TOGGLE_EXPAND_LEFT:
      if (state === AppStates.FOCUS_LEFT) return AppStates.DASHBOARD;
      if (state === AppStates.FOCUS_RIGHT) return AppStates.FOCUS_BOTH;
      if (state === AppStates.FOCUS_BOTH) return AppStates.FOCUS_RIGHT;
      return AppStates.FOCUS_LEFT;

    case AppTransitions.TOGGLE_EXPAND_RIGHT:
      if (state === AppStates.FOCUS_RIGHT) return AppStates.DASHBOARD;
      if (state === AppStates.FOCUS_LEFT) return AppStates.FOCUS_BOTH;
      if (state === AppStates.FOCUS_BOTH) return AppStates.FOCUS_LEFT;
      return AppStates.FOCUS_RIGHT;

    case AppTransitions.TOGGLE_EXPAND_BOTH:
      return state === AppStates.FOCUS_BOTH ? AppStates.DASHBOARD : AppStates.FOCUS_BOTH;

    case AppTransitions.RESET_VIEW:
      return AppStates.DASHBOARD;

    case AppTransitions.TOGGLE_SYSTEM:
      return state === AppStates.SYSTEM_EXPANDED ? AppStates.DASHBOARD : AppStates.SYSTEM_EXPANDED;

    case AppTransitions.CONNECTION_LOST:
      return AppStates.ERROR_SYSTEM;

    case AppTransitions.CONNECTION_RESTORED:
      return AppStates.DASHBOARD;

    default:
      return state;
  }
};
