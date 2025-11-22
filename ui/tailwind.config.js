/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        fair: {
          bg: '#0a0b1e', // Deep space blue
          card: 'rgba(255, 255, 255, 0.05)',
          primary: '#00f0ff', // Neon cyan
          secondary: '#7000ff', // Void purple
          text: '#e0e0e0',
          muted: '#888888',
        }
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
      }
    },
  },
  plugins: [],
}
