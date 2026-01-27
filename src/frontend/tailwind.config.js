/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        background: '#0a0a0a',
        surface: {
          DEFAULT: '#141414',
          light: '#1e1e1e',
          active: '#262626',
          tea: '#1a1a14', // Subtle leaf/tea tint
        },
        accent: {
          red: '#f04438',
          gold: '#c4a484',
          tea: '#8caa4b', // Tea green
        },
        text: {
          primary: '#f9fafb',
          secondary: '#98a2b3',
          muted: '#667085',
        },
      },
      gridTemplateColumns: {
        '5-segment':
          'minmax(600px, 1fr) minmax(400px, 0.7fr) 120px minmax(400px, 0.7fr) minmax(600px, 1fr)',
      },
      borderRadius: {
        '2xl': '1.25rem',
        '3xl': '1.75rem',
      },
      boxShadow: {
        premium: '0 10px 30px -10px rgba(0, 0, 0, 0.5)',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        display: ['Outfit', 'Inter', 'sans-serif'],
      },
    },
  },
  plugins: [require('tailwindcss-animate')],
};
