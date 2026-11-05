"use client";

import React, { useState, useMemo, useRef, useCallback, useEffect } from "react";
import { X, Search, ChevronLeft, ChevronRight } from "lucide-react";
import { EMOJI_CATEGORIES } from "@/lib/chat-emojis-stickers";

interface QuickReactionPickerModalProps {
  isOpen: boolean;
  currentEmoji: string;
  onSelectEmoji: (emoji: string) => void;
  onClose: () => void;
}

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

// The inner component only exists while the modal is open: the draggable row
// attaches its scroll listener on mount, which needs the element to exist.
export function QuickReactionPickerModal(props: QuickReactionPickerModalProps) {
  if (!props.isOpen) return null;
  return <QuickReactionPickerContent {...props} />;
}

function QuickReactionPickerContent({
  currentEmoji,
  onSelectEmoji,
  onClose,
}: QuickReactionPickerModalProps) {
  const [activeCategory, setActiveCategory] = useState(EMOJI_CATEGORIES[0].id);
  const [searchQuery, setSearchQuery] = useState("");
  const categoryRow = useDraggableRow();

  // Scroll active category tab into view when activeCategory changes
  // `categoryRow` is a new object every render, so it must not be a dependency:
  // the effect would re-centre the tab each time the user scrolls the row.
  const categoryRowRef = useRef(categoryRow);
  categoryRowRef.current = categoryRow;
  useEffect(() => {
    const row = categoryRowRef.current;
    if (!row.scrollRef.current) return;
    const activeBtn = row.scrollRef.current.querySelector(
      `[data-category-id="${activeCategory}"]`
    );
    if (activeBtn) {
      activeBtn.scrollIntoView({
        behavior: "smooth",
        inline: "center",
        block: "nearest",
      });
    }
    const timer = setTimeout(() => row.checkScroll(), 150);
    return () => clearTimeout(timer);
  }, [activeCategory]);

  const filteredEmojis = useMemo(() => {
    if (!searchQuery.trim()) return null;
    const query = searchQuery.trim().toLowerCase();
    const results: string[] = [];
    for (const cat of EMOJI_CATEGORIES) {
      if (cat.name.toLowerCase().includes(query)) {
        results.push(...cat.emojis);
      }
    }
    if (results.length === 0) {
      for (const cat of EMOJI_CATEGORIES) {
        results.push(...cat.emojis);
      }
    }
    return Array.from(new Set(results));
  }, [searchQuery]);

  // Content area swipe / drag left-right handlers to switch categories
  const contentDragRef = useRef<{
    startX: number;
    startY: number;
    isDown: boolean;
  }>({ startX: 0, startY: 0, isDown: false });

  const handleNextCategory = useCallback(() => {
    const idx = EMOJI_CATEGORIES.findIndex((c) => c.id === activeCategory);
    if (idx < EMOJI_CATEGORIES.length - 1) {
      setActiveCategory(EMOJI_CATEGORIES[idx + 1].id);
    }
  }, [activeCategory]);

  const handlePrevCategory = useCallback(() => {
    const idx = EMOJI_CATEGORIES.findIndex((c) => c.id === activeCategory);
    if (idx > 0) {
      setActiveCategory(EMOJI_CATEGORIES[idx - 1].id);
    }
  }, [activeCategory]);

  const handleContentMouseDown = (e: React.MouseEvent) => {
    contentDragRef.current = {
      startX: e.clientX,
      startY: e.clientY,
      isDown: true,
    };
  };

  const handleContentMouseUp = (e: React.MouseEvent) => {
    if (!contentDragRef.current.isDown) return;
    const diffX = e.clientX - contentDragRef.current.startX;
    const diffY = e.clientY - contentDragRef.current.startY;
    contentDragRef.current.isDown = false;

    // Must be a predominantly horizontal swipe of at least 45px
    if (Math.abs(diffX) > 45 && Math.abs(diffX) > Math.abs(diffY) * 1.5) {
      if (diffX < 0) {
        handleNextCategory();
      } else {
        handlePrevCategory();
      }
    }
  };

  const handleContentTouchStart = (e: React.TouchEvent) => {
    if (e.touches.length === 1) {
      contentDragRef.current = {
        startX: e.touches[0].clientX,
        startY: e.touches[0].clientY,
        isDown: true,
      };
    }
  };

  const handleContentTouchEnd = (e: React.TouchEvent) => {
    if (!contentDragRef.current.isDown) return;
    const touch = e.changedTouches[0];
    const diffX = touch.clientX - contentDragRef.current.startX;
    const diffY = touch.clientY - contentDragRef.current.startY;
    contentDragRef.current.isDown = false;

    if (Math.abs(diffX) > 40 && Math.abs(diffX) > Math.abs(diffY) * 1.5) {
      if (diffX < 0) {
        handleNextCategory();
      } else {
        handlePrevCategory();
      }
    }
  };

  const currentCategoryData =
    EMOJI_CATEGORIES.find((c) => c.id === activeCategory) || EMOJI_CATEGORIES[0];

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fade-in"
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div
        className="w-full max-w-md bg-white dark:bg-surface-dark rounded-2xl shadow-2xl border border-appBorder-light dark:border-appBorder-dark overflow-hidden flex flex-col max-h-[85vh] animate-scale-in"
        role="dialog"
        aria-modal="true"
      >
        {/* Header */}
        <div className="p-4 border-b border-appBorder-light dark:border-appBorder-dark flex items-center justify-between">
          <div>
            <h3 className="text-base font-bold text-appText-primary dark:text-white leading-tight">
              Biểu tượng cảm xúc nhanh
            </h3>
            <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary mt-0.5">
              Chọn bất kỳ biểu tượng nào để thay thế nút gửi nhanh
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded-lg text-appText-secondary hover:text-appText-primary dark:hover:text-white hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Search Bar */}
        <div className="px-4 pt-3 pb-2">
          <div className="relative">
            <Search className="w-4 h-4 text-appText-secondary absolute left-3 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Tìm kiếm biểu tượng cảm xúc..."
              className="w-full pl-9 pr-4 py-2 text-xs rounded-xl bg-surface-muted dark:bg-surface-dark-muted border border-appBorder-light dark:border-appBorder-dark text-appText-primary dark:text-white placeholder-appText-secondary focus:outline-none focus:ring-1 focus:ring-brand"
            />
            {searchQuery && (
              <button
                type="button"
                onClick={() => setSearchQuery("")}
                className="absolute right-2.5 top-1/2 -translate-y-1/2 text-appText-secondary hover:text-appText-primary p-0.5 cursor-pointer"
              >
                <X className="w-3.5 h-3.5" />
              </button>
            )}
          </div>
        </div>

        {/* Draggable Category Selector Bar with Navigation Arrows */}
        {!searchQuery && (
          <div className="relative group/bar border-b border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark">
            {/* Scroll Left Button */}
            {categoryRow.canScrollLeft && (
              <button
                type="button"
                onClick={() => categoryRow.scrollByAmount(-150)}
                className="absolute left-1 top-1/2 -translate-y-1/2 z-10 w-6 h-6 rounded-full bg-surface-light/90 dark:bg-surface-dark/90 shadow-md border border-appBorder-light dark:border-appBorder-dark flex items-center justify-center text-appText-primary dark:text-white hover:scale-110 transition cursor-pointer"
                title="Trượt sang trái"
              >
                <ChevronLeft className="w-3.5 h-3.5" />
              </button>
            )}

            {/* Scroll Right Button */}
            {categoryRow.canScrollRight && (
              <button
                type="button"
                onClick={() => categoryRow.scrollByAmount(150)}
                className="absolute right-1 top-1/2 -translate-y-1/2 z-10 w-6 h-6 rounded-full bg-surface-light/90 dark:bg-surface-dark/90 shadow-md border border-appBorder-light dark:border-appBorder-dark flex items-center justify-center text-appText-primary dark:text-white hover:scale-110 transition cursor-pointer"
                title="Trượt sang phải"
              >
                <ChevronRight className="w-3.5 h-3.5" />
              </button>
            )}

            <div
              ref={categoryRow.scrollRef}
              onMouseDown={categoryRow.onMouseDown}
              onMouseMove={categoryRow.onMouseMove}
              onMouseUp={categoryRow.onMouseUp}
              onMouseLeave={categoryRow.onMouseUp}
              onWheel={categoryRow.onWheel}
              className="flex items-center gap-1.5 px-3 py-2 overflow-x-auto scrollbar-none cursor-grab active:cursor-grabbing select-none"
            >
              {EMOJI_CATEGORIES.map((cat) => {
                const isActive = cat.id === activeCategory;
                return (
                  <button
                    key={cat.id}
                    data-category-id={cat.id}
                    type="button"
                    onClick={() => {
                      if (!categoryRow.hasDragged()) {
                        setActiveCategory(cat.id);
                      }
                    }}
                    className={`px-2.5 py-1.5 rounded-xl text-xs font-medium flex items-center gap-1.5 whitespace-nowrap transition cursor-pointer shrink-0 ${
                      isActive
                        ? "bg-brand/10 text-brand font-semibold ring-1 ring-brand/30"
                        : "text-appText-secondary hover:text-appText-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted"
                    }`}
                  >
                    <span className="text-base pointer-events-none">{cat.icon}</span>
                    <span className="text-xs font-medium pointer-events-none">{cat.name}</span>
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {/* Emojis Grid Area with Horizontal Swipe & Drag support */}
        <div
          className="flex-1 overflow-y-auto p-4 min-h-[260px] max-h-[380px] select-none"
          onMouseDown={handleContentMouseDown}
          onMouseUp={handleContentMouseUp}
          onTouchStart={handleContentTouchStart}
          onTouchEnd={handleContentTouchEnd}
        >
          {searchQuery && filteredEmojis ? (
            <div>
              <div className="text-[11px] font-bold uppercase tracking-wider text-appText-secondary mb-3">
                Kết quả ({filteredEmojis.length})
              </div>
              <div className="grid grid-cols-7 sm:grid-cols-8 gap-2">
                {filteredEmojis.map((emoji) => {
                  const isCurrent = emoji === currentEmoji;
                  return (
                    <button
                      key={emoji}
                      type="button"
                      onClick={() => {
                        onSelectEmoji(emoji);
                        onClose();
                      }}
                      className={`h-11 flex items-center justify-center text-2xl rounded-xl hover:bg-surface-muted dark:hover:bg-surface-dark-muted hover:scale-125 transition cursor-pointer active:scale-95 ${
                        isCurrent
                          ? "bg-brand/15 ring-2 ring-brand scale-110 shadow-sm"
                          : ""
                      }`}
                      title={`Chọn ${emoji}`}
                    >
                      {emoji}
                    </button>
                  );
                })}
              </div>
            </div>
          ) : (
            <div>
              <div className="flex items-center justify-between mb-3">
                <span className="text-[11px] font-bold uppercase tracking-wider text-appText-secondary">
                  {currentCategoryData.name}
                </span>
                <span className="text-[11px] text-appText-secondary italic">
                  (Vuốt hoặc trượt chuột để qua tab khác)
                </span>
              </div>
              <div className="grid grid-cols-7 sm:grid-cols-8 gap-2">
                {currentCategoryData.emojis.map((emoji) => {
                  const isCurrent = emoji === currentEmoji;
                  return (
                    <button
                      key={emoji}
                      type="button"
                      onClick={() => {
                        onSelectEmoji(emoji);
                        onClose();
                      }}
                      className={`h-11 flex items-center justify-center text-2xl rounded-xl hover:bg-surface-muted dark:hover:bg-surface-dark-muted hover:scale-125 transition cursor-pointer active:scale-95 ${
                        isCurrent
                          ? "bg-brand/15 ring-2 ring-brand scale-110 shadow-sm"
                          : ""
                      }`}
                      title={`Chọn ${emoji}`}
                    >
                      {emoji}
                    </button>
                  );
                })}
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="p-3 border-t border-appBorder-light dark:border-appBorder-dark bg-surface-muted/30 dark:bg-surface-dark-muted/30 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span className="text-xs text-appText-secondary">Đang chọn:</span>
            <span className="text-xl">{currentEmoji}</span>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-1.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark text-xs font-medium text-appText-primary dark:text-white hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition cursor-pointer"
          >
            Đóng
          </button>
        </div>
      </div>
    </div>
  );
}
