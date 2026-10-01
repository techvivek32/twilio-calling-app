/**
 * Sends the browser to the Android build named by APK_DOWNLOAD_URL.
 *
 * A Google Drive share link (".../file/d/<id>/view") opens Drive's preview
 * page rather than the file, so it is rewritten to Drive's direct download
 * endpoint. `confirm=t` skips the "can't scan for viruses" page Drive shows
 * for large files. Any other URL (GitHub release asset, S3, …) is used as is.
 *
 * Deliberately outside the admin gate so the same link can be shared with
 * app users.
 */
function directDownloadUrl(raw: string): string {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return raw;
  }

  if (url.hostname === 'drive.google.com') {
    const id =
      url.pathname.match(/\/file\/d\/([^/]+)/)?.[1] ?? url.searchParams.get('id');
    if (id) {
      return `https://drive.usercontent.google.com/download?id=${encodeURIComponent(id)}&export=download&confirm=t`;
    }
  }

  return raw;
}

export function GET() {
  const configured = process.env.APK_DOWNLOAD_URL?.trim();
  if (!configured) {
    return new Response('The Android app is not available for download yet.', {
      status: 404,
      headers: { 'Content-Type': 'text/plain; charset=utf-8' },
    });
  }

  return new Response(null, {
    status: 302,
    headers: {
      Location: directDownloadUrl(configured),
      'Cache-Control': 'no-store',
    },
  });
}
