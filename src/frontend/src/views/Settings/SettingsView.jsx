import React, { useState, useEffect } from 'react';
import {
  Settings,
  User,
  Sliders,
  Database,
  Save,
  FileText,
  X,
  Wifi,
  Globe,
  Clock,
  Power,
  RefreshCw,
  ShieldCheck,
  HardDrive,
  Cpu,
  Terminal,
  Check,
} from 'lucide-react';
import { useKeyboard } from '../../hooks/useKeyboard';
import IconButton from '../../components/ui/IconButton';
import Select from '../../components/ui/Select';
import TimePicker from '../../components/ui/TimePicker';
import Toggle from '../../components/ui/Toggle';
import WheelPicker from '../../components/ui/WheelPicker';

const CATEGORIES = [
  { id: 'info', icon: Cpu, labelKey: 'info' },
  { id: 'wifi', icon: Wifi, labelKey: 'wifi' },
  { id: 'interface', icon: Globe, labelKey: 'interface' },
  { id: 'system', icon: Terminal, labelKey: 'system' },
];

const LANGUAGE_OPTIONS = [
  { value: 'ru', label: 'Русский' },
  { value: 'en', label: 'English' },
];

const COUNTRY_OPTIONS = [
  { value: 'RU', label: 'Russia (RU)' },
  { value: 'US', label: 'USA (US)' },
  { value: 'DE', label: 'Germany (DE)' },
];

const TIMEZONE_OPTIONS = [
  { value: 'Europe/Moscow', label: 'Moscow (GMT+3)' },
  { value: 'Europe/London', label: 'London (GMT+0)' },
  { value: 'America/New_York', label: 'New York (GMT-5)' },
  { value: 'Asia/Dubai', label: 'Dubai (GMT+4)' },
  { value: 'Asia/Tokyo', label: 'Tokyo (GMT+9)' },
  { value: 'Europe/Paris', label: 'Paris (GMT+1)' },
  { value: 'Asia/Singapore', label: 'Singapore (GMT+8)' },
  { value: 'Australia/Sydney', label: 'Sydney (GMT+11)' },
];

const TIME_FORMAT_OPTIONS = [
  { value: '24h', label: '24 Hours (14:30)' },
  { value: '12h', label: '12 Hours (02:30 PM)' },
];

const SettingsView = ({
  onClose,
  t,
  uiSettings,
  onUpdateUiSettings,
  onUpdateSystemSettings,
  currentTime,
}) => {
  const { openKeyboard } = useKeyboard();
  const [activeCategory, setActiveCategory] = useState('info');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [showConfirm, setShowConfirm] = useState(null); // 'reboot' | 'shutdown' | null
  const [selectConfig, setSelectConfig] = useState(null); // { title, options, value, onSelect }
  const [wheelConfig, setWheelConfig] = useState(null); // { title, options, value, onSave }
  const [showTimePicker, setShowTimePicker] = useState(false);

  // Исходные настройки (сервер + UI)
  const [originalSettings, setOriginalSettings] = useState({});
  // Буфер для изменений
  const [bufferedSettings, setBufferedSettings] = useState({
    serial: '---',
    wifi_client_ssid: '',
    wifi_client_pass: '',
    wifi_country: 'RU',
    language: 'ru',
    time_format: '24h',
    summary_timeout: 15,
    timezone: 'Europe/Moscow',
    ntp_enabled: true,
    system_time: '',
    version: '0.0.0',
  });

  useEffect(() => {
    fetchSettings();
  }, []);

  const fetchSettings = async () => {
    try {
      const response = await fetch('/api/settings');
      const data = await response.json();

      const healthRes = await fetch('/api/health');
      const healthData = await healthRes.json();

      // Filter uiSettings to only include allowed UI keys
      const allowedUiKeys = ['language', 'time_format'];
      const filteredUiSettings = Object.keys(uiSettings).reduce((acc, key) => {
        if (allowedUiKeys.includes(key)) acc[key] = uiSettings[key];
        return acc;
      }, {});

      const merged = { ...data, ...filteredUiSettings, version: healthData.version };
      setOriginalSettings(merged);
      setBufferedSettings(merged);
    } catch (e) {
      console.error('[SETTINGS] Fetch failed:', e);
    } finally {
      setLoading(false);
    }
  };

  const handleApply = async () => {
    setSaving(true);
    try {
      // 1. Обработка UI настроек (локально)
      const uiUpdates = {};
      const uiKeys = ['language', 'time_format'];
      uiKeys.forEach((key) => {
        if (bufferedSettings[key] !== originalSettings[key]) {
          let val = bufferedSettings[key];
          if (key === 'summary_timeout') val = parseInt(val, 10) || 15;
          uiUpdates[key] = val;
        }
      });

      if (Object.keys(uiUpdates).length > 0 && onUpdateUiSettings) {
        onUpdateUiSettings({ ...uiSettings, ...uiUpdates });
      }

      // 2. Обработка системных настроек (на сервер)
      const updates = {};
      Object.keys(bufferedSettings).forEach((key) => {
        if (
          !uiKeys.includes(key) &&
          bufferedSettings[key] !== originalSettings[key] &&
          bufferedSettings[key] !== originalSettings[key] &&
          key !== 'version' &&
          key !== 'system_time'
        ) {
          updates[key] = bufferedSettings[key];
        }
      });

      // Добавляем system_time только если NTP выключен и оно изменилось
      if (
        !bufferedSettings.ntp_enabled &&
        bufferedSettings.system_time &&
        bufferedSettings.system_time !== originalSettings.system_time
      ) {
        updates['system_time'] = bufferedSettings.system_time;
      }

      if (Object.keys(updates).length > 0) {
        const response = await fetch('/api/settings', {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(updates),
        });
        if (response.ok) {
          setOriginalSettings({ ...bufferedSettings });
          if (onUpdateSystemSettings) {
            onUpdateSystemSettings(updates);
          }
        }
      }
      onClose();
    } catch (e) {
      console.error('[SETTINGS] Save failed:', e);
    } finally {
      setSaving(false);
    }
  };

  const handleSystemAction = async (action) => {
    try {
      await fetch(`/api/system/${action}`, { method: 'POST' });
      setShowConfirm(null);
      if (onClose) onClose();
    } catch (e) {
      console.error(`[SYSTEM] ${action} failed:`, e);
    }
  };

  const handleFieldClick = (fieldId, label, config = {}) => {
    if (fieldId === 'system_time') {
      setShowTimePicker(true);
      return;
    }

    if (config.type === 'select') {
      setSelectConfig({
        title: label,
        options: config.options,
        value: bufferedSettings[fieldId],
        onSelect: (val) => setBufferedSettings((prev) => ({ ...prev, [fieldId]: val })),
      });
      return;
    }

    if (config.type === 'wheel') {
      setWheelConfig({
        title: label,
        options: config.options,
        value: bufferedSettings[fieldId],
        onSave: (val) => setBufferedSettings((prev) => ({ ...prev, [fieldId]: val })),
      });
      return;
    }

    openKeyboard({
      id: fieldId,
      label: label,
      value: bufferedSettings[fieldId] || '',
      onSave: (val) => setBufferedSettings((prev) => ({ ...prev, [fieldId]: val })),
      ...config,
    });
  };

  const SettingField = ({ id, label, icon: Icon, config = {}, valueOverride }) => (
    <div
      onClick={() => {
        if (config.type === 'toggle') return; // Toggle handles its own click
        !config.readOnly && !config.disabled && handleFieldClick(id, label, config);
      }}
      className={`flex items-center justify-between p-[0.625rem] h-[4.75rem] bg-white/5 border border-white/5 rounded-[1rem] transition-all snap-start ${
        config.readOnly || config.disabled
          ? 'opacity-60 cursor-default'
          : 'cursor-pointer active:bg-white/10'
      }`}
    >
      <div className="flex items-center gap-[0.5rem]">
        <div
          className={`p-[0.3125rem] rounded-[0.5rem] ${config.readOnly || config.disabled ? 'bg-white/5' : 'bg-accent-red/10'}`}
        >
          <Icon
            className={`w-[0.875rem] h-[0.875rem] ${config.readOnly || config.disabled ? 'text-text-muted' : 'text-accent-red'}`}
          />
        </div>
        <div className="flex flex-col">
          <span className="text-text-muted text-[0.625rem] font-bold uppercase tracking-wider">
            {label}
          </span>
          <span className="text-text-primary text-[0.875rem] font-black line-clamp-1">
            {config.type === 'toggle' ? '' : valueOverride || bufferedSettings[id] || '---'}
          </span>
        </div>
      </div>

      {config.type === 'toggle' ? (
        <div className="pr-2">
          <Toggle
            checked={!!bufferedSettings[id]}
            onChange={(val) => setBufferedSettings((prev) => ({ ...prev, [id]: val }))}
          />
        </div>
      ) : (
        !config.readOnly &&
        !config.disabled && <div className="text-text-muted opacity-30 text-[1.25rem]">›</div>
      )}
    </div>
  );

  const renderCategoryContent = () => {
    switch (activeCategory) {
      case 'info':
        return (
          <div className="flex flex-col gap-[0.75rem] animate-in slide-in-from-right-4 duration-300">
            <h3 className="text-text-muted font-bold text-[0.625rem] uppercase pl-[0.25rem]">
              {t('general_info')}
            </h3>
            <div className="grid grid-cols-3 gap-[0.75rem]">
              <SettingField
                id="serial"
                label={t('serial')}
                icon={ShieldCheck}
                config={{ readOnly: true }}
              />
              <SettingField
                id="version"
                label={t('version')}
                icon={Database}
                config={{ readOnly: true }}
              />
              <SettingField
                id="hw_rev"
                label={t('hw_rev')}
                icon={HardDrive}
                config={{ readOnly: true }}
                valueOverride="REV A"
              />
              <SettingField
                id="uptime"
                label={t('uptime')}
                icon={Clock}
                config={{ readOnly: true }}
                valueOverride="12:45:00"
              />
            </div>
          </div>
        );
      case 'wifi':
        return (
          <div className="flex flex-col gap-[0.75rem] animate-in slide-in-from-right-4 duration-300">
            <h3 className="text-text-muted font-bold text-[0.625rem] uppercase pl-[0.25rem]">
              {t('wifi_settings')}
            </h3>
            <div className="grid grid-cols-3 gap-[0.75rem]">
              <SettingField
                id="wifi_client_ssid"
                label={t('ssid')}
                icon={Wifi}
                config={{ allowedLayouts: ['en', 'num', 'sym'] }}
              />
              <SettingField
                id="wifi_client_pass"
                label={t('password')}
                icon={ShieldCheck}
                config={{ type: 'password' }}
                valueOverride="********"
              />
              <SettingField
                id="wifi_country"
                label={t('region')}
                icon={Globe}
                config={{ type: 'select', options: COUNTRY_OPTIONS }}
              />
            </div>
          </div>
        );
      case 'interface':
        return (
          <div className="flex flex-col gap-[0.75rem] animate-in slide-in-from-right-4 duration-300">
            <h3 className="text-text-muted font-bold text-[0.625rem] uppercase pl-[0.25rem]">
              {t('interface')}
            </h3>
            <div className="grid grid-cols-3 gap-[0.75rem]">
              <SettingField
                id="language"
                label={t('language')}
                icon={Globe}
                config={{ type: 'select', options: LANGUAGE_OPTIONS }}
                valueOverride={
                  LANGUAGE_OPTIONS.find((o) => o.value === bufferedSettings.language)?.label
                }
              />

              <SettingField
                id="summary_timeout"
                label={t('summary_timeout')}
                icon={Clock}
                config={{
                  type: 'wheel',
                  options: [
                    { value: 0, label: `0 ${t('sec')} (${t('disabled')})` },
                    { value: 5, label: `5 ${t('sec')}` },
                    { value: 10, label: `10 ${t('sec')}` },
                    { value: 15, label: `15 ${t('sec')}` },
                    { value: 20, label: `20 ${t('sec')}` },
                    { value: 30, label: `30 ${t('sec')}` },
                  ],
                }}
                valueOverride={(() => {
                  const val =
                    bufferedSettings.summary_timeout !== undefined
                      ? parseInt(bufferedSettings.summary_timeout, 10)
                      : 15;
                  const opts = [
                    { value: 0, label: `0 ${t('sec')} (${t('disabled')})` },
                    { value: 5, label: `5 ${t('sec')}` },
                    { value: 10, label: `10 ${t('sec')}` },
                    { value: 15, label: `15 ${t('sec')}` },
                    { value: 20, label: `20 ${t('sec')}` },
                    { value: 30, label: `30 ${t('sec')}` },
                  ];
                  return opts.find((o) => o.value === val)?.label;
                })()}
              />
              <SettingField
                id="time_format"
                label={t('time_format') || 'Time Format'}
                icon={Clock}
                config={{
                  type: 'select',
                  options: [
                    { value: '24h', label: '24 Hours (14:30)' },
                    { value: '12h', label: '12 Hours (02:30 PM)' },
                  ],
                }}
                valueOverride={
                  [
                    { value: '24h', label: '24 Hours (14:30)' },
                    { value: '12h', label: '12 Hours (02:30 PM)' },
                  ].find((o) => o.value === (bufferedSettings.time_format || '24h'))?.label
                }
              />
            </div>
          </div>
        );
      case 'system':
        return (
          <div className="flex flex-col gap-[0.75rem] animate-in slide-in-from-right-4 duration-300">
            <h3 className="text-text-muted font-bold text-[0.625rem] uppercase pl-[0.25rem]">
              {t('system')}
            </h3>
            <div className="grid grid-cols-3 gap-[0.75rem]">
              <SettingField
                id="timezone"
                label={t('sys_timezone')}
                icon={Clock}
                config={{ type: 'select', options: TIMEZONE_OPTIONS }}
                valueOverride={
                  TIMEZONE_OPTIONS.find((o) => o.value === bufferedSettings.timezone)?.label
                }
              />
              <SettingField
                id="ntp_enabled"
                label={t('sys_auto_time')}
                icon={Clock}
                config={{ type: 'toggle' }}
              />

              <SettingField
                id="system_time"
                label={t('sys_set_time')}
                icon={Clock}
                config={{
                  disabled: bufferedSettings.ntp_enabled,
                  readOnly: bufferedSettings.ntp_enabled,
                  type: 'time',
                }}
                valueOverride={
                  bufferedSettings.ntp_enabled && currentTime
                    ? currentTime.toLocaleTimeString([], {
                        hour: '2-digit',
                        minute: '2-digit',
                        hour12: bufferedSettings.time_format === '12h',
                      })
                    : bufferedSettings.system_time
                      ? new Date(bufferedSettings.system_time).toLocaleTimeString([], {
                          hour: '2-digit',
                          minute: '2-digit',
                          hour12: bufferedSettings.time_format === '12h',
                        })
                      : '---'
                }
              />
              <button
                onClick={() => setShowConfirm('reboot')}
                className="flex items-center gap-[0.5rem] p-[0.625rem] h-[4.75rem] bg-accent-red/10 border border-accent-red/20 rounded-[1rem] active:bg-accent-red/20 transition-all font-bold uppercase text-[0.625rem] text-accent-red snap-start"
              >
                <div className="p-[0.3125rem] bg-accent-red/10 rounded-[0.5rem]">
                  <RefreshCw className="w-[0.875rem] h-[0.875rem]" />
                </div>
                <div className="flex flex-col items-start">
                  <span className="text-[0.5rem] opacity-50 mb-[0.125rem]">{t('system')}</span>
                  <span className="text-[0.875rem] font-black">{t('reboot')}</span>
                </div>
              </button>
              <button
                onClick={() => setShowConfirm('shutdown')}
                className="flex items-center gap-[0.5rem] p-[0.625rem] h-[4.75rem] bg-white/5 border border-white/10 rounded-[1rem] active:bg-white/10 transition-all font-bold uppercase text-[0.625rem] text-text-primary snap-start"
              >
                <div className="p-[0.3125rem] bg-white/10 rounded-[0.5rem]">
                  <Power className="w-[0.875rem] h-[0.875rem]" />
                </div>
                <div className="flex flex-col items-start">
                  <span className="text-[0.5rem] opacity-50 mb-[0.125rem]">{t('system')}</span>
                  <span className="text-[0.875rem] font-black">{t('shutdown')}</span>
                </div>
              </button>
            </div>
          </div>
        );
      default:
        return null;
    }
  };

  if (loading) {
    return (
      <div className="flex-1 flex items-center justify-center bg-surface-light rounded-[2.5rem] h-[25rem] border border-white/10">
        <div className="w-[3rem] h-[3rem] border-4 border-accent-red border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  const hasChanges = Object.keys(bufferedSettings).some(
    (key) => bufferedSettings[key] !== originalSettings[key]
  );

  return (
    <div className="flex-1 flex bg-surface-light rounded-[2rem] border border-white/10 animate-in fade-in zoom-in-95 duration-300 h-[28rem] overflow-hidden relative shadow-2xl">
      {/* Sidebar */}
      <div className="w-[11rem] bg-black/20 border-r border-white/5 flex flex-col p-[0.75rem] gap-[0.4rem]">
        <div className="flex items-center gap-[0.5rem] mb-[1rem] px-[0.5rem]">
          <Settings className="w-[1.25rem] h-[1.25rem] text-accent-red" />
          <h1 className="text-[1rem] font-black uppercase tracking-tighter text-text-primary">
            {t('settings')}
          </h1>
        </div>

        {CATEGORIES.map((cat) => (
          <button
            key={cat.id}
            onClick={() => setActiveCategory(cat.id)}
            className={`flex items-center gap-[0.6rem] p-[0.75rem] rounded-[1rem] transition-all ${
              activeCategory === cat.id
                ? 'bg-accent-red text-white shadow-glow-red'
                : 'text-text-muted hover:text-text-primary'
            }`}
          >
            <cat.icon className="w-[0.875rem] h-[0.875rem]" />
            <span className="font-bold text-[0.75rem] uppercase tracking-wider">
              {t(cat.labelKey)}
            </span>
          </button>
        ))}

        <div className="mt-auto flex flex-col gap-[0.4rem]">
          <button
            onClick={onClose}
            className="flex items-center justify-center gap-[0.4rem] w-full h-[3rem] rounded-[1rem] bg-white/5 text-text-muted font-bold uppercase text-[0.75rem] active:bg-white/10"
          >
            <X className="w-[1rem] h-[1rem]" />
            <span>{hasChanges ? t('cancel') : t('close')}</span>
          </button>

          {hasChanges && (
            <button
              onClick={handleApply}
              className="flex items-center justify-center gap-[0.4rem] w-full h-[3rem] rounded-[1rem] bg-accent-red text-white font-bold uppercase text-[0.75rem] shadow-glow-red animate-in fade-in slide-in-from-bottom-2"
            >
              <Check className="w-[1rem] h-[1rem]" />
              <span>{t('apply')}</span>
            </button>
          )}
        </div>
      </div>

      {/* Content Area */}
      <div className="flex-1 p-[1.5rem] overflow-y-auto no-scrollbar snap-y snap-mandatory scroll-py-[1.5rem]">
        {renderCategoryContent()}
      </div>

      {/* Confirmation Modal */}
      {showConfirm && (
        <div className="absolute inset-0 z-50 bg-black/90 flex items-center justify-center p-[2rem] animate-in fade-in duration-200">
          <div className="bg-surface-light border border-white/10 rounded-[2.5rem] p-[2.5rem] w-full max-w-[30rem] flex flex-col items-center gap-[1.5rem] text-center shadow-2xl">
            <div className="p-[1.5rem] bg-accent-red/20 rounded-full">
              <Power className="w-[3rem] h-[3rem] text-accent-red" />
            </div>
            <div className="flex flex-col gap-[0.25rem]">
              <h2 className="text-[1.75rem] font-black uppercase text-text-primary">
                {t('confirm_action')}
              </h2>
              <p className="text-text-muted text-[1.125rem]">
                {showConfirm === 'reboot' ? t('confirm_msg_reboot') : t('confirm_msg_shutdown')}
              </p>
            </div>
            <div className="flex gap-[1rem] w-full mt-[0.5rem]">
              <button
                onClick={() => setShowConfirm(null)}
                className="flex-1 h-[4rem] rounded-[1.25rem] bg-white/5 border border-white/10 font-bold uppercase text-text-muted active:bg-white/10 transition-all"
              >
                {t('cancel')}
              </button>
              <button
                onClick={() => handleSystemAction(showConfirm)}
                className="flex-1 h-[4rem] rounded-[1.25rem] bg-accent-red font-bold uppercase text-white shadow-glow-red active:brightness-110 active:scale-[0.98] transition-all"
              >
                {t('confirm')}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Select Modal Overlay */}
      {selectConfig && (
        <Select
          isOpen={!!selectConfig}
          title={selectConfig.title}
          options={selectConfig.options}
          value={selectConfig.value}
          onSelect={selectConfig.onSelect}
          onClose={() => setSelectConfig(null)}
        />
      )}

      <TimePicker
        isOpen={showTimePicker}
        initialValue={bufferedSettings.system_time || new Date()}
        is24Hour={bufferedSettings.time_format === '24h'}
        onClose={() => setShowTimePicker(false)}
        onSave={(val) => setBufferedSettings((prev) => ({ ...prev, system_time: val }))}
        t={t}
      />

      <WheelPicker
        isOpen={!!wheelConfig}
        title={wheelConfig?.title}
        options={wheelConfig?.options || []}
        value={wheelConfig?.value}
        onSave={wheelConfig?.onSave}
        onClose={() => setWheelConfig(null)}
      />

      {saving && (
        <div className="absolute bottom-[1rem] right-[1rem] flex items-center gap-[0.5rem] px-[1rem] py-[0.5rem] bg-black/60 rounded-full border border-white/10 animate-in fade-in">
          <div className="w-[0.875rem] h-[0.875rem] border-2 border-accent-red border-t-transparent rounded-full animate-spin" />
          <span className="text-[0.75rem] font-bold uppercase text-text-muted">{t('saving')}</span>
        </div>
      )}
    </div>
  );
};

export default SettingsView;
