/**
 * types.ts — Shared types for the Fraise identity layer.
 *
 * FraiseIdentity maps human-readable labels (e.g. "alice.fraise.box") to
 * Ethereum wallet addresses. Labels follow the pattern <handle>.fraise.box.
 * The .box TLD is on Optimism; we replicate the resolution on-chain via
 * FraiseIdentity.sol so that no external DNS dependency exists at runtime.
 */

/** A resolved fraise.box identity. */
export interface FraiseIdentity {
  /** The full label, e.g. "alice.fraise.box" */
  label: string;
  /** The Ethereum wallet address associated with this label. */
  wallet: string;
  /** Unix timestamp (seconds) of when the identity was registered on-chain. */
  registeredAt: number;
}

/** Registration request — used by the backend registrar service. */
export interface RegistrationRequest {
  /** Target wallet address. */
  wallet: string;
  /** Desired label (without TLD suffix validation — caller must validate). */
  label: string;
  /** ECDSA signature from the registrar key, as produced by signRegistration(). */
  signature: string;
}

/** Result of a resolution attempt. */
export type ResolutionResult =
  | { found: true; identity: FraiseIdentity }
  | { found: false; label: string };

/** Tier values mirroring the on-chain FraiseTimeCredits.Tier enum. */
export enum Tier {
  None = 0,
  Standard = 1,
  Reserve = 2,
  Estate = 3,
}

/** Human-readable tier display info. */
export const TIER_LABELS: Record<Tier, string> = {
  [Tier.None]: "None",
  [Tier.Standard]: "Standard",
  [Tier.Reserve]: "Reserve",
  [Tier.Estate]: "Estate",
};
