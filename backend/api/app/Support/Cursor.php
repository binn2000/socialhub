<?php

namespace App\Support;

/**
 * Opaque keyset cursor. It carries a scope (endpoint + filters) so a cursor issued for
 * one list is rejected on another, as the contract requires.
 */
class Cursor
{
    public static function encode(string $scope, string $createdAt, string $id): string
    {
        $json = json_encode(['s' => md5($scope), 'c' => $createdAt, 'i' => $id]);

        return rtrim(strtr(base64_encode($json), '+/', '-_'), '=');
    }

    /** @return array{0: string, 1: string}|null [createdAt, id], or null when invalid for $scope */
    public static function decode(string $cursor, string $scope): ?array
    {
        $data = json_decode((string) base64_decode(strtr($cursor, '-_', '+/'), true), true);

        if (! is_array($data) || ($data['s'] ?? null) !== md5($scope)
            || ! is_string($data['c'] ?? null) || ! is_string($data['i'] ?? null)) {
            return null;
        }

        return [$data['c'], $data['i']];
    }

    public static function invalid(): never
    {
        abort(response()->json([
            'message' => __('The cursor is not valid for this request.'),
            'code' => 'invalid_cursor',
        ], 400));
    }
}
