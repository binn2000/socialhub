<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Jobs\SendPush;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\MessageAttachment;
use App\Support\ImageStore;
use App\Support\Presence;
use Illuminate\Support\Facades\Cache;
use App\Models\User;
use App\Support\Cursor;
use App\Support\PostPresenter;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class ConversationController extends Controller
{
    private const MS = 'Y-m-d H:i:s.v';

    private const TYPING_SECONDS = 6;

    public function index(Request $request): array
    {
        $request->validate([
            'q' => ['nullable', 'string', 'max:100'],
            'cursor' => ['nullable', 'string'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $me = $request->user();
        $limit = (int) $request->query('limit', 20);
        $q = trim((string) $request->query('q', ''));
        $scope = 'conversations|'.mb_strtolower($q);

        // A conversation without a message is not listed.
        $query = Conversation::whereNotNull('last_message_id')->whereExists(fn ($e) => $e->selectRaw('1')
            ->from('conversation_participants')
            ->whereColumn('conversation_participants.conversation_id', 'conversations.id')
            ->where('conversation_participants.user_id', $me->id))
            // A conversation whose other person deleted their account is not listed.
            ->whereExists(fn ($e) => $e->selectRaw('1')
                ->from('conversation_participants as other')
                ->join('users', 'users.id', '=', 'other.user_id')
                ->whereColumn('other.conversation_id', 'conversations.id')
                ->where('other.user_id', '!=', $me->id)
                ->whereNull('users.deleted_at')
                ->when($q !== '', function ($other) use ($q) {
                    $like = '%'.addcslashes($q, '\\%_').'%';
                    $other->where(fn ($w) => $w->where('users.name', 'like', $like)->orWhere('users.username', 'like', $like));
                })
                ->whereNotExists(fn ($b) => $b->selectRaw('1')->from('user_blocks')
                    ->where(fn ($w) => $w->where(fn ($x) => $x->where('blocker_id', $me->id)->whereColumn('blocked_id', 'other.user_id'))
                        ->orWhere(fn ($x) => $x->where('blocked_id', $me->id)->whereColumn('blocker_id', 'other.user_id')))));

        if ($request->filled('cursor')) {
            [$at, $id] = Cursor::decode($request->query('cursor'), $scope) ?? Cursor::invalid();
            $query->where(fn ($w) => $w->where('last_message_at', '<', $at)
                ->orWhere(fn ($t) => $t->where('last_message_at', $at)->where('id', '<', $id)));
        }

        $rows = $query->orderByDesc('last_message_at')->orderByDesc('id')->limit($limit + 1)->get();
        $hasMore = $rows->count() > $limit;
        $page = $rows->take($limit)->values();
        $last = $page->last();

        return [
            'data' => $this->presentMany($page, $me),
            'meta' => [
                'nextCursor' => $hasMore ? Cursor::encode($scope, $last->last_message_at, $last->id) : null,
                'hasMore' => $hasMore,
            ],
        ];
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate(['userId' => ['required', 'string']]);
        $me = $request->user();

        if ($data['userId'] === $me->id) {
            throw ValidationException::withMessages(['userId' => [__('You cannot start a conversation with yourself.')]]);
        }
        $target = User::find($data['userId']) ?? abort(404);

        if (! self::areFriends($me->id, $target->id)) {
            abort(response()->json(['message' => __('You can only message your friends.'), 'code' => 'not_friends'], 403));
        }

        $key = min($me->id, $target->id).':'.max($me->id, $target->id);
        $created = false;

        try {
            $conversation = DB::transaction(function () use ($me, $target, $key, &$created) {
                $c = Conversation::create(['type' => 'direct', 'direct_key' => $key]);
                DB::table('conversation_participants')->insert([
                    ['conversation_id' => $c->id, 'user_id' => $me->id, 'created_at' => now()],
                    ['conversation_id' => $c->id, 'user_id' => $target->id, 'created_at' => now()],
                ]);
                $created = true;

                return $c;
            });
        } catch (UniqueConstraintViolationException) {
            // The unique direct_key decides when both sides open the chat at once.
            $conversation = Conversation::where('direct_key', $key)->firstOrFail();
        }

        return response()->json(
            ['data' => $this->presentMany(collect([$conversation->refresh()]), $me)[0]],
            $created ? 201 : 200,
        );
    }

    public function messages(Request $request, string $conversation): array
    {
        $c = self::forParticipant($request, $conversation);
        $request->validate([
            'cursor' => ['nullable', 'string'],
            'after' => ['nullable', 'string'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);
        if ($request->filled('cursor') && $request->filled('after')) {
            throw ValidationException::withMessages(['after' => [__('Use either cursor or after, not both.')]]);
        }

        $limit = (int) $request->query('limit', 30);
        $query = Message::where('conversation_id', $c->id);

        if ($request->filled('after')) {
            $anchor = Message::where('conversation_id', $c->id)->where('id', $request->query('after'))->first() ?? abort(404);
            $at = $anchor->created_at->format(self::MS);
            $rows = $query->where(fn ($w) => $w->where('created_at', '>', $at)
                ->orWhere(fn ($t) => $t->where('created_at', $at)->where('id', '>', $anchor->id)))
                ->orderBy('created_at')->orderBy('id')->limit($limit + 1)->get();

            return [
                'data' => $this->presentMessages($rows->take($limit)),
                'meta' => ['nextCursor' => null, 'hasMore' => $rows->count() > $limit, 'otherTyping' => $this->otherTyping($c, $request->user())],
            ];
        }

        $scope = 'messages|'.$c->id;
        if ($request->filled('cursor')) {
            [$at, $id] = Cursor::decode($request->query('cursor'), $scope) ?? Cursor::invalid();
            $query->where(fn ($w) => $w->where('created_at', '<', $at)
                ->orWhere(fn ($t) => $t->where('created_at', $at)->where('id', '<', $id)));
        }

        $rows = $query->orderByDesc('created_at')->orderByDesc('id')->limit($limit + 1)->get();
        $hasMore = $rows->count() > $limit;
        $page = $rows->take($limit);
        $last = $page->last();

        return [
            'data' => $this->presentMessages($page),
            'meta' => [
                'nextCursor' => $hasMore ? Cursor::encode($scope, $last->created_at->format(self::MS), $last->id) : null,
                'hasMore' => $hasMore,
                'otherTyping' => $this->otherTyping($c, $request->user()),
            ],
        ];
    }

    private const IMAGE_EXTENSIONS = ['jpg', 'jpeg', 'png', 'webp'];

    public function send(Request $request, string $conversation): JsonResponse
    {
        $c = self::forParticipant($request, $conversation);
        $data = $request->validate([
            'text' => ['nullable', 'string', 'max:2000'],
            'attachments' => ['nullable', 'array', 'max:5'],
            'attachments.*' => ['file', 'max:'.ImageStore::MAX_KB, 'mimes:jpg,jpeg,png,webp,pdf,doc,docx,xls,xlsx,ppt,pptx,txt,csv,zip'],
        ]);
        $me = $request->user();
        $text = trim((string) ($data['text'] ?? ''));
        $files = $request->hasFile('attachments') ? array_values($request->file('attachments')) : [];

        if ($text === '' && $files === []) {
            throw ValidationException::withMessages(['text' => [__('A message needs text or an attachment.')]]);
        }

        $otherId = DB::table('conversation_participants')->where('conversation_id', $c->id)
            ->where('user_id', '!=', $me->id)->value('user_id');
        if (! $otherId || ! self::areFriends($me->id, $otherId)) {
            abort(response()->json(['message' => __('You are no longer friends.'), 'code' => 'not_friends'], 403));
        }

        $stored = [];
        try {
            foreach ($files as $index => $file) {
                $stored[] = $this->storeAttachment($file, "attachments.$index");
            }

            $message = DB::transaction(function () use ($c, $me, $text, $stored) {
                $message = Message::create([
                    'conversation_id' => $c->id, 'sender_id' => $me->id,
                    'text' => $text, 'created_at' => now(),
                ]);
                foreach ($stored as $attachment) {
                    MessageAttachment::create($attachment + ['message_id' => $message->id, 'created_at' => now()]);
                }
                $at = $message->created_at->format(self::MS);

                DB::table('conversations')->where('id', $c->id)
                    ->update(['last_message_id' => $message->id, 'last_message_at' => $at, 'updated_at' => now()]);
                // The sender has read their own message; ids only grow, so this never moves backwards.
                DB::table('conversation_participants')->where(['conversation_id' => $c->id, 'user_id' => $me->id])
                    ->update(['last_read_message_id' => $message->id]);

                return $message;
            });
        } catch (\Throwable $e) {
            array_map(fn (array $a) => ImageStore::delete($a['path']), $stored);
            throw $e;
        }

        Cache::forget("typing:{$c->id}:{$me->id}");

        $preview = $text !== '' ? Str::limit($text, 100)
            : (collect($stored)->every(fn (array $a) => $a['type'] === 'image') ? 'Đã gửi ảnh' : 'Đã gửi tệp đính kèm');
        SendPush::dispatch($otherId, $me->name, $preview, [
            'type' => 'message',
            'conversationId' => $c->id,
            'actorId' => $me->id,
        ])->afterCommit();

        return response()->json(['data' => $this->presentMessage($message)], 201);
    }

    /** Stores one uploaded file and returns the attachment row to save. */
    private function storeAttachment(UploadedFile $file, string $field): array
    {
        $name = trim((string) preg_replace('/[\x00-\x1f\/\\\\]/u', '', $file->getClientOriginalName()));
        $name = $name === '' ? 'file' : Str::limit($name, 255, '');

        if (in_array(strtolower($file->getClientOriginalExtension()), self::IMAGE_EXTENSIONS, true)) {
            $path = ImageStore::store($file, 'chat', $field);
            [$width, $height] = ImageStore::dimensions($path) ?? [null, null];

            return [
                'type' => 'image', 'path' => $path, 'name' => $name,
                'mime_type' => image_type_to_mime_type(@getimagesizefromstring(ImageStore::read($path))[2] ?? IMAGETYPE_JPEG),
                'size_bytes' => ImageStore::size($path), 'width' => $width, 'height' => $height,
            ];
        }

        $path = ImageStore::storeFile($file, 'chat');

        return [
            'type' => 'file', 'path' => $path, 'name' => $name,
            'mime_type' => Str::limit((string) $file->getMimeType(), 100, ''),
            'size_bytes' => ImageStore::size($path), 'width' => null, 'height' => null,
        ];
    }

    public function typing(Request $request, string $conversation): JsonResponse
    {
        $c = self::forParticipant($request, $conversation);
        $me = $request->user();
        $otherId = DB::table('conversation_participants')->where('conversation_id', $c->id)
            ->where('user_id', '!=', $me->id)->value('user_id');
        if (! $otherId || ! self::areFriends($me->id, $otherId)) {
            abort(response()->json(['message' => __('You are no longer friends.'), 'code' => 'not_friends'], 403));
        }

        Cache::put("typing:{$c->id}:{$me->id}", true, now()->addSeconds(self::TYPING_SECONDS));

        return response()->json(null, 204);
    }

    public function stopTyping(Request $request, string $conversation): JsonResponse
    {
        $c = self::forParticipant($request, $conversation);
        Cache::forget("typing:{$c->id}:{$request->user()->id}");

        return response()->json(null, 204);
    }

    private function otherTyping(Conversation $c, User $me): bool
    {
        $otherId = DB::table('conversation_participants')->where('conversation_id', $c->id)
            ->where('user_id', '!=', $me->id)->value('user_id');

        return $otherId !== null && Cache::has("typing:{$c->id}:{$otherId}");
    }

    public function read(Request $request, string $conversation): JsonResponse
    {
        $c = self::forParticipant($request, $conversation);
        $data = $request->validate(['upToMessageId' => ['nullable', 'string']]);

        $upTo = $data['upToMessageId'] ?? null;
        if ($upTo !== null) {
            if (! Message::where('conversation_id', $c->id)->where('id', $upTo)->exists()) {
                throw ValidationException::withMessages(['upToMessageId' => [__('The message is not in this conversation.')]]);
            }
        } else {
            $upTo = Message::where('conversation_id', $c->id)->max('id');
        }

        if ($upTo !== null) {
            DB::table('conversation_participants')
                ->where(['conversation_id' => $c->id, 'user_id' => $request->user()->id])
                ->where(fn ($q) => $q->whereNull('last_read_message_id')->orWhere('last_read_message_id', '<', $upTo))
                ->update(['last_read_message_id' => $upTo]);
        }

        return response()->json(null, 204);
    }

    /** Participants only; everyone else gets 404 so the conversation's existence is not leaked. */
    private static function forParticipant(Request $request, string $id): Conversation
    {
        return Conversation::where('id', $id)->whereExists(fn ($e) => $e->selectRaw('1')
            ->from('conversation_participants')
            ->whereColumn('conversation_participants.conversation_id', 'conversations.id')
            ->where('conversation_participants.user_id', $request->user()->id))
            ->first() ?? abort(404);
    }

    private static function areFriends(string $a, string $b): bool
    {
        return DB::table('friendships')->where('status', 'accepted')
            ->where('user_low_id', min($a, $b))->where('user_high_id', max($a, $b))->exists();
    }

    private function presentMessage(Message $m): array
    {
        return $this->presentMessages(collect([$m]))[0];
    }

    /** @param \Illuminate\Support\Collection<int, Message> $messages */
    private function presentMessages($messages): array
    {
        $messages = collect($messages)->values();
        $attachments = MessageAttachment::whereIn('message_id', $messages->pluck('id'))->orderBy('id')->get()->groupBy('message_id');

        return $messages->map(fn (Message $m) => [
            'id' => $m->id,
            'conversationId' => $m->conversation_id,
            'senderId' => $m->sender_id,
            'text' => $m->text,
            'attachments' => ($attachments[$m->id] ?? collect())->map(fn (MessageAttachment $a) => [
                'id' => $a->id,
                'type' => $a->type,
                'url' => ImageStore::url($a->path),
                'name' => $a->name,
                'mimeType' => $a->mime_type,
                'sizeBytes' => $a->size_bytes,
                'width' => $a->width,
                'height' => $a->height,
            ])->values()->all(),
            'createdAt' => PostPresenter::timestamp($m->created_at),
        ])->all();
    }

    /** @param \Illuminate\Support\Collection<int, Conversation> $conversations */
    private function presentMany($conversations, User $me): array
    {
        $ids = $conversations->pluck('id');

        $others = User::query()
            ->join('conversation_participants as cp', 'cp.user_id', '=', 'users.id')
            ->whereIn('cp.conversation_id', $ids)->where('cp.user_id', '!=', $me->id)
            ->get(['users.*', 'cp.conversation_id as conversation_id'])->keyBy('conversation_id');

        $lastMessages = collect($this->presentMessages(Message::whereIn('id', $conversations->pluck('last_message_id')->filter())->get()))->keyBy('id');
        $presence = Presence::forUsers($me, $others->values());

        $unread = DB::table('messages as m')
            ->join('conversation_participants as cp', fn ($j) => $j->on('cp.conversation_id', '=', 'm.conversation_id')->where('cp.user_id', $me->id))
            ->whereIn('m.conversation_id', $ids)->where('m.sender_id', '!=', $me->id)
            ->where(fn ($q) => $q->whereNull('cp.last_read_message_id')->orWhereColumn('m.id', '>', 'cp.last_read_message_id'))
            ->groupBy('m.conversation_id')->selectRaw('m.conversation_id, count(*) as n')->pluck('n', 'conversation_id');

        return $conversations->map(function (Conversation $c) use ($others, $lastMessages, $unread, $presence) {
            $last = $c->last_message_id ? $lastMessages->get($c->last_message_id) : null;

            return [
                'id' => $c->id,
                'participant' => PostPresenter::userSummary($others[$c->id]) + $presence[$others[$c->id]->id],
                'lastMessage' => $last,
                'unreadCount' => (int) ($unread[$c->id] ?? 0),
                'updatedAt' => PostPresenter::timestamp(\Illuminate\Support\Carbon::parse($c->last_message_at ?? $c->created_at, 'UTC')),
            ];
        })->values()->all();
    }
}
