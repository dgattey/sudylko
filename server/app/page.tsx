import { DownloadPage, latestRelease, loadSite } from "@dylkit/web";

const site = loadSite();

export default async function Home() {
  return <DownloadPage site={site} release={await latestRelease(site)} />;
}
