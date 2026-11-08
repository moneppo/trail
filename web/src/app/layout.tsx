import type { Metadata } from "next";
import { Barlow_Condensed, IM_Fell_English, Cormorant_SC } from "next/font/google";
import { themeInitScript } from "@/lib/theme";
import "./globals.css";

const display = Cormorant_SC({
  variable: "--font-display",
  weight: "600",
  subsets: ["latin"],
});

const body = IM_Fell_English({
  variable: "--font-body",
  weight: "400",
  style: ["normal", "italic"],
  subsets: ["latin"],
});

const data = Barlow_Condensed({
  variable: "--font-data",
  weight: ["500", "600"],
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Trail",
  description: "Track and review your walks",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="en"
      suppressHydrationWarning
      className={`${display.variable} ${body.variable} ${data.variable} h-full antialiased`}
    >
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeInitScript }} />
      </head>
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
