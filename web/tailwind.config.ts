import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
    // The toast container lives in a context file; without this its classes are never generated.
    "./src/context/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/lib/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: "#3D4DD8",
          hover: "#313EB5",
          soft: "#EEF0FC",
          dark: "#2A3599",
          light: "#8C97F5",
        },
        like: "#E11D48",
        surface: {
          light: "#FFFFFF",
          muted: "#F1F3F5",
          dark: "#1E2024",
          "dark-muted": "#26292E",
        },
        appBg: {
          light: "#F8F9FA",
          dark: "#131416",
        },
        appBorder: {
          light: "#E6E8EC",
          dark: "#2A2D36",
        },
        appText: {
          primary: "#1A1D1E",
          secondary: "#6C7278",
          "dark-primary": "#F5F6F8",
          "dark-secondary": "#9EA3AE",
        },
        success: "#2F9E6E",
        danger: "#D9383A",
        warning: "#F59E0B",
      },
      borderRadius: {
        sm: "10px",
        md: "16px",
        lg: "24px",
      },
      boxShadow: {
        card: "0 2px 8px -2px rgba(0, 0, 0, 0.05), 0 1px 4px -1px rgba(0, 0, 0, 0.03)",
        elevated: "0 10px 25px -5px rgba(0, 0, 0, 0.08), 0 8px 10px -6px rgba(0, 0, 0, 0.04)",
        "card-hover": "0 8px 24px -8px rgba(26, 29, 30, 0.10), 0 2px 6px -2px rgba(26, 29, 30, 0.05)",
      },
      keyframes: {
        "like-pop": {
          "0%": { transform: "scale(1)" },
          "35%": { transform: "scale(1.35)" },
          "65%": { transform: "scale(0.9)" },
          "100%": { transform: "scale(1)" },
        },
        "dropdown-in": {
          "0%": { opacity: "0", transform: "translateY(-6px) scale(0.98)" },
          "100%": { opacity: "1", transform: "translateY(0) scale(1)" },
        },
        "toast-in": {
          "0%": { opacity: "0", transform: "translateY(16px) scale(0.95)" },
          "100%": { opacity: "1", transform: "translateY(0) scale(1)" },
        },
      },
      animation: {
        "like-pop": "like-pop 420ms cubic-bezier(0.34, 1.56, 0.64, 1)",
        "dropdown-in": "dropdown-in 160ms ease-out",
        "toast-in": "toast-in 240ms cubic-bezier(0.16, 1, 0.3, 1)",
      },
    },
  },
  plugins: [],
};

export default config;
