import Link from "next/link";
import { ArrowLeft, Lock } from "lucide-react";
import { privacyPolicy } from "@/lib/legal-texts";

export const metadata = {
  title: "Chính sách quyền riêng tư - SocialHub",
};

export default function PrivacyPage() {
  return (
    <div className="min-h-screen bg-surface-muted dark:bg-appBg-dark py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-3xl mx-auto">
        <div className="mb-6">
          <Link
            href="/login"
            className="inline-flex items-center text-sm font-medium text-appText-secondary dark:text-appText-dark-secondary hover:text-brand dark:hover:text-brand-light transition"
          >
            <ArrowLeft className="w-4 h-4 mr-1.5" />
            Quay lại
          </Link>
        </div>

        <div className="bg-white dark:bg-surface-dark shadow-sm border border-appBorder-light dark:border-appBorder-dark rounded-2xl p-6 sm:p-10">
          <div className="flex items-center gap-3 mb-6 pb-6 border-b border-appBorder-light dark:border-appBorder-dark">
            <div className="p-3 bg-brand-soft dark:bg-brand/20 rounded-xl text-brand dark:text-brand-light">
              <Lock className="w-6 h-6" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-appText-primary dark:text-white">
                {privacyPolicy.title}
              </h1>
              <p className="text-sm text-appText-secondary dark:text-appText-dark-secondary">
                Cam kết bảo vệ thông tin và quyền riêng tư của bạn trên SocialHub
              </p>
            </div>
          </div>

          <div className="space-y-6">
            {privacyPolicy.sections.map((section, index) => (
              <div
                key={index}
                className="p-4 sm:p-5 rounded-xl bg-surface-muted/50 dark:bg-surface-dark-muted/40 border border-appBorder-light dark:border-appBorder-dark/80"
              >
                <h2 className="text-base font-semibold text-appText-primary dark:text-white mb-2">
                  {index + 1}. {section.heading}
                </h2>
                <p className="text-sm text-appText-secondary dark:text-appText-dark-primary leading-relaxed">
                  {section.body}
                </p>
              </div>
            ))}
          </div>

          <div className="mt-8 pt-6 border-t border-appBorder-light dark:border-appBorder-dark flex justify-between items-center text-sm">
            <Link
              href="/terms"
              className="text-brand dark:text-brand-light hover:underline font-medium"
            >
              Xem Điều khoản sử dụng →
            </Link>
            <span className="text-appText-secondary">SocialHub</span>
          </div>
        </div>
      </div>
    </div>
  );
}
