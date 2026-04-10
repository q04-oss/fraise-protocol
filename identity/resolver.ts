/**
 * resolver.ts — On-chain FraiseIdentity label resolver.
 *
 * Provides label → wallet and wallet → label lookups against the
 * FraiseIdentity contract deployed on Optimism.
 *
 * Usage:
 *   const resolver = new FraiseResolver(publicClient, IDENTITY_ADDRESS);
 *   const result = await resolver.resolve("alice.fraise.box");
 *   if (result.found) console.log(result.identity.wallet);
 */

import { type PublicClient, getContract, zeroAddress } from "viem";
import type { FraiseIdentity, ResolutionResult } from "./types";

// Minimal ABI for read-only identity queries
const IDENTITY_ABI = [
  {
    inputs: [{ name: "label", type: "string" }],
    name: "getWallet",
    outputs: [{ name: "", type: "address" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [{ name: "wallet", type: "address" }],
    name: "getLabel",
    outputs: [{ name: "", type: "string" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [{ name: "label", type: "string" }],
    name: "isAvailable",
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "view",
    type: "function",
  },
] as const;

export class FraiseResolver {
  private readonly contract;

  constructor(
    private readonly client: PublicClient,
    identityAddress: `0x${string}`,
  ) {
    this.contract = getContract({
      address: identityAddress,
      abi: IDENTITY_ABI,
      client,
    });
  }

  /**
   * Resolve a label to a wallet address.
   * Returns { found: false } if the label is not registered.
   */
  async resolve(label: string): Promise<ResolutionResult> {
    const wallet = await this.contract.read.getWallet([label]);

    if (wallet === zeroAddress) {
      return { found: false, label };
    }

    return {
      found: true,
      identity: {
        label,
        wallet,
        registeredAt: 0, // contract doesn't expose registeredAt; enrich from events if needed
      },
    };
  }

  /**
   * Reverse-resolve a wallet address to its label.
   * Returns null if the wallet has no registered identity.
   */
  async reverseResolve(wallet: `0x${string}`): Promise<string | null> {
    const label = await this.contract.read.getLabel([wallet]);
    return label.length > 0 ? label : null;
  }

  /**
   * Check whether a label is available for registration.
   */
  async isAvailable(label: string): Promise<boolean> {
    return this.contract.read.isAvailable([label]);
  }
}
