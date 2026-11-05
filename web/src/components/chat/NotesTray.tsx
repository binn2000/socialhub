"use client";

import React, { useState, useEffect, useCallback } from "react";
import { Plus, Music2 } from "lucide-react";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { useAuth } from "@/context/AuthContext";
import { useToast } from "@/context/ToastContext";
import { clientFetch } from "@/lib/client-api";
import { CreateNoteModal } from "./CreateNoteModal";
import { ViewNoteModal } from "./ViewNoteModal";
import type { Note } from "@/types";

interface NotesTrayProps {
  onOpenConversation?: (conversationId: string) => void;
  className?: string;
}

export function NotesTray({ onOpenConversation, className = "" }: NotesTrayProps) {
  const { user: currentUser } = useAuth();
  const { toast } = useToast();

  const [notes, setNotes] = useState<Note[]>([]);
  const [loading, setLoading] = useState(true);

  // Modals state
  const [createModalOpen, setCreateModalOpen] = useState(false);
  const [viewingNote, setViewingNote] = useState<Note | null>(null);

  const loadNotes = useCallback(async () => {
    try {
      const res = await clientFetch<{ data: Note[] }>("/api/proxy/notes");
      setNotes(res.data || []);
    } catch {
      setNotes([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadNotes();
  }, [loadNotes]);

  // Find my note
  const myNote = notes.find((n) => n.user.id === currentUser?.id) || null;
  // Friends' notes
  const friendsNotes = notes.filter((n) => n.user.id !== currentUser?.id);

  const handleNoteSaved = (updatedNote: Note | null) => {
    if (!updatedNote) {
      // Deleted
      setNotes((prev) => prev.filter((n) => n.user.id !== currentUser?.id));
    } else {
      // Created or updated
      setNotes((prev) => {
        const withoutMine = prev.filter((n) => n.user.id !== currentUser?.id);
        return [updatedNote, ...withoutMine];
      });
    }
  };

  const handleDeleteMyNote = async () => {
    try {
      await clientFetch("/api/proxy/me/note", { method: "DELETE" });
      handleNoteSaved(null);
      setViewingNote(null);
      toast.success("Đã gỡ ghi chú");
    } catch {
      toast.error("Không thể xóa ghi chú.");
    }
  };

  return (
    <div className={`px-3 py-3 border-b border-appBorder-light dark:border-appBorder-dark ${className}`}>
      <div className="flex items-start gap-4 overflow-x-auto pb-1 scrollbar-none pt-7">
        {/* Item 1: My Note */}
        <div
          onClick={() => {
            if (myNote) {
              setViewingNote(myNote);
            } else {
              setCreateModalOpen(true);
            }
          }}
          className="relative flex flex-col items-center shrink-0 cursor-pointer group"
        >
          {/* Thought Bubble */}
          <div className="absolute -top-7 left-1/2 -translate-x-1/2 z-10">
            {myNote ? (
              <div className="relative max-w-[85px] px-2 py-1 bg-surface-light dark:bg-surface-dark rounded-xl shadow-md border border-appBorder-light dark:border-appBorder-dark group-hover:scale-105 transition-transform">
                {myNote.text ? (
                  <p className="text-[10px] font-semibold text-appText-primary dark:text-appText-dark-primary truncate text-center">
                    {myNote.text}
                  </p>
                ) : myNote.track ? (
                  <div className="flex items-center justify-center gap-1 text-[10px] text-brand font-semibold">
                    <Music2 size={10} />
                    <span className="truncate">{myNote.track.title}</span>
                  </div>
                ) : null}
                {/* Bubble Tail */}
                <div className="absolute -bottom-1 left-1/2 -translate-x-1/2 w-1.5 h-1.5 bg-surface-light dark:bg-surface-dark rounded-full border-b border-r border-appBorder-light dark:border-appBorder-dark" />
              </div>
            ) : (
              <div className="relative px-2 py-0.5 bg-surface-light dark:bg-surface-dark rounded-full shadow-sm border border-appBorder-light dark:border-appBorder-dark text-[10px] text-appText-secondary group-hover:text-brand font-medium whitespace-nowrap group-hover:scale-105 transition">
                <span>Chia sẻ suy nghĩ...</span>
                <div className="absolute -bottom-1 left-1/2 -translate-x-1/2 w-1.5 h-1.5 bg-surface-light dark:bg-surface-dark rounded-full border-b border-r border-appBorder-light dark:border-appBorder-dark" />
              </div>
            )}
          </div>

          {/* Avatar with optional + badge */}
          <div className="relative">
            <UserAvatar
              name={currentUser?.name}
              src={currentUser?.avatarUrl}
              size="md"
              className={myNote ? "ring-2 ring-brand/40" : ""}
            />
            {!myNote && (
              <div className="absolute -bottom-0.5 -right-0.5 w-4 h-4 rounded-full bg-brand text-white flex items-center justify-center shadow-xs">
                <Plus size={11} />
              </div>
            )}
          </div>

          <span className="text-[11px] font-medium text-appText-secondary dark:text-appText-dark-secondary mt-1.5 truncate max-w-[70px] text-center">
            Ghi chú của bạn
          </span>
        </div>

        {/* Items 2..N: Friends' Notes */}
        {friendsNotes.map((note) => (
          <div
            key={note.user.id}
            onClick={() => setViewingNote(note)}
            className="relative flex flex-col items-center shrink-0 cursor-pointer group"
          >
            {/* Thought Bubble */}
            <div className="absolute -top-7 left-1/2 -translate-x-1/2 z-10">
              <div className="relative max-w-[85px] px-2 py-1 bg-surface-light dark:bg-surface-dark rounded-xl shadow-md border border-appBorder-light dark:border-appBorder-dark group-hover:scale-105 transition-transform">
                {note.text ? (
                  <p className="text-[10px] font-semibold text-appText-primary dark:text-appText-dark-primary truncate text-center">
                    {note.text}
                  </p>
                ) : note.track ? (
                  <div className="flex items-center justify-center gap-1 text-[10px] text-brand font-semibold">
                    <Music2 size={10} />
                    <span className="truncate">{note.track.title}</span>
                  </div>
                ) : null}
                {/* Bubble Tail */}
                <div className="absolute -bottom-1 left-1/2 -translate-x-1/2 w-1.5 h-1.5 bg-surface-light dark:bg-surface-dark rounded-full border-b border-r border-appBorder-light dark:border-appBorder-dark" />
              </div>
            </div>

            {/* Avatar */}
            <div className="relative">
              <UserAvatar
                name={note.user.name}
                src={note.user.avatarUrl}
                size="md"
                className="ring-2 ring-brand/30"
              />
            </div>

            <span className="text-[11px] font-medium text-appText-primary dark:text-appText-dark-primary mt-1.5 truncate max-w-[70px] text-center">
              {note.user.name.split(" ").slice(-1)[0]}
            </span>
          </div>
        ))}
      </div>

      {/* Modal: Create or Edit My Note */}
      {createModalOpen && (
        <CreateNoteModal
          isOpen={createModalOpen}
          onClose={() => setCreateModalOpen(false)}
          onNoteSaved={handleNoteSaved}
          initialNote={myNote}
        />
      )}

      {/* Modal: View Note Details & Reply */}
      {viewingNote && (
        <ViewNoteModal
          note={viewingNote}
          isOpen={Boolean(viewingNote)}
          onClose={() => setViewingNote(null)}
          onEditNote={() => setCreateModalOpen(true)}
          onDeleteNote={handleDeleteMyNote}
          onOpenConversation={onOpenConversation}
        />
      )}
    </div>
  );
}
