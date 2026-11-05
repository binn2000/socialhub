export interface ChatTheme {
  id: string;
  name: string;
  bubbleClass: string;
  bubbleStyle?: React.CSSProperties;
  sendBtnClass: string;
  colorPreview: string;
  ringColor: string;
}

export const CHAT_THEMES: ChatTheme[] = [
  {
    id: "blue",
    name: "Xanh đại dương",
    bubbleClass: "bg-blue-600 text-white rounded-br-xs",
    sendBtnClass: "bg-blue-600 hover:bg-blue-700 text-white",
    colorPreview: "linear-gradient(135deg, #2563eb, #3b82f6)",
    ringColor: "ring-blue-500",
  },
  {
    id: "purple",
    name: "Hồng tím",
    bubbleClass: "bg-gradient-to-r from-pink-500 to-purple-600 text-white rounded-br-xs",
    sendBtnClass: "bg-gradient-to-r from-pink-500 to-purple-600 hover:opacity-90 text-white",
    colorPreview: "linear-gradient(135deg, #ec4899, #8b5cf6)",
    ringColor: "ring-pink-500",
  },
  {
    id: "sunset",
    name: "Hoàng hôn",
    bubbleClass: "bg-gradient-to-r from-amber-500 via-rose-500 to-pink-500 text-white rounded-br-xs",
    sendBtnClass: "bg-gradient-to-r from-amber-500 via-rose-500 to-pink-500 hover:opacity-90 text-white",
    colorPreview: "linear-gradient(135deg, #f59e0b, #ef4444, #ec4899)",
    ringColor: "ring-rose-500",
  },
  {
    id: "midnight",
    name: "Midnight",
    bubbleClass: "bg-gradient-to-r from-slate-900 via-indigo-950 to-indigo-900 border border-indigo-700/50 text-indigo-100 rounded-br-xs",
    sendBtnClass: "bg-indigo-900 hover:bg-indigo-800 text-white border border-indigo-700/50",
    colorPreview: "linear-gradient(135deg, #0f172a, #312e81)",
    ringColor: "ring-indigo-600",
  },
  {
    id: "emerald",
    name: "Ngọc lục bảo",
    bubbleClass: "bg-gradient-to-r from-emerald-500 to-teal-600 text-white rounded-br-xs",
    sendBtnClass: "bg-gradient-to-r from-emerald-500 to-teal-600 hover:opacity-90 text-white",
    colorPreview: "linear-gradient(135deg, #10b981, #0d9488)",
    ringColor: "ring-emerald-500",
  },
];

export const DEFAULT_CHAT_THEME = CHAT_THEMES[0];

export function getChatTheme(themeId: string | null | undefined): ChatTheme {
  return CHAT_THEMES.find((t) => t.id === themeId) ?? DEFAULT_CHAT_THEME;
}
