/**
 * payments.ts — FraisePayments SDK module.
 */

import {
  type PublicClient,
  type WalletClient,
  getContract,
  parseUnits,
} from "viem";
import { fraisePaymentsAbi } from "./abis/index.js";

export class PaymentsModule {
  private readonly contract;

  constructor(
    private readonly publicClient: PublicClient,
    private readonly walletClient: WalletClient | undefined,
    address: `0x${string}`,
  ) {
    this.contract = getContract({
      address,
      abi: fraisePaymentsAbi,
      client: publicClient,
    });
  }

  /** Current fee in basis points. */
  async getFeeBps(): Promise<bigint> {
    return this.contract.read.feeBps();
  }

  /** Whether a token is accepted for payment. */
  async isSupported(token: `0x${string}`): Promise<boolean> {
    return this.contract.read.isSupported([token]);
  }

  /** All currently accepted payment tokens. */
  async getSupportedTokens(): Promise<readonly `0x${string}`[]> {
    return this.contract.read.supportedTokens();
  }

  /**
   * Calculate the fee and net amounts for a given gross amount.
   * Useful for displaying a breakdown before the user signs.
   */
  async getPaymentBreakdown(grossAmount: bigint): Promise<{
    gross: bigint;
    fee: bigint;
    net: bigint;
    feeBps: bigint;
  }> {
    const feeBps = await this.getFeeBps();
    const fee = (grossAmount * feeBps) / 10_000n;
    const net = grossAmount - fee;
    return { gross: grossAmount, fee, net, feeBps };
  }

  /**
   * Execute a payment.
   *
   * @param token     ERC-20 token address (must be whitelisted).
   * @param amount    Gross amount (in token's base units).
   * @param recipient Payment recipient address.
   * @param ref       Off-chain order reference (keccak256 of order UUID).
   *
   * Note: The caller must have approved the payments contract for at least `amount`
   * before calling this. Use the `approve` call on the token contract first.
   */
  async pay(
    token: `0x${string}`,
    amount: bigint,
    recipient: `0x${string}`,
    ref: `0x${string}`,
  ): Promise<`0x${string}`> {
    this._requireWalletClient();
    const { request } = await this.publicClient.simulateContract({
      address: this.contract.address,
      abi: fraisePaymentsAbi,
      functionName: "pay",
      args: [token, amount, recipient, ref],
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
