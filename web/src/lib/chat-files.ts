/**
 * What `POST /conversations/{id}/messages` accepts as attachments (openapi.yaml,
 * ConversationController::send): up to 5 files of at most 10 MB, pictures as
 * jpg/png/webp and a fixed list of document types. One file outside the list makes
 * the server refuse the whole message, so pasted and dropped files are checked here.
 */
export const MAX_CHAT_FILES = 5;
export const MAX_CHAT_FILE_BYTES = 10 * 1024 * 1024;

const IMAGE_EXTENSIONS = ["jpg", "jpeg", "png", "webp"];
const DOCUMENT_EXTENSIONS = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "csv", "zip"];

/** For the file picker, so it only offers what can be sent. */
export const CHAT_FILE_ACCEPT = [...IMAGE_EXTENSIONS, ...DOCUMENT_EXTENSIONS].map((e) => `.${e}`).join(",");

const IMAGE_TYPES: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
};

function extensionOf(name: string): string {
  const dot = name.lastIndexOf(".");
  return dot < 0 ? "" : name.slice(dot + 1).toLowerCase();
}

export type RejectReason = "type" | "size";

export interface CheckedFiles {
  accepted: File[];
  rejected: { file: File; reason: RejectReason }[];
}

export function checkChatFiles<T extends Pick<File, "name" | "size">>(files: T[]): { accepted: T[]; rejected: { file: T; reason: RejectReason }[] } {
  const accepted: T[] = [];
  const rejected: { file: T; reason: RejectReason }[] = [];
  for (const file of files) {
    const ext = extensionOf(file.name);
    if (![...IMAGE_EXTENSIONS, ...DOCUMENT_EXTENSIONS].includes(ext)) {
      rejected.push({ file, reason: "type" });
    } else if (file.size > MAX_CHAT_FILE_BYTES) {
      rejected.push({ file, reason: "size" });
    } else {
      accepted.push(file);
    }
  }
  return { accepted, rejected };
}

/**
 * A pasted picture usually comes without a useful name ("image.png", or none). It gets
 * one whose extension matches its real type, so the server's extension check passes;
 * a type the server does not take (gif, heic, bmp…) returns null.
 */
export function pastedImageName(type: string, name: string, now: Date = new Date()): string | null {
  const ext = IMAGE_TYPES[type];
  if (!ext) return null;
  const stamp = now.toISOString().replace(/[:.]/g, "-");
  const keep = name && name !== "image.png" && extensionOf(name) === ext;
  return keep ? name : `anh-dan-${stamp}.${ext}`;
}

export function namePastedImage(file: File, now: Date = new Date()): File | null {
  const name = pastedImageName(file.type, file.name, now);
  return name === null ? null : new File([file], name, { type: file.type });
}

/** A short Vietnamese explanation of why some files were left out. */
export function describeRejected(rejected: { file: Pick<File, "name">; reason: RejectReason }[]): string | null {
  if (rejected.length === 0) return null;
  const names = rejected.map((r) => r.file.name || "tệp").slice(0, 3).join(", ");
  const tooBig = rejected.every((r) => r.reason === "size");
  return tooBig
    ? `Tệp quá 10 MB nên không gửi được: ${names}`
    : `Không gửi được loại tệp này: ${names} (chỉ ảnh JPG/PNG/WebP, PDF, Word, Excel, PowerPoint, TXT, CSV, ZIP, tối đa 10 MB)`;
}

/** Files and their image previews (object URLs) are kept side by side. */
export function revokePreviews(previews: string[]): void {
  for (const url of previews) {
    if (url) URL.revokeObjectURL(url);
  }
}
