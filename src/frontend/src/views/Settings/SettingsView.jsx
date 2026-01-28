import React, { useState } from 'react';
import { Settings, User, Sliders, Database, Save, FileText } from 'lucide-react';
import { useKeyboard } from '../../hooks/useKeyboard';
import IconButton from '../../components/ui/IconButton';

const SettingsView = ({ onClose, t }) => {
  const { openKeyboard } = useKeyboard();
  const [values, setValues] = useState({
    machineName: 'Reborn One',
    boilerTemp: '93.5',
    pressureLimit: '9.0',
    userName: 'Admin',
    description: 'Multi-line\ntest field',
  });

  const handleFieldClick = (fieldId, label, config = {}) => {
    openKeyboard({
      id: fieldId,
      label: label,
      value: values[fieldId],
      onSave: (val) => setValues((prev) => ({ ...prev, [fieldId]: val })),
      ...config,
    });
  };

  const SettingField = ({ id, label, icon: Icon, config = {} }) => (
    <div
      onClick={() => handleFieldClick(id, label, config)}
      className="flex items-center justify-between p-[1.5rem] bg-white/5 border border-white/5 rounded-[1.5rem] hover:bg-white/10 transition-all active:scale-[0.98]"
    >
      <div className="flex items-center gap-[1rem]">
        <div className="p-[0.75rem] bg-accent-red/10 rounded-[1rem]">
          <Icon className="w-[1.25rem] h-[1.25rem] text-accent-red" />
        </div>
        <div className="flex flex-col">
          <span className="text-text-muted text-[0.75rem] font-bold uppercase tracking-wider">
            {label}
          </span>
          <span className="text-text-primary text-[1.125rem] font-black line-clamp-1 whitespace-pre-wrap">
            {values[id]}
          </span>
        </div>
      </div>
      <div className="text-text-muted opacity-30 text-[1.5rem]">›</div>
    </div>
  );

  return (
    <div className="flex-1 flex flex-col bg-surface-light rounded-[2.5rem] p-[2rem] border border-white/10 animate-in fade-in zoom-in-95 duration-300 h-full overflow-hidden">
      <div className="flex justify-between items-center mb-[2rem]">
        <div className="flex items-center gap-[1rem]">
          <Settings className="w-[2rem] h-[2rem] text-text-primary" />
          <h1 className="text-[2rem] font-black font-display uppercase text-text-primary">
            {t('settings') || 'Настройки'}
          </h1>
        </div>
        <IconButton
          icon={Save}
          variant="accent"
          onClick={onClose}
          className="h-[3.5rem] w-[10rem] rounded-[1.25rem] shadow-glow-red"
        />
      </div>

      <div className="grid grid-cols-2 gap-[1.5rem] overflow-y-auto pr-2 no-scrollbar">
        <div className="flex flex-col gap-[1.5rem]">
          <h3 className="text-text-muted font-bold text-[0.875rem] uppercase mb-[-0.5rem] pl-[0.5rem]">
            Основные
          </h3>
          <SettingField
            id="machineName"
            label="Имя машины"
            icon={Database}
            config={{ allowedLayouts: ['en', 'num', 'sym'], defaultLayout: 'en' }}
          />
          <SettingField
            id="userName"
            label="Пользователь"
            icon={User}
            config={{ allowedLayouts: ['en'], defaultLayout: 'en' }}
          />
          <SettingField
            id="description"
            label="Заметки (Multiline)"
            icon={FileText}
            config={{ isMultiline: true }}
          />
        </div>

        <div className="flex flex-col gap-[1.5rem]">
          <h3 className="text-text-muted font-bold text-[0.875rem] uppercase mb-[-0.5rem] pl-[0.5rem]">
            Параметры
          </h3>
          <SettingField
            id="boilerTemp"
            label="Температура бойлера"
            icon={Sliders}
            config={{ type: 'num', allowedLayouts: ['num'] }}
          />
          <SettingField
            id="pressureLimit"
            label="Лимит давления"
            icon={Sliders}
            config={{ type: 'num', allowedLayouts: ['num'] }}
          />
        </div>
      </div>
    </div>
  );
};

export default SettingsView;
