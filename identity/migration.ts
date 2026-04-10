/**
 * migration.ts — Seed FraiseIdentity from an existing off-chain user database.
 *
 * Purpose:
 *   When first deploying the on-chain identity registry, existing Maison Fraise
 *   users (stored in Postgres) need their wallet addresses and labels migrated
 *   onto FraiseIdentity. This script is a one-time batch registrar call.
 *
 * Usage:
 *   PRIVATE_KEY=0x... IDENTITY_ADDRESS=0x... npx tsx identity/migration.ts
 *
 * Safety:
 *   - Dry-run mode by default (set DRY_RUN=false to broadcast).
 *   - Already-registered labels are skipped (idempotent).
 *   - A CSV report is written to migration_report.csv.
 */

import fs from "node:fs";
import { createPublicClient, createWalletClient, http, parseAbi } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { optimism } from "viem/chains";

interface UserRecord {
  wallet: string;
  label: string; // e.g. "alice.fraise.box"
}

const IDENTITY_ABI = parseAbi([
  "function registerIdentity(address wallet, string label) external",
  "function isAvailable(string label) view returns (bool)",
  "function getWallet(string label) view returns (address)",
]);

async function main() {
  const privateKey = process.env.PRIVATE_KEY as `0x${string}`;
  const identityAddress = process.env.IDENTITY_ADDRESS as `0x${string}`;
  const rpcUrl = process.env.RPC_URL ?? "https://mainnet.optimism.io";
  const dryRun = process.env.DRY_RUN !== "false";
  const inputPath = process.env.INPUT_CSV ?? "users.csv";

  if (!privateKey || !identityAddress) {
    console.error("PRIVATE_KEY and IDENTITY_ADDRESS are required");
    process.exit(1);
  }

  console.log(`Mode: ${dryRun ? "DRY RUN" : "LIVE BROADCAST"}`);

  const account = privateKeyToAccount(privateKey);
  const publicClient = createPublicClient({ chain: optimism, transport: http(rpcUrl) });
  const walletClient = createWalletClient({ account, chain: optimism, transport: http(rpcUrl) });

  // Load user records from CSV (wallet,label)
  const users: UserRecord[] = fs
    .readFileSync(inputPath, "utf8")
    .split("\n")
    .slice(1) // skip header
    .filter(Boolean)
    .map((line) => {
      const [wallet, label] = line.split(",").map((s) => s.trim());
      return { wallet, label };
    });

  console.log(`Loaded ${users.length} users from ${inputPath}`);

  const report: string[] = ["wallet,label,status,tx_hash"];

  for (const { wallet, label } of users) {
    const available = await publicClient.readContract({
      address: identityAddress,
      abi: IDENTITY_ABI,
      functionName: "isAvailable",
      args: [label],
    });

    if (!available) {
      console.log(`SKIP — label already taken: ${label}`);
      report.push(`${wallet},${label},skipped,`);
      continue;
    }

    if (dryRun) {
      console.log(`DRY RUN — would register: ${label} → ${wallet}`);
      report.push(`${wallet},${label},dry_run,`);
      continue;
    }

    try {
      const hash = await walletClient.writeContract({
        address: identityAddress,
        abi: IDENTITY_ABI,
        functionName: "registerIdentity",
        args: [wallet as `0x${string}`, label],
      });

      console.log(`REGISTERED — ${label} → ${wallet} (tx: ${hash})`);
      report.push(`${wallet},${label},registered,${hash}`);

      // Avoid rate-limiting the RPC
      await new Promise((r) => setTimeout(r, 200));
    } catch (err) {
      console.error(`FAILED — ${label}: ${err}`);
      report.push(`${wallet},${label},failed,`);
    }
  }

  fs.writeFileSync("migration_report.csv", report.join("\n"));
  console.log("Report written to migration_report.csv");
}

main().catch(console.error);
