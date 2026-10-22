import type { ReactNode } from "react";
import { loadSite, siteMetadata, SiteLayout } from "@dylkit/web";

const site = loadSite();

export const metadata = siteMetadata(site);

export default function RootLayout({ children }: { children: ReactNode }) {
  return <SiteLayout site={site}>{children}</SiteLayout>;
}
