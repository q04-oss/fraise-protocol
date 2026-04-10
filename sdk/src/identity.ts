/**
 * identity.ts — FraiseIdentity SDK module.
 */

import {
  type PublicClient,
  type WalletClient,
  getContract,
  zeroAddress,
} from "viem";
import { fraiseIdentityAbi } from "./abis/index.js";

export class IdentityModule {
  private readonly contract;

  constructor(
    private readonly publicClient: PublicClient,
    private readonly walletClient: WalletClient | undefined,
    address: `0x${string}`,
  ) {
    this.contract = getContract({
      address,
      abi: fraiseIdentityAbi,
      client: publicClient,
    });
  }

  /** Resolve a label to a wallet address. Returns null if not registered. */
  async getWallet(label: string): Promise<string | null> {
    const addr = await this.contract.read.getWallet([label]);
    return addr === zeroAddress ? null : addr;
  }

  /** Reverse-resolve a wallet to its label. Returns null if not registered. */
  async getLabel(wallet: `0x${string}`): Promise<string | null> {
    const label = await this.contract.read.getLabel([wallet]);
    return label.length > 0 ? label : null;
  }

  /** Check if a label is available for registration. */
  async isAvailable(label: string): Promise<boolean> {
    return this.contract.read.isAvailable([label]);
  }

  /**
   * Self-register a label with a registrar signature.
   * The caller (msg.sender) is the wallet that gets the identity.
   * The signature must be produced by the registrar key off-chain.
   */
  async selfRegister(
    label: string,
    signature: `0x${string}`,
  ): Promise<`0x${string}`> {
    this._requireWalletClient();
    const { request } = await this.publicClient.simulateContract({
      address: this.contract.address,
      abi: fraiseIdentityAbi,
      functionName: "selfRegister",
      args: [label, signature],
      account: this.walletClient!.account,
    });
    return this.walletClient!.writeContract(request);
  }

  private _requireWalletClient(): void {
    if (!this.walletClient) {
      throw new Error("walletClient is required for write operations");
    }
  }
}
