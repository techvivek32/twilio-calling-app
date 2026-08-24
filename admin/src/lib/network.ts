import os from 'node:os';

export type ServerAddress = {
  url: string;
  label: string;
  /** Reachable from another device on the network, not just this machine. */
  external: boolean;
};

/**
 * Addresses this server can be reached on, for the "point your phone here"
 * hint. `localhost` is listed first for desktop use; the LAN entries are what
 * a physical phone needs.
 */
export function serverAddresses(port = 3000): ServerAddress[] {
  // On a hosted deployment the machine's own interfaces are private and
  // useless to a phone; the public URL is the only address that works.
  const deployed =
    process.env.VERCEL_PROJECT_PRODUCTION_URL ?? process.env.VERCEL_URL;
  if (deployed) {
    return [
      {
        url: `https://${deployed}`,
        label: 'this deployment',
        external: true,
      },
    ];
  }

  const addresses: ServerAddress[] = [
    { url: `http://localhost:${port}`, label: 'This computer', external: false },
    {
      url: `http://10.0.2.2:${port}`,
      label: 'Android emulator',
      external: false,
    },
  ];

  for (const [name, entries] of Object.entries(os.networkInterfaces())) {
    for (const entry of entries ?? []) {
      // Node <18.4 reports family as 'IPv4'; newer versions use 4.
      const isIpv4 = entry.family === 'IPv4' || (entry.family as unknown) === 4;
      if (!isIpv4 || entry.internal) continue;
      // Link-local addresses mean "no DHCP lease"; they never route.
      if (entry.address.startsWith('169.254.')) continue;

      addresses.push({
        url: `http://${entry.address}:${port}`,
        label: name,
        external: true,
      });
    }
  }

  return addresses;
}
