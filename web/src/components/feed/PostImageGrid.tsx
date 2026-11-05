"use client";

import { getImageGridLayout } from "@/lib/image-grid";

interface PostImageGridProps {
  images: string[];
  onOpen: (index: number) => void;
}

/** Facebook-style grid for 2 or more pictures; the last tile shows "+N" when more are hidden. */
export function PostImageGrid({ images, onOpen }: PostImageGridProps) {
  const { visible, hidden } = getImageGridLayout(images.length);
  const shown = images.slice(0, visible);

  // Tile classes per layout. The grid has 6 columns so 2 and 3 tiles can share one row.
  let container = "grid grid-cols-2 gap-0.5";
  let tiles: string[];
  if (visible === 2) {
    tiles = ["aspect-[4/5]", "aspect-[4/5]"];
  } else if (visible === 3) {
    // One tall picture on the left, two stacked on the right.
    container = "grid grid-cols-2 grid-rows-2 gap-0.5 aspect-[4/3]";
    tiles = ["row-span-2 h-full", "h-full", "h-full"];
  } else if (visible === 4) {
    tiles = ["aspect-square", "aspect-square", "aspect-square", "aspect-square"];
  } else {
    // 5: two on top, three below.
    container = "grid grid-cols-6 gap-0.5";
    tiles = [
      "col-span-3 aspect-[4/3]",
      "col-span-3 aspect-[4/3]",
      "col-span-2 aspect-square",
      "col-span-2 aspect-square",
      "col-span-2 aspect-square",
    ];
  }

  return (
    <div className={container}>
      {shown.map((src, index) => (
        <button
          key={`${src}-${index}`}
          type="button"
          onClick={() => onOpen(index)}
          className={`relative w-full overflow-hidden group cursor-pointer ${tiles[index]}`}
          aria-label={`Xem ảnh ${index + 1}`}
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={src}
            alt=""
            className="absolute inset-0 w-full h-full object-cover group-hover:scale-102 transition duration-200"
          />
          {hidden > 0 && index === shown.length - 1 && (
            <div className="absolute inset-0 bg-black/55 flex items-center justify-center text-white text-3xl font-bold">
              +{hidden}
            </div>
          )}
        </button>
      ))}
    </div>
  );
}
