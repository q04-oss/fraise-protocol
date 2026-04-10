/**
 * timeCredits.ts — FraiseTimeCredits SDK module.
 */

import {
  type PublicClient,
  type WalletClient,
  getContract,
} from "viem";
import { fraiseTimeCreditsAbi } from "./abis/index.js";

/** Mirrors the on-chain Tier enum. */
export enum Tier {
  None = 0,
  Standard = 1,
  Reserve = 2,
  Estate = 3,
}

export const TIER_LABELS: Record<Tier, string> = {
  [Tier.None]: "None",
  [Tier.Standard]: "Standard",
  [Tier.Reserve]: "Reserve",
  [Tier.Estate]: "Estate",
};

export class TimeCreditsModule {
  private readonly contract;

  constructor(
    private readonly publicClient: PublicClient,
    private readonly walletClient: WalletClient | undefined,
    address: `0x${string}`,
  ) {
    this.contract = getContract({
      address,
      abi: fraiseTimeCreditsAbi,
      client: publicClient,
    });
  }

  /** Current balance in seconds (linearly decays at 1 second per second). */
  async getBalance(wallet: `0x${string}`): Promise<bigint> {
    return this.contract.read.currentBalance([wallet]);
  }

  /** Total credits ever earned (never decreases). */
  async getLifetimeCredits(wallet: `0x${string}`): Promise<bigint> {
    return this.contract.read.lifetimeCredits([wallet]);
  }

  /** Current tier based on live balance. */
  async getTier(wallet: `0x${string}`): Promise<Tier> {
    const raw = await this.contract.read.getTier([wallet]);
    return raw as Tier;
  }

  /** Human-readable tier label for a wallet. */
  async getTierLabel(wallet: `0x${string}`): Promise<string> {
    const tier = await this.getTier(wallet);
    return TIER_LABELS[tier];
  }

  /**
   * Format a balance (in seconds) as a human-readable duration.
   * e.g. 90061 → "1d 1h 1m"
   */
  static formatBalance(seconds: bigint): string {
    const s = Number(seconds);
    if (s === 0) return "0s";
    const d = Math.floor(s / 86400);
    const h = Math.floor((s % 86400) / 3600);
    const m = Math.floor((s % 3600) / 60);
    const parts: string[] = [];
    if (d > 0) parts.push(`${d}d`);
    if (h > 0) parts.push(`${h}h`);
    if (m > 0) parts.push(`${m}m`);
    return parts.join(" ") || "<1m";
  }
}
