"use client";

import React, { useState, useRef, useEffect, useCallback } from "react";
import { Smile, Sparkles, X, ChevronLeft, ChevronRight } from "lucide-react";
import {
  EMOJI_CATEGORIES,
  STICKER_PACKS,
  StickerItem,
} from "@/lib/chat-emojis-stickers";

interface EmojiStickerPickerProps {
  onSelectEmoji: (emoji: string) => void;
  onSelectSticker: (sticker: StickerItem) => void;
  onClose: () => void;
}

/**
 * Reusable hook providing mouse drag-to-scroll, wheel horizontal scroll,
 * and edge scroll navigation buttons for horizontal tab bars.
 */
function useDraggableRow() {
  const scrollRef = useRef<HTMLDivElement>(null);
  const [canScrollLeft, setCanScrollLeft] = useState(false);
  const [canScrollRight, setCanScrollRight] = useState(false);

  const checkScroll = useCallback(() => {
    const el = scrollRef.current;
    if (!el) return;
    setCanScrollLeft(el.scrollLeft > 4);
    setCanScrollRight(el.scrollLeft + el.clientWidth < el.scrollWidth - 4);
  }, []);

  useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;
    checkScroll();
    el.addEventListener("scroll", checkScroll, { passive: true });
    window.addEventListener("resize", checkScroll);
    return () => {
      el.removeEventListener("scroll", checkScroll);
      window.removeEventListener("resize", checkScroll);
    };
  }, [checkScroll]);

  const stateRef = useRef({
    isDown: false,
    startX: 0,
    scrollLeft: 0,
    hasDragged: false,
  });

  const onMouseDown = (e: React.MouseEvent) => {
    const el = scrollRef.current;
    if (!el) return;
    stateRef.current.isDown = true;
    stateRef.current.hasDragged = false;
    stateRef.current.startX = e.pageX - el.offsetLeft;
    stateRef.current.scrollLeft = el.scrollLeft;
  };

  const onMouseMove = (e: React.MouseEvent) => {
    if (!stateRef.current.isDown) return;
    const el = scrollRef.current;
    if (!el) return;
    const x = e.pageX - el.offsetLeft;
    const walk = (x - stateRef.current.startX) * 1.3;
    if (Math.abs(walk) > 5) {
      stateRef.current.hasDragged = true;
    }
    el.scrollLeft = stateRef.current.scrollLeft - walk;
    checkScroll();
  };

  const onMouseUp = () => {
    stateRef.current.isDown = false;
  };

  const onWheel = (e: React.WheelEvent) => {
    const el = scrollRef.current;
    if (!el) return;
    if (e.deltaY !== 0) {
      el.scrollLeft += e.deltaY;
      checkScroll();
    }
  };

  const scrollByAmount = (amount: number) => {
    scrollRef.current?.scrollBy({ left: amount, behavior: "smooth" });
  };

  return {
    scrollRef,
    canScrollLeft,
    canScrollRight,
    onMouseDown,
    onMouseMove,
    onMouseUp,
    onWheel,
    scrollByAmount,
    hasDragged: () => stateRef.current.hasDragged,
    checkScroll,
  };
}

export function EmojiStickerPicker({
  onSelectEmoji,
  onSelectSticker,
  onClose,
}: EmojiStickerPickerProps) {
  const [activeTab, setActiveTab] = useState<"emojis" | "stickers">("emojis");
  const [activeEmojiCat, setActiveEmojiCat] = useState<string>(EMOJI_CATEGORIES[0].id);
  const [activeStickerPack, setActiveStickerPack] = useState<string>(STICKER_PACKS[0].id);

  const emojiRow = useDraggableRow();
  const stickerRow = useDraggableRow();

  const currentCategory = EMOJI_CATEGORIES.find((c) => c.id === activeEmojiCat) || EMOJI_CATEGORIES[0];
  const currentPack = STICKER_PACKS.find((p) => p.id === activeStickerPack) || STICKER_PACKS[0];

  // The rows are new objects every render; keep them in a ref so the effect
  // runs only when the selection changes, not each time the user scrolls a row.
  const rowsRef = useRef({ emojiRow, stickerRow });
  rowsRef.current = { emojiRow, stickerRow };

  // Auto-scroll selected tab into view when active tab/category changes
  useEffect(() => {
    const tabId = activeTab === "emojis" ? `tab-cat-${activeEmojiCat}` : `tab-pack-${activeStickerPack}`;
    const el = document.getElementById(tabId);
    if (el) {
      el.scrollIntoView({ behavior: "smooth", inline: "center", block: "nearest" });
    }
    // Recheck scroll boundaries
    const timer = setTimeout(() => {
      if (activeTab === "emojis") rowsRef.current.emojiRow.checkScroll();
      else rowsRef.current.stickerRow.checkScroll();
    }, 200);
    return () => clearTimeout(timer);
  }, [activeTab, activeEmojiCat, activeStickerPack]);

  // Swipe / Drag left-right handlers on content area to switch categories/tabs
  const contentDragRef = useRef<{
    startX: number;
    startY: number;
    isDown: boolean;
  }>({ startX: 0, startY: 0, isDown: false });

  const handleNextCategoryOrTab = useCallback(() => {
    if (activeTab === "emojis") {
      const idx = EMOJI_CATEGORIES.findIndex((c) => c.id === activeEmojiCat);
      if (idx < EMOJI_CATEGORIES.length - 1) {
        setActiveEmojiCat(EMOJI_CATEGORIES[idx + 1].id);
      } else {
        setActiveTab("stickers");
      }
    } else {
      const idx = STICKER_PACKS.findIndex((p) => p.id === activeStickerPack);
      if (idx < STICKER_PACKS.length - 1) {
        setActiveStickerPack(STICKER_PACKS[idx + 1].id);
      }
    }
  }, [activeTab, activeEmojiCat, activeStickerPack]);

  const handlePrevCategoryOrTab = useCallback(() => {
    if (activeTab === "stickers") {
      const idx = STICKER_PACKS.findIndex((p) => p.id === activeStickerPack);
      if (idx > 0) {
        setActiveStickerPack(STICKER_PACKS[idx - 1].id);
      } else {
        setActiveTab("emojis");
        setActiveEmojiCat(EMOJI_CATEGORIES[EMOJI_CATEGORIES.length - 1].id);
      }
    } else {
      const idx = EMOJI_CATEGORIES.findIndex((c) => c.id === activeEmojiCat);
      if (idx > 0) {
        setActiveEmojiCat(EMOJI_CATEGORIES[idx - 1].id);
      }
    }
  }, [activeTab, activeEmojiCat, activeStickerPack]);

  const handleContentMouseDown = (e: React.MouseEvent) => {
    contentDragRef.current = {
      startX: e.clientX,
      startY: e.clientY,
      isDown: true,
    };
  };

  const handleContentMouseUp = (e: React.MouseEvent) => {
    if (!contentDragRef.current.isDown) return;
    contentDragRef.current.isDown = false;
    const diffX = e.clientX - contentDragRef.current.startX;
    const diffY = e.clientY - contentDragRef.current.startY;

    // Detect horizontal swipe (> 50px and horizontally dominant)
    if (Math.abs(diffX) > 50 && Math.abs(diffX) > Math.abs(diffY) * 1.4) {
      if (diffX < 0) {
        handleNextCategoryOrTab();
      } else {
        handlePrevCategoryOrTab();
      }
    }
  };

  const handleContentTouchStart = (e: React.TouchEvent) => {
    const touch = e.touches[0];
    contentDragRef.current = {
      startX: touch.clientX,
      startY: touch.clientY,
      isDown: true,
    };
  };

  const handleContentTouchEnd = (e: React.TouchEvent) => {
    if (!contentDragRef.current.isDown) return;
    contentDragRef.current.isDown = false;
    const touch = e.changedTouches[0];
    const diffX = touch.clientX - contentDragRef.current.startX;
    const diffY = touch.clientY - contentDragRef.current.startY;

    if (Math.abs(diffX) > 50 && Math.abs(diffX) > Math.abs(diffY) * 1.4) {
      if (diffX < 0) {
        handleNextCategoryOrTab();
      } else {
        handlePrevCategoryOrTab();
      }
    }
  };

  const currentCatIndex = EMOJI_CATEGORIES.findIndex((c) => c.id === activeEmojiCat);
  const currentPackIndex = STICKER_PACKS.findIndex((p) => p.id === activeStickerPack);

  return (
    <div className="flex flex-col h-80 sm:h-96 w-full max-w-sm sm:max-w-md bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl shadow-xl overflow-hidden animate-in fade-in zoom-in-95 duration-150 select-none">
      {/* Top Header: Main Tabs & Close */}
      <div className="flex items-center justify-between px-3 py-2 border-b border-appBorder-light dark:border-appBorder-dark bg-surface-muted/50 dark:bg-surface-dark-muted/40">
        <div className="flex items-center gap-1 bg-surface-muted dark:bg-surface-dark p-1 rounded-xl">
          <button
            type="button"
            onClick={() => setActiveTab("emojis")}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition flex items-center gap-1.5 cursor-pointer ${
              activeTab === "emojis"
                ? "bg-white dark:bg-surface-dark-muted text-brand shadow-sm"
                : "text-appText-secondary hover:text-appText-primary dark:hover:text-white"
            }`}
          >
            <Smile className="w-4 h-4" />
            <span>Biểu tượng</span>
          </button>

          <button
            type="button"
            onClick={() => setActiveTab("stickers")}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition flex items-center gap-1.5 cursor-pointer ${
              activeTab === "stickers"
                ? "bg-white dark:bg-surface-dark-muted text-brand shadow-sm"
                : "text-appText-secondary hover:text-appText-primary dark:hover:text-white"
            }`}
          >
            <Sparkles className="w-4 h-4 text-amber-500" />
            <span>Nhãn dán 3D</span>
          </button>
        </div>

        <button
          type="button"
          onClick={onClose}
          className="p-1.5 rounded-lg text-appText-secondary hover:text-appText-primary dark:hover:text-white hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition cursor-pointer"
          title="Đóng"
        >
          <X className="w-4 h-4" />
        </button>
      </div>

      {/* Content Area with Horizontal Swipe & Tab Bar */}
      <div
        className="flex-1 overflow-hidden flex flex-col"
        onMouseDown={handleContentMouseDown}
        onMouseUp={handleContentMouseUp}
        onTouchStart={handleContentTouchStart}
        onTouchEnd={handleContentTouchEnd}
      >
        {activeTab === "emojis" ? (
          <>
            {/* Draggable Category Selector Bar with Left/Right Arrows */}
            <div className="relative group/bar border-b border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark">
              {emojiRow.canScrollLeft && (
                <button
                  type="button"
                  onClick={() => emojiRow.scrollByAmount(-130)}
                  className="absolute left-1 top-1/2 -translate-y-1/2 z-10 w-6 h-6 rounded-full bg-white/95 dark:bg-surface-dark/95 shadow-md border border-appBorder-light dark:border-appBorder-dark flex items-center justify-center text-appText-secondary hover:text-appText-primary transition cursor-pointer"
                  title="Cuộn sang trái"
                >
                  <ChevronLeft className="w-3.5 h-3.5" />
                </button>
              )}

              <div
                ref={emojiRow.scrollRef}
                onMouseDown={emojiRow.onMouseDown}
                onMouseMove={emojiRow.onMouseMove}
                onMouseUp={emojiRow.onMouseUp}
                onMouseLeave={emojiRow.onMouseUp}
                onWheel={emojiRow.onWheel}
                className="flex items-center gap-1.5 px-3 py-2 overflow-x-auto scrollbar-none cursor-grab active:cursor-grabbing select-none"
              >
                {EMOJI_CATEGORIES.map((cat) => (
                  <button
                    key={cat.id}
                    id={`tab-cat-${cat.id}`}
                    type="button"
                    onClick={() => {
                      if (emojiRow.hasDragged()) return;
                      setActiveEmojiCat(cat.id);
                    }}
                    className={`px-3 py-1.5 rounded-xl text-xs font-medium whitespace-nowrap transition flex items-center gap-1.5 shrink-0 cursor-pointer ${
                      activeEmojiCat === cat.id
                        ? "bg-brand/10 text-brand dark:bg-brand/20 dark:text-brand-light font-semibold border border-brand/20 shadow-sm"
                        : "text-appText-secondary hover:bg-surface-muted dark:hover:bg-surface-dark-muted border border-transparent"
                    }`}
                  >
                    <span>{cat.icon}</span>
                    <span>{cat.name}</span>
                  </button>
                ))}
              </div>

              {emojiRow.canScrollRight && (
                <button
                  type="button"
                  onClick={() => emojiRow.scrollByAmount(130)}
                  className="absolute right-1 top-1/2 -translate-y-1/2 z-10 w-6 h-6 rounded-full bg-white/95 dark:bg-surface-dark/95 shadow-md border border-appBorder-light dark:border-appBorder-dark flex items-center justify-center text-appText-secondary hover:text-appText-primary transition cursor-pointer"
                  title="Cuộn sang phải"
                >
                  <ChevronRight className="w-3.5 h-3.5" />
                </button>
              )}
            </div>

            {/* Emojis Grid */}
            <div className="flex-1 overflow-y-auto p-3 grid grid-cols-7 sm:grid-cols-8 gap-1.5 text-center content-start">
              {currentCategory.emojis.map((emoji, idx) => (
                <button
                  key={`${emoji}-${idx}`}
                  type="button"
                  onClick={() => onSelectEmoji(emoji)}
                  className="w-10 h-10 text-2xl flex items-center justify-center rounded-xl hover:bg-surface-muted dark:hover:bg-surface-dark-muted hover:scale-125 active:scale-95 transition-transform cursor-pointer"
                >
                  {emoji}
                </button>
              ))}
            </div>

            {/* Bottom Swipe Hint & Category Dots */}
            <div className="px-3 py-1.5 border-t border-appBorder-light dark:border-appBorder-dark/60 bg-surface-muted/30 dark:bg-surface-dark-muted/20 flex items-center justify-between text-[11px] text-appText-secondary">
              <span className="truncate">{currentCategory.name}</span>
              <div className="flex items-center gap-1">
                {EMOJI_CATEGORIES.map((cat, i) => (
                  <button
                    key={cat.id}
                    type="button"
                    onClick={() => setActiveEmojiCat(cat.id)}
                    className={`w-1.5 h-1.5 rounded-full transition-all cursor-pointer ${
                      i === currentCatIndex ? "w-3 bg-brand" : "bg-appText-secondary/30 hover:bg-appText-secondary/60"
                    }`}
                    title={cat.name}
                  />
                ))}
              </div>
            </div>
          </>
        ) : (
          <>
            {/* Draggable Sticker Pack Selector Bar with Left/Right Arrows */}
            <div className="relative group/bar border-b border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark">
              {stickerRow.canScrollLeft && (
                <button
                  type="button"
                  onClick={() => stickerRow.scrollByAmount(-130)}
                  className="absolute left-1 top-1/2 -translate-y-1/2 z-10 w-6 h-6 rounded-full bg-white/95 dark:bg-surface-dark/95 shadow-md border border-appBorder-light dark:border-appBorder-dark flex items-center justify-center text-appText-secondary hover:text-appText-primary transition cursor-pointer"
                  title="Cuộn sang trái"
                >
                  <ChevronLeft className="w-3.5 h-3.5" />
                </button>
              )}

              <div
                ref={stickerRow.scrollRef}
                onMouseDown={stickerRow.onMouseDown}
                onMouseMove={stickerRow.onMouseMove}
                onMouseUp={stickerRow.onMouseUp}
                onMouseLeave={stickerRow.onMouseUp}
                onWheel={stickerRow.onWheel}
                className="flex items-center gap-1.5 px-3 py-2 overflow-x-auto scrollbar-none cursor-grab active:cursor-grabbing select-none"
              >
                {STICKER_PACKS.map((pack) => (
                  <button
                    key={pack.id}
                    id={`tab-pack-${pack.id}`}
                    type="button"
                    onClick={() => {
                      if (stickerRow.hasDragged()) return;
                      setActiveStickerPack(pack.id);
                    }}
                    className={`px-3 py-1.5 rounded-xl text-xs font-medium whitespace-nowrap transition flex items-center gap-1.5 shrink-0 cursor-pointer ${
                      activeStickerPack === pack.id
                        ? "bg-brand/10 text-brand dark:bg-brand/20 dark:text-brand-light font-semibold border border-brand/20 shadow-sm"
                        : "text-appText-secondary hover:bg-surface-muted dark:hover:bg-surface-dark-muted border border-transparent"
                    }`}
                  >
                    <span className="text-sm">{pack.icon}</span>
                    <span>{pack.name}</span>
                  </button>
                ))}
              </div>

              {stickerRow.canScrollRight && (
                <button
                  type="button"
                  onClick={() => stickerRow.scrollByAmount(130)}
                  className="absolute right-1 top-1/2 -translate-y-1/2 z-10 w-6 h-6 rounded-full bg-white/95 dark:bg-surface-dark/95 shadow-md border border-appBorder-light dark:border-appBorder-dark flex items-center justify-center text-appText-secondary hover:text-appText-primary transition cursor-pointer"
                  title="Cuộn sang phải"
                >
                  <ChevronRight className="w-3.5 h-3.5" />
                </button>
              )}
            </div>

            {/* Stickers Grid */}
            <div className="flex-1 overflow-y-auto p-3 grid grid-cols-3 sm:grid-cols-4 gap-3 content-start">
              {currentPack.stickers.map((stk) => (
                <button
                  key={stk.id}
                  type="button"
                  onClick={() => onSelectSticker(stk)}
                  className="group flex flex-col items-center p-2 rounded-2xl hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition active:scale-95 cursor-pointer"
                  title={stk.name}
                >
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={stk.url}
                    alt={stk.name}
                    className="w-16 h-16 sm:w-20 sm:h-20 object-contain group-hover:scale-110 transition-transform duration-200 pointer-events-none"
                    loading="lazy"
                  />
                  <span className="text-[11px] text-appText-secondary group-hover:text-appText-primary dark:group-hover:text-white mt-1 truncate max-w-full">
                    {stk.name}
                  </span>
                </button>
              ))}
            </div>

            {/* Bottom Swipe Hint & Pack Dots */}
            <div className="px-3 py-1.5 border-t border-appBorder-light dark:border-appBorder-dark/60 bg-surface-muted/30 dark:bg-surface-dark-muted/20 flex items-center justify-between text-[11px] text-appText-secondary">
              <span className="truncate">{currentPack.name}</span>
              <div className="flex items-center gap-1">
                {STICKER_PACKS.map((pack, i) => (
                  <button
                    key={pack.id}
                    type="button"
                    onClick={() => setActiveStickerPack(pack.id)}
                    className={`w-1.5 h-1.5 rounded-full transition-all cursor-pointer ${
                      i === currentPackIndex ? "w-3 bg-brand" : "bg-appText-secondary/30 hover:bg-appText-secondary/60"
                    }`}
                    title={pack.name}
                  />
                ))}
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
