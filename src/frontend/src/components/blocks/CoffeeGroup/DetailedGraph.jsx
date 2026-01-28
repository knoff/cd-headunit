import React from 'react';
import { ResponsiveContainer, AreaChart, Area, XAxis, YAxis, CartesianGrid } from 'recharts';

const mockGraphData = Array.from({ length: 40 }, (_, i) => ({
  time: i,
  value: 40 + Math.sin(i / 5) * 20 + (i > 20 ? 20 : 0),
  target: 45 + Math.sin(i / 5) * 18 + (i > 20 ? 15 : 0),
}));

const DetailedGraph = ({ profileName, t }) => (
  <div className="flex h-full w-full flex-col overflow-hidden animate-in fade-in duration-300">
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

export default DetailedGraph;
