class EmojiCategory {
  final String id;
  final String name;
  final String icon;
  final List<String> emojis;

  const EmojiCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.emojis,
  });
}

class StickerItem {
  final String id;
  final String name;
  final String url;

  const StickerItem({required this.id, required this.name, required this.url});
}

class StickerPack {
  final String id;
  final String name;
  final String icon;
  final List<StickerItem> stickers;

  const StickerPack({
    required this.id,
    required this.name,
    required this.icon,
    required this.stickers,
  });
}

const List<EmojiCategory> kEmojiCategories = [
  EmojiCategory(
    id: 'smileys',
    name: 'Cảm xúc',
    icon: '😀',
    emojis: [
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '🥹',
      '😅',
      '😂',
      '🤣',
      '🥲',
      '☺️',
      '😊',
      '😇',
      '🙂',
      '🙃',
      '😉',
      '😌',
      '😍',
      '🥰',
      '😘',
      '😗',
      '😙',
      '😚',
      '😋',
      '😛',
      '😝',
      '😜',
      '🤪',
      '🤨',
      '🧐',
      '🤓',
      '😎',
      '🥸',
      '🤩',
      '🥳',
      '😏',
      '😒',
      '😞',
      '😔',
      '😟',
      '😕',
      '🙁',
      '☹️',
      '😣',
      '😖',
      '😫',
      '😩',
      '🥺',
      '😢',
      '😭',
      '😤',
      '😠',
      '😡',
      '🤬',
      '🤯',
      '😳',
      '🥵',
      '🥶',
      '😱',
      '😨',
      '😰',
      '😥',
      '😓',
      '🤗',
      '🤔',
      '🫣',
      '🤭',
      '🫢',
      '🫡',
      '🤫',
    ],
  ),
  EmojiCategory(
    id: 'gestures',
    name: 'Trái tim & Tay',
    icon: '❤️',
    emojis: [
      '👍',
      '👎',
      '👏',
      '🙌',
      '🫶',
      '👐',
      '🤲',
      '🤝',
      '👊',
      '✊',
      '🤛',
      '🤜',
      '🤞',
      '✌️',
      '🫰',
      '🤟',
      '🤘',
      '👌',
      '🤌',
      '🤏',
      '👈',
      '👉',
      '👆',
      '👇',
      '☝️',
      '✋',
      '🤚',
      '🖐️',
      '🖖',
      '👋',
      '🤙',
      '💪',
      '🙏',
      '💅',
      '❤️',
      '🧡',
      '💛',
      '💚',
      '💙',
      '💜',
      '🖤',
      '🤍',
      '🤎',
      '💔',
      '❤️‍🔥',
      '❤️‍🩹',
      '💕',
      '💞',
      '💓',
      '💗',
      '💖',
      '💘',
      '💝',
      '💟',
      '💌',
      '💋',
    ],
  ),
  EmojiCategory(
    id: 'animals',
    name: 'Động vật',
    icon: '🐱',
    emojis: [
      '🐶',
      '🐱',
      '🐭',
      '🐹',
      '🐰',
      '🦊',
      '🐻',
      '🐼',
      '🐻‍❄️',
      '🐨',
      '🐯',
      '🦁',
      '🐮',
      '🐷',
      '🐸',
      '🐵',
      '🐔',
      '🐧',
      '🐦',
      '🐤',
      '🦆',
      '🦅',
      '🦉',
      '🦇',
      '🐺',
      '🐗',
      '🐴',
      '🦄',
      '🐝',
      '🐛',
      '🦋',
      '🐌',
      '🐞',
      '🐜',
      '🪰',
      '🪲',
      '🪳',
      '🦟',
      '🦗',
      '🕷️',
      '🌸',
      '🌺',
      '🌹',
      '🌷',
      '🌻',
      '🌼',
      '💐',
      '🌿',
      '🍀',
      '🍁',
    ],
  ),
  EmojiCategory(
    id: 'food',
    name: 'Đồ ăn',
    icon: '🍔',
    emojis: [
      '🍏',
      '🍎',
      '🍐',
      '🍊',
      '🍋',
      '🍌',
      '🍉',
      '🍇',
      '🍓',
      '🫐',
      '🍈',
      '🍒',
      '🍑',
      '🥭',
      '🍍',
      '🥥',
      '🥝',
      '🍅',
      '🥑',
      '🥦',
      '🥐',
      '🍞',
      '🥖',
      '🥨',
      '🧀',
      '🍳',
      '🥞',
      '🧇',
      '🥓',
      '🥩',
      '🍗',
      '🍖',
      '🌭',
      '🍔',
      '🍟',
      '🍕',
      '🥪',
      '🌮',
      '🌯',
      '🥗',
      '🍦',
      '🍧',
      '🍨',
      '🍩',
      '🍪',
      '🎂',
      '🍰',
      '🧁',
      '🍫',
      '🍬',
    ],
  ),
  EmojiCategory(
    id: 'activities',
    name: 'Hoạt động',
    icon: '🎉',
    emojis: [
      '⚽',
      '🏀',
      '🏈',
      '⚾',
      '🥎',
      '🎾',
      '🏐',
      '🎱',
      '🏓',
      '🏸',
      '🥊',
      '🥋',
      '🎯',
      '🏆',
      '🥇',
      '🥈',
      '🥉',
      '🎫',
      '🎟️',
      '🎪',
      '🎭',
      '🎨',
      '🎬',
      '🎤',
      '🎧',
      '🎼',
      '🎹',
      '🥁',
      '🎷',
      '🎺',
      '🎸',
      '🎮',
      '🎲',
      '🎳',
      '🔥',
      '💥',
      '✨',
      '⚡',
      '🌈',
      '☀️',
      '🌙',
      '⭐',
      '🌟',
      '🎉',
      '🎊',
      '🎁',
      '🎈',
      '📱',
      '💻',
      '💡',
    ],
  ),
];

const List<StickerPack> kStickerPacks = [
  StickerPack(
    id: 'pack_animated_3d',
    name: '3D Emojis Động',
    icon: '🔥',
    stickers: [
      StickerItem(
        id: '3d_haha',
        name: 'Cười sặc sụa',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f602/512.webp',
      ),
      StickerItem(
        id: '3d_love',
        name: 'Mê đắm',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f60d/512.webp',
      ),
      StickerItem(
        id: '3d_kiss',
        name: 'Bắn tim',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f618/512.webp',
      ),
      StickerItem(
        id: '3d_fire',
        name: 'Cháy bùng',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f525/512.webp',
      ),
      StickerItem(
        id: '3d_party',
        name: 'Ăn mừng',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f973/512.webp',
      ),
      StickerItem(
        id: '3d_like',
        name: 'Tuyệt vời',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f44d/512.webp',
      ),
      StickerItem(
        id: '3d_hug',
        name: 'Ôm ấp',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f917/512.webp',
      ),
      StickerItem(
        id: '3d_clap',
        name: 'Vỗ tay',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f44f/512.webp',
      ),
      StickerItem(
        id: '3d_cry',
        name: 'Khóc ròng',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f62d/512.webp',
      ),
      StickerItem(
        id: '3d_mindblown',
        name: 'Bất ngờ',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f92f/512.webp',
      ),
      StickerItem(
        id: '3d_cool',
        name: 'Cực ngầu',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f60e/512.webp',
      ),
      StickerItem(
        id: '3d_think',
        name: 'Suy ngẫm',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f914/512.webp',
      ),
      StickerItem(
        id: '3d_crazy',
        name: 'Nhí nhảnh',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f92a/512.webp',
      ),
      StickerItem(
        id: '3d_angry',
        name: 'Tức giận',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f92c/512.webp',
      ),
      StickerItem(
        id: '3d_ghost',
        name: 'Hù ma',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f47b/512.webp',
      ),
      StickerItem(
        id: '3d_100',
        name: '100 Điểm',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f4af/512.webp',
      ),
    ],
  ),
  StickerPack(
    id: 'pack_animals',
    name: 'Thú Cưng Cute',
    icon: '😻',
    stickers: [
      StickerItem(
        id: 'pet_cat_heart',
        name: 'Mèo yêu',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f63b/512.webp',
      ),
      StickerItem(
        id: 'pet_cat_smile',
        name: 'Mèo cười',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f638/512.webp',
      ),
      StickerItem(
        id: 'pet_cat_cry',
        name: 'Mèo mếu',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f63f/512.webp',
      ),
      StickerItem(
        id: 'pet_cat_pout',
        name: 'Mèo dỗi',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f63e/512.webp',
      ),
      StickerItem(
        id: 'pet_cat_shock',
        name: 'Mèo hoảng',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f640/512.webp',
      ),
      StickerItem(
        id: 'pet_fox',
        name: 'Cáo tinh nghịch',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f98a/512.webp',
      ),
      StickerItem(
        id: 'pet_panda',
        name: 'Gấu trúc',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f43c/512.webp',
      ),
      StickerItem(
        id: 'pet_frog',
        name: 'Ếch xanh',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f438/512.webp',
      ),
      StickerItem(
        id: 'pet_monkey_shy',
        name: 'Khỉ thẹn',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f648/512.webp',
      ),
      StickerItem(
        id: 'pet_unicorn',
        name: 'Kỳ lân',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f984/512.webp',
      ),
    ],
  ),
  StickerPack(
    id: 'pack_love',
    name: 'Tình Yêu',
    icon: '💖',
    stickers: [
      StickerItem(
        id: 'love_sparkle',
        name: 'Tim lấp lánh',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f496/512.webp',
      ),
      StickerItem(
        id: 'love_beat',
        name: 'Tim rung rinh',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f493/512.webp',
      ),
      StickerItem(
        id: 'love_arrow',
        name: 'Trúng tên yêu',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f498/512.webp',
      ),
      StickerItem(
        id: 'love_kiss',
        name: 'Nụ hôn nồng',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f48b/512.webp',
      ),
      StickerItem(
        id: 'love_letter',
        name: 'Thư tỏ tình',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f48c/512.webp',
      ),
      StickerItem(
        id: 'love_couple',
        name: 'Hai trái tim',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f495/512.webp',
      ),
      StickerItem(
        id: 'love_ring',
        name: 'Nhẫn cầu hôn',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f48d/512.webp',
      ),
      StickerItem(
        id: 'love_rose',
        name: 'Bó hồng đỏ',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f940/512.webp',
      ),
    ],
  ),
  StickerPack(
    id: 'pack_party',
    name: 'Tiệc Tùng',
    icon: '🎉',
    stickers: [
      StickerItem(
        id: 'party_popper',
        name: 'Pháo hoa giấy',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f389/512.webp',
      ),
      StickerItem(
        id: 'party_cake',
        name: 'Bánh sinh nhật',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f382/512.webp',
      ),
      StickerItem(
        id: 'party_gift',
        name: 'Hộp quà to',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f381/512.webp',
      ),
      StickerItem(
        id: 'party_sparkler',
        name: 'Pháo hoa sáng',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f386/512.webp',
      ),
      StickerItem(
        id: 'party_trophy',
        name: 'Chiến thắng',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f3c6/512.webp',
      ),
      StickerItem(
        id: 'party_cheers',
        name: 'Nâng ly cụng',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f942/512.webp',
      ),
      StickerItem(
        id: 'party_music',
        name: 'Giai điệu vui',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f3b6/512.webp',
      ),
      StickerItem(
        id: 'party_star',
        name: 'Ngôi sao sáng',
        url: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f31f/512.webp',
      ),
    ],
  ),
];

/// The sticker of the catalogue with this id, or null. A message only names a
/// sticker by id: the picture comes from this catalogue, never from the
/// message text, so nobody can make friends' phones fetch an address they chose.
StickerItem? findStickerById(String id) {
  for (final pack in kStickerPacks) {
    for (final sticker in pack.stickers) {
      if (sticker.id == id) return sticker;
    }
  }
  return null;
}

bool isStickerMessage(String? text) {
  if (text == null || text.isEmpty) return false;
  return text.startsWith('[sticker:') && text.endsWith(']');
}

class ParsedSticker {
  final String id;
  final String url;
  const ParsedSticker({required this.id, required this.url});
}

ParsedSticker? parseStickerMessage(String? text) {
  if (!isStickerMessage(text)) return null;
  final match = RegExp(r'^\[sticker:([^:]+):([^\]]+)\]$').firstMatch(text!);
  if (match == null) return null;
  return ParsedSticker(id: match.group(1) ?? '', url: match.group(2) ?? '');
}

String formatMessagePreview(String? text) {
  if (text == null || text.isEmpty) return '';
  if (isStickerMessage(text)) return '[Nhãn dán]';
  return text;
}
