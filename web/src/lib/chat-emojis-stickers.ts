import { parseReplyMessage } from "@/lib/chat-interactions";

export interface EmojiCategory {
  id: string;
  name: string;
  icon: string;
  emojis: string[];
}

export interface StickerItem {
  id: string;
  name: string;
  url: string;
}

export interface StickerPack {
  id: string;
  name: string;
  icon: string;
  stickers: StickerItem[];
}

export const EMOJI_CATEGORIES: EmojiCategory[] = [
  {
    id: "smileys",
    name: "Mặt cười & Cảm xúc",
    icon: "😀",
    emojis: [
      "😀", "😃", "😄", "😁", "😆", "🥹", "😅", "😂", "🤣", "🥲",
      "☺️", "😊", "😇", "🙂", "🙃", "😉", "😌", "😍", "🥰", "😘",
      "😗", "😙", "😚", "😋", "😛", "😝", "😜", "🤪", "🤨", "🧐",
      "🤓", "😎", "🥸", "🤩", "🥳", "😏", "😒", "😞", "😔", "😟",
      "😕", "🙁", "☹️", "😣", "😖", "😫", "😩", "🥺", "😢", "😭",
      "😤", "😠", "😡", "🤬", "🤯", "😳", "🥵", "🥶", "😱", "😨",
      "😰", "😥", "😓", "🤗", "🤔", "🫣", "🤭", "🫢", "🫡", "🤫",
      "🫠", "🤥", "😶", "🫥", "😐", "🫤", "😑", "😬", "😮‍💨", "😴",
    ],
  },
  {
    id: "gestures",
    name: "Cử chỉ & Trái tim",
    icon: "❤️",
    emojis: [
      "👍", "👎", "👏", "🙌", "🫶", "👐", "🤲", "🤝", "👊", "✊",
      "🤛", "🤜", "🤞", "✌️", "🫰", "🤟", "🤘", "👌", "🤌", "🤏",
      "👈", "👉", "👆", "👇", "☝️", "✋", "🤚", "🖐️", "🖖", "👋",
      "🤙", "💪", "🦾", "🖕", "✍️", "🙏", "💅", "🤳", "❤️", "🧡",
      "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔", "❤️‍🔥", "❤️‍🩹",
      "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟", "💌", "💋",
    ],
  },
  {
    id: "animals",
    name: "Động vật & Tự nhiên",
    icon: "🐱",
    emojis: [
      "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐻‍❄️", "🐨",
      "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🐔", "🐧", "🐦", "🐤",
      "🦆", "🦅", "🦉", "🦇", "🐺", "🐗", "🐴", "🦄", "🐝", "🐛",
      "🦋", "🐌", "🐞", "🐜", "🪰", "🪲", "🪳", "🦟", "🦗", "🕷️",
      "🦂", "🐢", "🐍", "🦎", "🦖", "🦕", "🐙", "🦑", "🦐", "🦞",
      "🦀", "🐡", "🐠", "🐟", "🐬", "🐳", "🦈", "🦭", "🐊", "🦩",
      "🌸", "🌺", "🌹", "🌷", "🌻", "🌼", "💐", "🌿", "🍀", "🍁",
    ],
  },
  {
    id: "food",
    name: "Đồ ăn & Thức uống",
    icon: "🍔",
    emojis: [
      "🍏", "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐",
      "🍈", "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🥑", "🥦",
      "🥐", "🍞", "🥖", "🥨", "🧀", "🍳", "🥞", "🧇", "🥓", "🥩",
      "🍗", "🍖", "🌭", "🍔", "🍟", "🍕", "🥪", "🌮", "🌯", "🥗",
      "🥘", "🍝", "🍜", "🍲", "🍛", "🍣", "🍱", "🥟", "🍤", "🍙",
      "🍦", "🍧", "🍨", "🍩", "🍪", "🎂", "🍰", "🧁", "🍫", "🍬",
      "🍭", "🍮", "🍯", "🥛", "☕", "🧃", "🥤", "🧋", "🍺", "🍻",
    ],
  },
  {
    id: "activities",
    name: "Hoạt động & Đồ vật",
    icon: "🎉",
    emojis: [
      "⚽", "🏀", "🏈", "⚾", "🥎", "🎾", "🏐", "🎱", "🏓", "🏸",
      "🥊", "🥋", "🎯", "🏆", "🥇", "🥈", "🥉", "🎫", "🎟️", "🎪",
      "🎭", "🎨", "🎬", "🎤", "🎧", "🎼", "🎹", "🥁", "🎷", "🎺",
      "🎸", "🎮", "🎲", "♟️", "🎳", "🔥", "💥", "✨", "⚡", "🌈",
      "☀️", "🌙", "⭐", "🌟", "🎉", "🎊", "🎁", "🎈", "📱", "💻",
      "📷", "📸", "📹", "💡", "💰", "💎", "🔑", "🔔", "⏰", "⏳",
    ],
  },
];

// Google Noto Animated WebP stickers - transparent, smooth, official Google CDN
export const STICKER_PACKS: StickerPack[] = [
  {
    id: "pack_animated_3d",
    name: "3D Emojis Động",
    icon: "🔥",
    stickers: [
      { id: "3d_haha", name: "Cười sặc sụa", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f602/512.webp" },
      { id: "3d_love", name: "Mê đắm", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f60d/512.webp" },
      { id: "3d_kiss", name: "Bắn tim", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f618/512.webp" },
      { id: "3d_fire", name: "Cháy bùng", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f525/512.webp" },
      { id: "3d_party", name: "Ăn mừng", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f973/512.webp" },
      { id: "3d_like", name: "Tuyệt vời", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f44d/512.webp" },
      { id: "3d_hug", name: "Ôm ấp", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f917/512.webp" },
      { id: "3d_clap", name: "Vỗ tay", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f44f/512.webp" },
      { id: "3d_cry", name: "Khóc ròng", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f62d/512.webp" },
      { id: "3d_mindblown", name: "Bất ngờ", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f92f/512.webp" },
      { id: "3d_cool", name: "Cực ngầu", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f60e/512.webp" },
      { id: "3d_think", name: "Suy ngẫm", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f914/512.webp" },
      { id: "3d_crazy", name: "Nhí nhảnh", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f92a/512.webp" },
      { id: "3d_angry", name: "Tức giận", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f92c/512.webp" },
      { id: "3d_ghost", name: "Hù ma", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f47b/512.webp" },
      { id: "3d_100", name: "100 Điểm", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f4af/512.webp" },
    ],
  },
  {
    id: "pack_animals",
    name: "Thú Cưng Cute",
    icon: "😻",
    stickers: [
      { id: "pet_cat_heart", name: "Mèo yêu", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f63b/512.webp" },
      { id: "pet_cat_smile", name: "Mèo cười", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f638/512.webp" },
      { id: "pet_cat_cry", name: "Mèo mếu", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f63f/512.webp" },
      { id: "pet_cat_pout", name: "Mèo dỗi", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f63e/512.webp" },
      { id: "pet_cat_shock", name: "Mèo hoảng", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f640/512.webp" },
      { id: "pet_fox", name: "Cáo tinh nghịch", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f98a/512.webp" },
      { id: "pet_panda", name: "Gấu trúc", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f43c/512.webp" },
      { id: "pet_frog", name: "Ếch xanh", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f438/512.webp" },
      { id: "pet_monkey_shy", name: "Khỉ thẹn", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f648/512.webp" },
      { id: "pet_unicorn", name: "Kỳ lân", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f984/512.webp" },
    ],
  },
  {
    id: "pack_love",
    name: "Tình Yêu & Thả Thính",
    icon: "💖",
    stickers: [
      { id: "love_sparkle", name: "Tim lấp lánh", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f496/512.webp" },
      { id: "love_beat", name: "Tim rung rinh", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f493/512.webp" },
      { id: "love_arrow", name: "Trúng tên tình yêu", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f498/512.webp" },
      { id: "love_kiss", name: "Nụ hôn nồng", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f48b/512.webp" },
      { id: "love_letter", name: "Thư tỏ tình", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f48c/512.webp" },
      { id: "love_couple", name: "Hai trái tim", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f495/512.webp" },
      { id: "love_ring", name: "Nhẫn cầu hôn", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f48d/512.webp" },
      { id: "love_rose", name: "Bó hồng đỏ", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f940/512.webp" },
    ],
  },
  {
    id: "pack_party",
    name: "Tiệc Tùng & Vui Nhộn",
    icon: "🎉",
    stickers: [
      { id: "party_popper", name: "Pháo hoa giấy", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f389/512.webp" },
      { id: "party_cake", name: "Bánh sinh nhật", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f382/512.webp" },
      { id: "party_gift", name: "Hộp quà to", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f381/512.webp" },
      { id: "party_sparkler", name: "Pháo hoa rực rỡ", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f386/512.webp" },
      { id: "party_trophy", name: "Chiến thắng", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f3c6/512.webp" },
      { id: "party_cheers", name: "Nâng ly cụng", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f942/512.webp" },
      { id: "party_music", name: "Giai điệu vui", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f3b6/512.webp" },
      { id: "party_star", name: "Ngôi sao sáng", url: "https://fonts.gstatic.com/s/e/notoemoji/latest/1f31f/512.webp" },
    ],
  },
];

export function isStickerMessage(text?: string | null): boolean {
  if (!text) return false;
  return text.startsWith("[sticker:") && text.endsWith("]");
}

/** The sticker of the catalogue with this id, or undefined. */
export function findStickerById(id: string): StickerItem | undefined {
  for (const pack of STICKER_PACKS) {
    const found = pack.stickers.find((sticker) => sticker.id === id);
    if (found) return found;
  }
  return undefined;
}

/**
 * Reads a sticker message. A message only names a sticker by id: the picture comes from the
 * catalogue, never from the message text, so nobody can make other people's browsers fetch an
 * address they chose. `url` is null for an id the catalogue does not know.
 */
export function parseStickerMessage(text?: string | null): { id: string; url: string | null } | null {
  if (!text || !isStickerMessage(text)) return null;
  const match = text.match(/^\[sticker:([^:]+):([^\]]+)\]$/);
  if (!match) return null;
  return {
    id: match[1],
    url: findStickerById(match[1])?.url ?? null,
  };
}

export function formatMessagePreview(text?: string | null): string {
  if (!text) return "";
  // A reply travels as "[reply:id:name:quote]" followed by the text: the preview shows only what was written.
  const written = parseReplyMessage(text).text;
  if (!written && text !== written) return "Đã trả lời một tin nhắn";
  if (isStickerMessage(written)) return "[Nhãn dán]";
  return written;
}
