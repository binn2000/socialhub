import type { components, paths } from "./api";

export type { components, paths };

// Schemas
export type Schemas = components["schemas"];

export type Id = Schemas["Id"];
export type Timestamp = Schemas["Timestamp"];
export type ApiError = Schemas["Error"];
export type ValidationError = Schemas["ValidationError"];
export type CursorMeta = Schemas["CursorMeta"];

export type Privacy = Schemas["Privacy"];
export type Feeling = Schemas["Feeling"];
export type StoryBackground = Schemas["StoryBackground"];
export type NotificationType = Schemas["NotificationType"];
export type FriendshipStatus = Schemas["FriendshipStatus"];
export type Friendship = Schemas["Friendship"];

export type UserSummary = Schemas["UserSummary"];
export type UserListItem = Schemas["UserListItem"];
export type UserProfile = Schemas["UserProfile"];
export type Me = Schemas["Me"];
export type About = Schemas["About"];

export type AuthToken = Schemas["AuthToken"];
export type AuthResult = Schemas["AuthResult"];
export type LoginRequest = Schemas["LoginRequest"];
export type RegisterRequest = Schemas["RegisterRequest"];
export type UpdateMeRequest = Schemas["UpdateMeRequest"];
export type DeleteAccountRequest = Schemas["DeleteAccountRequest"];

export type Post = Schemas["Post"];
export type PostVideo = Schemas["PostVideo"];
export type Comment = Schemas["Comment"];
export type Story = Schemas["Story"];

export type Conversation = Schemas["Conversation"];
export type Message = Schemas["Message"];
export type ChatMessage = Message;
export type Attachment = Schemas["Attachment"];
export type ChatAttachment = Attachment;
export type Note = Schemas["Note"];
export type Track = Schemas["Track"];
export type Notification = Schemas["Notification"];
export type FriendRequest = Schemas["FriendRequest"];
export type BlockedUser = Schemas["UserSummary"];
export type ReportReason = Schemas["CreateReportRequest"]["reason"];
export type Photo = Schemas["Photo"];
export type PhotoPage = Schemas["PhotoPage"];
export type UserPage = Schemas["UserPage"];
