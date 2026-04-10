# fraise-protocol

The open infrastructure layer for the Fraise ecosystem.

## Architecture

- **contracts/** — Solidity smart contracts on Optimism
  - Identity (`fraise.box`)
  - NFC verification events
  - $FRAISE gold-backed token (USDC bridge at launch)
  - Time credits
- **hardware/** — Device firmware and NFC reader code
- **identity/** — `fraise.box` identity resolution and wallet linking
- **sdk/** — Client SDK for interacting with the protocol

## Network

Optimism (Mainnet + Sepolia testnet)

## Payment Currency

USDC at launch → $FRAISE (gold-backed) on migration
