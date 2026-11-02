/// The terms and the privacy policy shown inside the app. Keep them in step
/// with docs/legal/*.md (the longer drafts with the blanks still to fill).
class LegalDocument {
  final String title;
  final List<(String heading, String body)> sections;

  const LegalDocument(this.title, this.sections);
}

const termsOfService = LegalDocument('Điều khoản sử dụng', [
  (
    'Tài khoản',
    'Bạn cần cung cấp thông tin chính xác, giữ bí mật mật khẩu và chịu '
        'trách nhiệm về mọi hoạt động trong tài khoản. Không mạo danh người '
        'khác.',
  ),
  (
    'Nội dung của bạn',
    'Bạn giữ quyền sở hữu nội dung mình đăng và cho phép SocialHub lưu trữ, '
        'hiển thị nội dung đó cho những người bạn chọn xem. Bạn bảo đảm có '
        'quyền đăng nội dung đó và nó không vi phạm pháp luật hay quyền của '
        'người khác.',
  ),
  (
    'Hành vi bị cấm',
    'Đăng nội dung vi phạm pháp luật, bạo lực, thù ghét, khiêu dâm, lừa đảo '
        'hoặc tiết lộ thông tin riêng tư của người khác; quấy rối, spam; truy '
        'cập trái phép hoặc làm gián đoạn dịch vụ; đăng nội dung vi phạm bản '
        'quyền.',
  ),
  (
    'Nhạc nghe thử',
    'Đoạn nghe thử 30 giây do Apple Music cung cấp, chỉ để nghe thử. Bài hát '
        'thuộc về chủ sở hữu bản quyền; SocialHub không phân phối bản nhạc '
        'đầy đủ.',
  ),
  (
    'Báo cáo và chặn',
    'Bạn có thể báo cáo nội dung hoặc người dùng và chặn người khác. Chúng '
        'tôi có thể gỡ nội dung, giới hạn hoặc khóa tài khoản vi phạm điều '
        'khoản.',
  ),
  (
    'Chấm dứt',
    'Bạn có thể xóa tài khoản bất cứ lúc nào trong Chỉnh sửa hồ sơ. Chúng '
        'tôi có thể tạm ngừng hoặc chấm dứt tài khoản vi phạm.',
  ),
  (
    'Miễn trừ trách nhiệm',
    'Dịch vụ được cung cấp "nguyên trạng" và có thể gián đoạn hoặc thay '
        'đổi. Trong phạm vi pháp luật cho phép, SocialHub không chịu trách '
        'nhiệm với thiệt hại gián tiếp hoặc nội dung do người dùng đăng.',
  ),
]);

const privacyPolicy = LegalDocument('Chính sách quyền riêng tư', [
  (
    'Chúng tôi thu thập gì',
    'Thông tin tài khoản (tên, tên người dùng, email, mật khẩu đã băm), hồ sơ '
        'bạn tự điền, nội dung bạn tạo (bài viết, ảnh, bình luận, tin, ghi '
        'chú, tin nhắn), quan hệ bạn bè và theo dõi, lượt thích và lưu bài, '
        'thời điểm hoạt động gần nhất và mã thông báo đẩy của thiết bị.',
  ),
  (
    'Dùng để làm gì',
    'Cung cấp dịch vụ, bảo vệ tài khoản và chống lạm dụng. Chúng tôi không '
        'bán dữ liệu cá nhân của bạn.',
  ),
  (
    'Ai nhìn thấy gì',
    'Bài viết, tin và ghi chú hiển thị theo quyền riêng tư bạn chọn: Công '
        'khai, Bạn bè hoặc Chỉ mình tôi. Tin nhắn chỉ hiển thị với người '
        'trong cuộc trò chuyện. Email của bạn không hiển thị với người khác. '
        'Bạn có thể tắt hiển thị trạng thái trực tuyến.',
  ),
  (
    'Bên thứ ba',
    'Google Firebase gửi thông báo đẩy tới thiết bị. Apple cung cấp đoạn '
        'nghe thử khi bạn gắn nhạc (chỉ nhận từ khóa tìm kiếm). Spotify chỉ '
        'dùng để tạo liên kết bài hát.',
  ),
  (
    'Lưu trữ và xóa',
    'Tin và ghi chú tự hết hạn sau 24 giờ. Bạn có thể xóa từng nội dung. Khi '
        'xóa tài khoản (Chỉnh sửa hồ sơ → Xóa tài khoản), nội dung ngừng '
        'hiển thị ngay và dữ liệu bị xóa vĩnh viễn sau 30 ngày.',
  ),
  (
    'Quyền của bạn',
    'Bạn có quyền truy cập, chỉnh sửa và xóa dữ liệu của mình; phần lớn làm '
        'được ngay trong app.',
  ),
  (
    'Bảo mật',
    'Mật khẩu được băm và mã đăng nhập lưu trong bộ nhớ an toàn của thiết '
        'bị. Hãy dùng mật khẩu riêng và báo cho chúng tôi nếu nghi ngờ bị '
        'xâm nhập.',
  ),
]);
