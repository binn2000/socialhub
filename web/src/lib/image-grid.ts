/**
 * How many pictures a post shows in its grid and how many stay hidden behind the "+N" badge.
 * One picture is shown on its own, 2 to 5 are all shown, and from 6 on the grid shows 5 and
 * the last tile says how many more there are (like Facebook).
 */
export const MAX_GRID_IMAGES = 5;

export function getImageGridLayout(count: number): { visible: number; hidden: number } {
  const visible = Math.min(Math.max(count, 0), MAX_GRID_IMAGES);
  return { visible, hidden: Math.max(count - MAX_GRID_IMAGES, 0) };
}
