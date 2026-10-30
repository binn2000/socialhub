import 'package:flutter/material.dart';
import 'package:flutter_learning/models/message.dart';
import 'package:flutter_learning/models/notification.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/models/story.dart';
import 'package:flutter_learning/models/user.dart';

const UserModel currentUser = UserModel(
  id: 'user_1',
  name: 'Lê Anh Hùng',
  username: '@lanh',
  avatarUrl: 'assets/placeholder.png',
  coverUrl: 'assets/placeholder.png',
  bio: 'Product Designer • Học hỏi mỗi ngày',
  mutualFriends: 245,
  isFriend: true,
  accentColor: Color(0xFF5D6BFF),
);

final List<UserModel> mockUsers = [
  currentUser,
  const UserModel(
    id: 'user_2',
    name: 'Minh Ánh',
    username: '@minh_anh',
    avatarUrl: 'assets/placeholder.png',
    coverUrl: 'assets/placeholder.png',
    bio: 'UI/UX lover',
    mutualFriends: 128,
    isFriend: true,
    accentColor: Color(0xFF00B894),
  ),
  const UserModel(
    id: 'user_3',
    name: 'Duy Khang',
    username: '@duy_khang',
    avatarUrl: 'assets/placeholder.png',
    coverUrl: 'assets/placeholder.png',
    bio: 'Flutter Developer',
    mutualFriends: 86,
    isFriend: true,
    accentColor: Color(0xFF6C5CE7),
  ),
  const UserModel(
    id: 'user_4',
    name: 'Bảo Trâm',
    username: '@baotram',
    avatarUrl: 'assets/placeholder.png',
    coverUrl: 'assets/placeholder.png',
    bio: 'Travel every day',
    mutualFriends: 64,
    isFriend: false,
    accentColor: Color(0xFFFF7675),
  ),
  const UserModel(
    id: 'user_5',
    name: 'Quang Huy',
    username: '@quanghuy',
    avatarUrl: 'assets/placeholder.png',
    coverUrl: 'assets/placeholder.png',
    bio: 'Coffee and code',
    mutualFriends: 94,
    isFriend: true,
    accentColor: Color(0xFF2ECC71),
  ),
  const UserModel(
    id: 'user_6',
    name: 'Hà My',
    username: '@ha_my',
    avatarUrl: 'assets/placeholder.png',
    coverUrl: 'assets/placeholder.png',
    bio: 'Biohacking & mindful living',
    mutualFriends: 76,
    isFriend: false,
    accentColor: Color(0xFFF39C12),
  ),
];

final List<Post> mockPosts = [
  Post(
    id: 'post_1',
    author: mockUsers[1],
    content:
        'Ngày đẹp trời, ngồi ở quán cà phê và làm việc cùng những project mới. Sáng nào cũng thấy hứng thú hơn cho đến khi deadline kề cận 😄',
    imageUrl: 'assets/placeholder.png',
    createdAt: '15 phút trước',
    likes: 254,
    comments: 38,
    shares: 12,
    isLiked: true,
  ),
  Post(
    id: 'post_2',
    author: mockUsers[2],
    content:
        'Mình vừa hoàn thành một prototype giao diện mới cho app quản lý công việc. Đã học được rất nhiều từ tối ưu trải nghiệm người dùng.',
    imageUrl: null,
    createdAt: '1 giờ trước',
    likes: 143,
    comments: 19,
    shares: 7,
    isLiked: false,
  ),
  Post(
    id: 'post_3',
    author: mockUsers[4],
    content:
        'Một buổi đi bộ tối và chụp lại cảnh thành phố. Cuộc sống thật tuyệt nếu bạn biết thưởng thức từng khoảnh khắc. #citylight #weekend',
    imageUrl: 'assets/placeholder.png',
    createdAt: '2 giờ trước',
    likes: 892,
    comments: 64,
    shares: 21,
    isLiked: false,
  ),
  Post(
    id: 'post_4',
    author: currentUser,
    content:
        'Mình đã hoàn thành một dự án thiết kế branding mới. Cảm giác rất hài lòng khi mọi thứ kết nối lại với nhau đẹp như kế hoạch.',
    imageUrl: 'assets/placeholder.png',
    createdAt: 'Hôm qua',
    likes: 429,
    comments: 29,
    shares: 15,
    isLiked: true,
  ),
];

final List<Story> mockStories = [
  Story(
    id: 'story_0',
    user: currentUser,
    imageUrl: null,
    isViewed: false,
    gradientColors: const [Color(0xFF6C5CE7), Color(0xFF8E8DFF)],
  ),
  Story(
    id: 'story_1',
    user: mockUsers[1],
    imageUrl: 'assets/placeholder.png',
    isViewed: false,
    gradientColors: const [Color(0xFFFF8A65), Color(0xFFFFB74D)],
  ),
  Story(
    id: 'story_2',
    user: mockUsers[2],
    imageUrl: 'assets/placeholder.png',
    isViewed: true,
    gradientColors: const [Color(0xFF00B894), Color(0xFF26C6DA)],
  ),
  Story(
    id: 'story_3',
    user: mockUsers[4],
    imageUrl: 'assets/placeholder.png',
    isViewed: false,
    gradientColors: const [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
  ),
  Story(
    id: 'story_4',
    user: mockUsers[5],
    imageUrl: 'assets/placeholder.png',
    isViewed: true,
    gradientColors: const [Color(0xFFAB47BC), Color(0xFFEC407A)],
  ),
];

final List<SocialNotification> mockNotifications = [
  SocialNotification(
    id: 'notification_1',
    actor: mockUsers[1],
    description: 'đã thích bài viết của bạn',
    time: '2 phút trước',
    type: 'like',
    icon: Icons.favorite_rounded,
    iconColor: const Color(0xFFE91E63),
    isRead: false,
  ),
  SocialNotification(
    id: 'notification_2',
    actor: mockUsers[2],
    description: 'đã bình luận trong bài viết của bạn',
    time: '35 phút trước',
    type: 'comment',
    icon: Icons.chat_bubble_rounded,
    iconColor: const Color(0xFF5D6BFF),
    isRead: false,
  ),
  SocialNotification(
    id: 'notification_3',
    actor: mockUsers[3],
    description: 'đã gửi lời mời kết bạn',
    time: '1 giờ trước',
    type: 'friend',
    icon: Icons.person_add_alt_rounded,
    iconColor: const Color(0xFF2ECC71),
    isRead: true,
  ),
  SocialNotification(
    id: 'notification_4',
    actor: mockUsers[4],
    description: 'đã chia sẻ bài viết của bạn',
    time: 'Hôm qua',
    type: 'share',
    icon: Icons.share_rounded,
    iconColor: const Color(0xFF6C5CE7),
    isRead: true,
  ),
];

final List<Conversation> mockConversations = [
  Conversation(
    id: 'conv_1',
    user: mockUsers[1],
    lastMessage: 'Mình đã gửi mockup cho bạn xem chưa?',
    time: '10:42',
    unreadCount: 2,
    messages: [
      const ChatMessage(
        id: 'm_1',
        senderId: 'user_1',
        text: 'Chào bạn, dự án của mình đã xong rồi.',
        time: '10:30',
      ),
      const ChatMessage(
        id: 'm_2',
        senderId: 'user_2',
        text: 'Wow, tuyệt vời! Mình đã gửi mockup cho bạn rồi.',
        time: '10:32',
      ),
      const ChatMessage(
        id: 'm_3',
        senderId: 'user_2',
        text: 'Mình đã gửi mockup cho bạn xem chưa?',
        time: '10:42',
      ),
    ],
  ),
  Conversation(
    id: 'conv_2',
    user: mockUsers[2],
    lastMessage: 'Cậu có muốn tham gia buổi review sáng mai không?',
    time: 'Hôm qua',
    unreadCount: 0,
    messages: [
      const ChatMessage(
        id: 'm_4',
        senderId: 'user_3',
        text: 'Cậu có muốn tham gia buổi review sáng mai không?',
        time: 'Hôm qua',
      ),
    ],
  ),
  Conversation(
    id: 'conv_3',
    user: mockUsers[3],
    lastMessage: 'Mình thích style mới của bạn',
    time: 'Thứ 6',
    unreadCount: 1,
    messages: [
      const ChatMessage(
        id: 'm_5',
        senderId: 'user_4',
        text: 'Mình thích style mới của bạn',
        time: 'Thứ 6',
      ),
    ],
  ),
];
