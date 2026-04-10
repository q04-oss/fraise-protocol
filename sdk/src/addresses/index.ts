/**
 * addresses/index.ts — Deployed contract addresses per network.
 *
 * Populated after each deployment run. Commit changes here when deploying
 * a new version to testnet or mainnet.
 *
 * Chain IDs:
 *   10    — Optimism Mainnet
 *   11155420 — Optimism Sepolia (testnet)
 */

export type SupportedChainId = 10 | 11155420;

export interface FraiseAddresses {
  identity: `0x${string}`;
  timeCredits: `0x${string}`;
  nfc: `0x${string}`;
  token: `0x${string}`; // proxy address
  payments: `0x${string}`;
  timelock: `0x${string}`;
}

export const ADDRESSES: Record<SupportedChainId, FraiseAddresses> = {
  // Optimism Mainnet — populated after production deployment
  10: {
    identity: "0x0000000000000000000000000000000000000000",
    timeCredits: "0x0000000000000000000000000000000000000000",
    nfc: "0x0000000000000000000000000000000000000000",
    token: "0x0000000000000000000000000000000000000000",
    payments: "0x0000000000000000000000000000000000000000",
    timelock: "0x0000000000000000000000000000000000000000",
  },
  // Optimism Sepolia — populated after testnet deployment
  11155420: {
    identity: "0x0000000000000000000000000000000000000000",
    timeCredits: "0x0000000000000000000000000000000000000000",
    nfc: "0x0000000000000000000000000000000000000000",
    token: "0x0000000000000000000000000000000000000000",
    payments: "0x0000000000000000000000000000000000000000",
    timelock: "0x0000000000000000000000000000000000000000",
  },
} as const;

export function getAddresses(chainId: number): FraiseAddresses {
  const supported = ADDRESSES[chainId as SupportedChainId];
  if (!supported) {
    throw new Error(`Fraise Protocol not deployed on chain ${chainId}`);
  }
  return supported;
}
