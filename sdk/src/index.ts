/**
 * @fraise/sdk — Fraise Protocol TypeScript SDK
 *
 * Built on viem. Targets Optimism mainnet and Optimism Sepolia.
 *
 * @example
 * ```ts
 * import { createFraiseClient } from "@fraise/sdk";
 * import { createPublicClient, http } from "viem";
 * import { optimism } from "viem/chains";
 *
 * const publicClient = createPublicClient({ chain: optimism, transport: http() });
 * const fraise = createFraiseClient({ publicClient });
 *
 * // Read a user's time credit balance
 * const balance = await fraise.timeCredits.getBalance("0xYourWallet");
 * console.log(TimeCreditsModule.formatBalance(balance)); // "7d 4h 30m"
 *
 * // Resolve a fraise.box label
 * const result = await fraise.identity.getWallet("alice.fraise.box");
 * ```
 */

// Client factory
export { createFraiseClient } from "./client.js";
export type { FraiseClient, FraiseClientConfig } from "./client.js";

// Modules
export { IdentityModule } from "./identity.js";
export { NFCModule } from "./nfc.js";
export { TimeCreditsModule, Tier, TIER_LABELS } from "./timeCredits.js";
export { PaymentsModule } from "./payments.js";

// ABIs (for consumers who want to use them directly with viem)
export {
  fraiseIdentityAbi,
  fraiseNFCAbi,
  fraiseTimeCreditsAbi,
  fraiseTokenAbi,
  fraisePaymentsAbi,
} from "./abis/index.js";

// Addresses
export { ADDRESSES, getAddresses } from "./addresses/index.js";
export type { FraiseAddresses, SupportedChainId } from "./addresses/index.js";
