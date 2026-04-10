/**
 * client.ts — FraiseClient factory.
 *
 * Creates a pre-wired client that exposes all Fraise Protocol modules.
 *
 * Usage:
 *   import { createFraiseClient } from "@fraise/sdk";
 *   import { createPublicClient, createWalletClient, http } from "viem";
 *   import { optimism } from "viem/chains";
 *
 *   const publicClient = createPublicClient({ chain: optimism, transport: http() });
 *   const fraise = createFraiseClient({ publicClient });
 *
 *   const balance = await fraise.timeCredits.getBalance("0x...");
 */

import type { PublicClient, WalletClient } from "viem";
import { getAddresses } from "./addresses/index.js";
import { IdentityModule } from "./identity.js";
import { NFCModule } from "./nfc.js";
import { PaymentsModule } from "./payments.js";
import { TimeCreditsModule } from "./timeCredits.js";

export interface FraiseClientConfig {
  publicClient: PublicClient;
  walletClient?: WalletClient;
  /** Override chain ID (defaults to publicClient's chain). */
  chainId?: number;
}

export interface FraiseClient {
  identity: IdentityModule;
  nfc: NFCModule;
  timeCredits: TimeCreditsModule;
  payments: PaymentsModule;
}

export function createFraiseClient(config: FraiseClientConfig): FraiseClient {
  const chainId = config.chainId ?? config.publicClient.chain?.id;
  if (!chainId) {
    throw new Error("Chain ID must be set on publicClient or passed explicitly");
  }

  const addresses = getAddresses(chainId);

  return {
    identity: new IdentityModule(
      config.publicClient,
      config.walletClient,
      addresses.identity,
    ),
    nfc: new NFCModule(
      config.publicClient,
      config.walletClient,
      addresses.nfc,
    ),
    timeCredits: new TimeCreditsModule(
      config.publicClient,
      config.walletClient,
      addresses.timeCredits,
    ),
    payments: new PaymentsModule(
      config.publicClient,
      config.walletClient,
      addresses.payments,
    ),
  };
}
