import { describe, it, expect } from "vitest";
import { termsOfService, privacyPolicy } from "@/lib/legal-texts";
import type { UpdateMeRequest, DeleteAccountRequest } from "@/types";

describe("Phase 2: Auth and Account", () => {
  describe("Legal texts", () => {
    it("has complete terms of service matching app copy", () => {
      expect(termsOfService.title).toBe("Điều khoản sử dụng");
      expect(termsOfService.sections.length).toBe(7);
      expect(termsOfService.sections[0].heading).toBe("Tài khoản");
      expect(termsOfService.sections[1].heading).toBe("Nội dung của bạn");
      expect(termsOfService.sections[2].heading).toBe("Hành vi bị cấm");
      expect(termsOfService.sections[3].heading).toBe("Nhạc nghe thử");
      expect(termsOfService.sections[4].heading).toBe("Báo cáo và chặn");
      expect(termsOfService.sections[5].heading).toBe("Chấm dứt");
      expect(termsOfService.sections[6].heading).toBe("Miễn trừ trách nhiệm");
    });

    it("has complete privacy policy matching app copy", () => {
      expect(privacyPolicy.title).toBe("Chính sách quyền riêng tư");
      expect(privacyPolicy.sections.length).toBe(7);
      expect(privacyPolicy.sections[0].heading).toBe("Chúng tôi thu thập gì");
      expect(privacyPolicy.sections[1].heading).toBe("Dùng để làm gì");
      expect(privacyPolicy.sections[2].heading).toBe("Ai nhìn thấy gì");
      expect(privacyPolicy.sections[3].heading).toBe("Bên thứ ba");
      expect(privacyPolicy.sections[4].heading).toBe("Lưu trữ và xóa");
      expect(privacyPolicy.sections[5].heading).toBe("Quyền của bạn");
      expect(privacyPolicy.sections[6].heading).toBe("Bảo mật");
    });
  });

  describe("Form validations", () => {
    it("validates username rules (3-30 chars, alphanumeric and underscore)", () => {
      const usernameRegex = /^[a-zA-Z0-9_]{3,30}$/;

      expect(usernameRegex.test("user_123")).toBe(true);
      expect(usernameRegex.test("an")).toBe(false); // too short
      expect(usernameRegex.test("a".repeat(31))).toBe(false); // too long
      expect(usernameRegex.test("user@name")).toBe(false); // invalid special char
      expect(usernameRegex.test("user space")).toBe(false); // space not allowed
    });

    it("validates 6-digit confirmation code", () => {
      const codeRegex = /^\d{6}$/;

      expect(codeRegex.test("123456")).toBe(true);
      expect(codeRegex.test("000000")).toBe(true);
      expect(codeRegex.test("12345")).toBe(false); // 5 digits
      expect(codeRegex.test("1234567")).toBe(false); // 7 digits
      expect(codeRegex.test("12345a")).toBe(false); // non-digit
    });

    it("validates website URL scheme", () => {
      const isHttpUrl = (url: string) =>
        url.startsWith("http://") || url.startsWith("https://");

      expect(isHttpUrl("https://example.com")).toBe(true);
      expect(isHttpUrl("http://sub.domain.vn/path")).toBe(true);
      expect(isHttpUrl("ftp://ftp.example.com")).toBe(false);
      expect(isHttpUrl("example.com")).toBe(false);
    });
  });

  describe("Type compatibility", () => {
    it("satisfies UpdateMeRequest schema", () => {
      const updateData: UpdateMeRequest = {
        name: "Lê Anh Hùng",
        bio: "Senior Product Designer",
        showOnlineStatus: true,
        location: "Đà Nẵng",
        hometown: "Quảng Nam",
        workplace: "Tech Corp",
        education: "Đại học Bách Khoa",
        website: "https://example.com",
        birthday: "1995-05-15",
      };

      expect(updateData.name).toBe("Lê Anh Hùng");
      expect(updateData.showOnlineStatus).toBe(true);
    });

    it("satisfies DeleteAccountRequest schema", () => {
      const deleteData: DeleteAccountRequest = {
        password: "secret_password",
      };

      expect(deleteData.password).toBe("secret_password");
    });
  });
});
