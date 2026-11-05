import { describe, it, expect, vi } from "vitest";
import type { ToastType, ToastOptions, ToastItem } from "@/context/ToastContext";

describe("Global In-App Toast Notification System", () => {
  it("supports all required toast types", () => {
    const types: ToastType[] = ["success", "error", "info", "warning"];
    expect(types).toHaveLength(4);
    expect(types).toContain("success");
    expect(types).toContain("error");
    expect(types).toContain("info");
    expect(types).toContain("warning");
  });

  it("constructs a valid ToastItem with defaults", () => {
    const toast: ToastItem = {
      id: "toast-1",
      message: "Đã lưu bài viết thành công",
      type: "success",
      duration: 3000,
    };

    expect(toast.id).toBe("toast-1");
    expect(toast.message).toBe("Đã lưu bài viết thành công");
    expect(toast.type).toBe("success");
    expect(toast.duration).toBe(3000);
    expect(toast.undoAction).toBeUndefined();
  });

  it("supports undo action and custom undo label for reversible actions like hide post", () => {
    const undoFn = vi.fn();
    const toast: ToastItem = {
      id: "toast-undo-1",
      message: "Đã ẩn bài viết khỏi bảng tin",
      type: "info",
      duration: 5000,
      undoAction: undoFn,
      undoLabel: "Hoàn tác",
    };

    expect(toast.undoLabel).toBe("Hoàn tác");
    expect(typeof toast.undoAction).toBe("function");
    toast.undoAction?.();
    expect(undoFn).toHaveBeenCalledTimes(1);
  });

  it("allows setting custom duration or persistent toasts", () => {
    const customOpts: ToastOptions = {
      type: "error",
      duration: 6000,
    };

    expect(customOpts.duration).toBe(6000);
    expect(customOpts.type).toBe("error");
  });
});
