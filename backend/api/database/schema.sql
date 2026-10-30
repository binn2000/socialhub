-- SocialHub database schema for MariaDB 10.1.38 (XAMPP).
-- Source of truth: docs/api/openapi.yaml, section `x-database`. Change the contract first.
--
-- Required server settings (my.cnf, [mysqld]) BEFORE running this file, otherwise the
-- unique indexes on long utf8mb4 columns fail with "Specified key was too long":
--   innodb_file_format    = Barracuda
--   innodb_large_prefix   = 1
--   innodb_file_per_table = 1
--
-- CHECK constraints are parsed but NOT enforced by MariaDB 10.1: they are written as
-- comments below and must also be enforced in Laravel validation.
--
-- Run:  mysql -u root < backend/database/schema.sql

CREATE DATABASE IF NOT EXISTS `socialhub`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `socialhub`;

SET NAMES utf8mb4;
-- MariaDB 10.1 gives a NOT NULL timestamp column without an explicit default an implicit
-- ON UPDATE CURRENT_TIMESTAMP (and explicit_defaults_for_timestamp is read-only here),
-- so every NOT NULL timestamp below spells out its default.

-- ---------------------------------------------------------------------------
-- users
-- ---------------------------------------------------------------------------
CREATE TABLE `users` (
  `id`                char(26)     NOT NULL,
  `name`              varchar(50)  NOT NULL,
  `username`          varchar(30)  NOT NULL COMMENT 'stored without @',
  `email`             varchar(255) NOT NULL,
  `email_verified_at` timestamp    NULL DEFAULT NULL,
  `password`          varchar(255) NOT NULL COMMENT 'hashed by Laravel; never returned',
  `avatar_path`       varchar(255) NULL DEFAULT NULL,
  `bio`               varchar(300) NULL DEFAULT NULL,
  `created_at`        timestamp    NULL DEFAULT NULL,
  `updated_at`        timestamp    NULL DEFAULT NULL,
  `deleted_at`        timestamp    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `users_username_unique` (`username`),
  UNIQUE KEY `users_email_unique` (`email`),
  KEY `users_name_id_index` (`name`, `id`)
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- personal_access_tokens (Sanctum, ULID owners: ulidMorphs('tokenable'))
-- ---------------------------------------------------------------------------
CREATE TABLE `personal_access_tokens` (
  `id`             bigint unsigned NOT NULL AUTO_INCREMENT,
  `tokenable_type` varchar(255)    NOT NULL,
  `tokenable_id`   char(26)        NOT NULL,
  `name`           varchar(255)    NOT NULL COMMENT 'device name',
  `token`          char(64)        NOT NULL COMMENT 'SHA-256 hash',
  `abilities`      text            NULL,
  `last_used_at`   timestamp       NULL DEFAULT NULL,
  `expires_at`     timestamp       NULL DEFAULT NULL,
  `created_at`     timestamp       NULL DEFAULT NULL,
  `updated_at`     timestamp       NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `personal_access_tokens_token_unique` (`token`),
  KEY `personal_access_tokens_tokenable_index` (`tokenable_type`, `tokenable_id`),
  KEY `personal_access_tokens_expires_at_index` (`expires_at`)
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- friendships (one row per pair of users, whichever way the request went)
-- CHECK (requester_id <> addressee_id) -- not enforced, validate in the service
-- ---------------------------------------------------------------------------
CREATE TABLE `friendships` (
  `id`           char(26)    NOT NULL COMMENT 'friendRequestId while pending',
  `requester_id` char(26)    NOT NULL,
  `addressee_id` char(26)    NOT NULL,
  -- The smaller and the larger of the two user ids, set by the app (Friendship::creating).
  -- Plain columns on purpose: MariaDB 10.2+ rejects LEAST()/GREATEST()/IF() on strings in a
  -- stored generated column (error 1901), while 10.1 accepted it.
  `user_low_id`  char(26)    NOT NULL,
  `user_high_id` char(26)    NOT NULL,
  `status`       varchar(10) NOT NULL COMMENT 'pending | accepted',
  `accepted_at`  timestamp   NULL DEFAULT NULL,
  `created_at`   timestamp   NULL DEFAULT NULL,
  `updated_at`   timestamp   NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `friendships_pair_unique` (`user_low_id`, `user_high_id`),
  KEY `friendships_incoming_index` (`addressee_id`, `status`, `created_at`),
  KEY `friendships_outgoing_index` (`requester_id`, `status`, `created_at`),
  KEY `friendships_low_status_index` (`user_low_id`, `status`),
  KEY `friendships_high_status_index` (`user_high_id`, `status`),
  CONSTRAINT `friendships_requester_fk` FOREIGN KEY (`requester_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `friendships_addressee_fk` FOREIGN KEY (`addressee_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- posts
-- CHECK (content IS NOT NULL OR image_path IS NOT NULL) -- not enforced
-- ---------------------------------------------------------------------------
CREATE TABLE `posts` (
  `id`             char(26)     NOT NULL,
  `user_id`        char(26)     NOT NULL,
  `content`        text         NULL,
  `image_path`     varchar(255) NULL DEFAULT NULL,
  `feeling`        varchar(20)  NULL DEFAULT NULL COMMENT 'cheerful | excited | happy',
  `privacy`        varchar(10)  NOT NULL DEFAULT 'public' COMMENT 'public | friends | only_me',
  `likes_count`    int unsigned NOT NULL DEFAULT 0,
  `comments_count` int unsigned NOT NULL DEFAULT 0,
  `shares_count`   int unsigned NOT NULL DEFAULT 0,
  `created_at`     timestamp    NULL DEFAULT NULL,
  `updated_at`     timestamp    NULL DEFAULT NULL,
  `deleted_at`     timestamp    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `posts_user_created_index` (`user_id`, `created_at`, `id`),
  KEY `posts_privacy_created_index` (`privacy`, `created_at`, `id`),
  CONSTRAINT `posts_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- post_likes / post_saves / post_hidden / post_shares
-- The composite primary key is the "one per user and post" rule.
-- ---------------------------------------------------------------------------
CREATE TABLE `post_likes` (
  `post_id`    char(26)  NOT NULL,
  `user_id`    char(26)  NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`post_id`, `user_id`),
  CONSTRAINT `post_likes_post_fk` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `post_likes_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `post_saves` (
  `post_id`    char(26)  NOT NULL,
  `user_id`    char(26)  NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`post_id`, `user_id`),
  KEY `post_saves_user_created_index` (`user_id`, `created_at`, `post_id`),
  CONSTRAINT `post_saves_post_fk` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `post_saves_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `post_hidden` (
  `post_id`    char(26)  NOT NULL,
  `user_id`    char(26)  NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`post_id`, `user_id`),
  CONSTRAINT `post_hidden_post_fk` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `post_hidden_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `post_shares` (
  `post_id`    char(26)    NOT NULL,
  `user_id`    char(26)    NOT NULL,
  `target`     varchar(10) NOT NULL COMMENT 'link | message',
  `created_at` timestamp   NULL DEFAULT NULL,
  PRIMARY KEY (`post_id`, `user_id`),
  CONSTRAINT `post_shares_post_fk` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `post_shares_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- comments
-- ---------------------------------------------------------------------------
CREATE TABLE `comments` (
  `id`         char(26)      NOT NULL,
  `post_id`    char(26)      NOT NULL,
  `user_id`    char(26)      NOT NULL,
  `content`    varchar(1000) NOT NULL,
  `created_at` timestamp     NULL DEFAULT NULL,
  `updated_at` timestamp     NULL DEFAULT NULL,
  `deleted_at` timestamp     NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `comments_post_created_index` (`post_id`, `created_at`, `id`),
  KEY `comments_user_fk_index` (`user_id`),
  CONSTRAINT `comments_post_fk` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `comments_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- stories / story_views
-- CHECK (text IS NOT NULL OR image_path IS NOT NULL) -- not enforced
-- ---------------------------------------------------------------------------
CREATE TABLE `stories` (
  `id`         char(26)     NOT NULL,
  `user_id`    char(26)     NOT NULL,
  `text`       varchar(500) NULL DEFAULT NULL,
  `image_path` varchar(255) NULL DEFAULT NULL,
  `background` varchar(10)  NOT NULL DEFAULT 'indigo' COMMENT 'indigo | sunset | mint | berry',
  `expires_at` timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'created_at + 24 hours',
  `created_at` timestamp    NULL DEFAULT NULL,
  `updated_at` timestamp    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `stories_user_created_index` (`user_id`, `created_at`, `id`),
  KEY `stories_expires_at_index` (`expires_at`),
  CONSTRAINT `stories_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `story_views` (
  `story_id`  char(26)  NOT NULL,
  `user_id`   char(26)  NOT NULL,
  `viewed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`story_id`, `user_id`),
  KEY `story_views_user_story_index` (`user_id`, `story_id`),
  CONSTRAINT `story_views_story_fk` FOREIGN KEY (`story_id`) REFERENCES `stories` (`id`) ON DELETE CASCADE,
  CONSTRAINT `story_views_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- conversations / conversation_participants / messages
-- conversations.last_message_id and participants.last_read_message_id reference
-- messages, which references conversations, so those two FKs are added at the end.
-- ---------------------------------------------------------------------------
CREATE TABLE `conversations` (
  `id`              char(26)     NOT NULL,
  `type`            varchar(10)  NOT NULL DEFAULT 'direct' COMMENT 'only direct in v1',
  `direct_key`      char(53)     NULL DEFAULT NULL COMMENT '{lowerUserId}:{higherUserId}',
  `last_message_id` char(26)     NULL DEFAULT NULL,
  `last_message_at` timestamp(3) NULL DEFAULT NULL,
  `created_at`      timestamp    NULL DEFAULT NULL,
  `updated_at`      timestamp    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `conversations_direct_key_unique` (`direct_key`),
  KEY `conversations_last_message_index` (`last_message_at`, `id`)
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `messages` (
  `id`              char(26)      NOT NULL,
  `conversation_id` char(26)      NOT NULL,
  `sender_id`       char(26)      NOT NULL,
  `text`            varchar(2000) NOT NULL,
  `created_at`      timestamp(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `messages_conversation_created_index` (`conversation_id`, `created_at`, `id`),
  KEY `messages_sender_index` (`sender_id`),
  CONSTRAINT `messages_conversation_fk` FOREIGN KEY (`conversation_id`) REFERENCES `conversations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `messages_sender_fk` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `conversation_participants` (
  `conversation_id`      char(26)  NOT NULL,
  `user_id`              char(26)  NOT NULL,
  `last_read_message_id` char(26)  NULL DEFAULT NULL COMMENT 'read marker; NULL = nothing read',
  `created_at`           timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`conversation_id`, `user_id`),
  KEY `conversation_participants_user_index` (`user_id`, `conversation_id`),
  KEY `conversation_participants_read_index` (`last_read_message_id`),
  CONSTRAINT `conversation_participants_conversation_fk` FOREIGN KEY (`conversation_id`) REFERENCES `conversations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `conversation_participants_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `conversation_participants_read_fk` FOREIGN KEY (`last_read_message_id`) REFERENCES `messages` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `conversations`
  ADD KEY `conversations_last_message_id_index` (`last_message_id`),
  ADD CONSTRAINT `conversations_last_message_fk`
    FOREIGN KEY (`last_message_id`) REFERENCES `messages` (`id`) ON DELETE SET NULL;

-- ---------------------------------------------------------------------------
-- notifications (custom table so foreign keys can exist)
-- CHECK (user_id <> actor_id) -- not enforced, the creating job must skip it
-- ---------------------------------------------------------------------------
CREATE TABLE `notifications` (
  `id`            char(26)     NOT NULL,
  `user_id`       char(26)     NOT NULL COMMENT 'recipient',
  `actor_id`      char(26)     NOT NULL,
  `type`          varchar(20)  NOT NULL COMMENT 'like | comment | share | friend_request | friend_accepted',
  `post_id`       char(26)     NULL DEFAULT NULL,
  `comment_id`    char(26)     NULL DEFAULT NULL,
  `friendship_id` char(26)     NULL DEFAULT NULL,
  `dedupe_key`    varchar(120) NULL DEFAULT NULL COMMENT 'e.g. like:{actorId}:{postId}; NULL for comments',
  `read_at`       timestamp    NULL DEFAULT NULL,
  `created_at`    timestamp    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `notifications_dedupe_key_unique` (`dedupe_key`),
  KEY `notifications_user_created_index` (`user_id`, `created_at`, `id`),
  KEY `notifications_user_read_index` (`user_id`, `read_at`),
  KEY `notifications_actor_fk_index` (`actor_id`),
  KEY `notifications_post_fk_index` (`post_id`),
  KEY `notifications_comment_fk_index` (`comment_id`),
  KEY `notifications_friendship_fk_index` (`friendship_id`),
  CONSTRAINT `notifications_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `notifications_actor_fk` FOREIGN KEY (`actor_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `notifications_post_fk` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `notifications_comment_fk` FOREIGN KEY (`comment_id`) REFERENCES `comments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `notifications_friendship_fk` FOREIGN KEY (`friendship_id`) REFERENCES `friendships` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- idempotency_keys (response_body is text: MariaDB 10.1 has no JSON type)
-- ---------------------------------------------------------------------------
CREATE TABLE `idempotency_keys` (
  `id`            bigint unsigned   NOT NULL AUTO_INCREMENT,
  `user_id`       char(26)          NOT NULL,
  `key`           char(36)          NOT NULL,
  `method`        varchar(6)        NOT NULL,
  `path`          varchar(255)      NOT NULL,
  `request_hash`  char(64)          NOT NULL COMMENT 'SHA-256 of the body',
  `status_code`   smallint unsigned NULL DEFAULT NULL COMMENT 'NULL while the first request runs',
  `response_body` text              NULL,
  `created_at`    timestamp         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idempotency_keys_user_key_unique` (`user_id`, `key`),
  KEY `idempotency_keys_created_at_index` (`created_at`),
  CONSTRAINT `idempotency_keys_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Laravel infrastructure tables (jobs, job_batches, failed_jobs, migrations) are created
-- by Laravel's own migrations once the Laravel project exists; they are not duplicated here.
