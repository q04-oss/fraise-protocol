/**
 * nfc.ts — FraiseNFC SDK module.
 *
 * Primarily used by the admin dashboard and device management tooling.
 * NFC devices call recordScan directly via the signer.py firmware.
 */

import {
  type PublicClient,
  type WalletClient,
  getContract,
} from "viem";
import { fraiseNFCAbi } from "./abis/index.js";

export class NFCModule {
  private readonly contract;

  constructor(
    private readonly publicClient: PublicClient,
    private readonly walletClient: WalletClient | undefined,
    address: `0x${string}`,
  ) {
    this.contract = getContract({
      address,
      abi: fraiseNFCAbi,
      client: publicClient,
    });
  }

  /** Get the block timestamp of the last scan for a given tag. */
  async lastScanAt(tagId: `0x${string}`): Promise<bigint> {
    return this.contract.read.lastScanAt([tagId]);
  }

  /** Total number of scans recorded on-chain. */
  async totalScans(): Promise<bigint> {
    return this.contract.read.totalScans();
  }

  /** On-chain minimum scan interval in seconds. */
  async minScanInterval(): Promise<bigint> {
    return this.contract.read.MIN_SCAN_INTERVAL();
  }

  /** Time credits awarded per scan in seconds. */
  async scanCreditSeconds(): Promise<bigint> {
    return this.contract.read.scanCreditSeconds();
  }

  /** Check if a tag is currently within the cooldown window. */
  async isOnCooldown(tagId: `0x${string}`): Promise<boolean> {
    const [lastScan, interval] = await Promise.all([
      this.lastScanAt(tagId),
      this.minScanInterval(),
    ]);
    if (lastScan === 0n) return false;
    const blockTime = BigInt(Math.floor(Date.now() / 1000));
    return blockTime - lastScan < interval;
  }

  /** Add a device address (admin only). */
  async addDevice(device: `0x${string}`): Promise<`0x${string}`> {
    this._requireWalletClient();
    const { request } = await this.publicClient.simulateContract({
      address: this.contract.address,
      abi: fraiseNFCAbi,
      functionName: "addDevice",
      args: [device],
      account: this.walletClient!.account,
    });
    return this.walletClient!.writeContract(request);
  }

  /** Revoke a device address (admin only). */
  async revokeDevice(device: `0x${string}`): Promise<`0x${string}`> {
    this._requireWalletClient();
    const { request } = await this.publicClient.simulateContract({
      address: this.contract.address,
      abi: fraiseNFCAbi,
      functionName: "revokeDevice",
      args: [device],
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
