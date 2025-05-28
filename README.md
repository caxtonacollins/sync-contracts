# SYNC: 🌉 The Hybrid Fiat-Crypto Empire, The Bridge Between Two Worlds


- Telegram Community: [here](https://t.me/+lcd-x7E_9p4zYTM0)
- Dicord Community: [here](https://discord.gg/MpCrQzNE)

## Project Overview:
Sync is a decentralized payment protocol enabling instant fiat-to-crypto transactions on StarkNet. By combining non-custodial wallets, automated liquidity bridging, and StarkNet's ZK-rollup efficiency, Sync allows users to spend fiat (e.g., NGN, USD) while seamlessly tapping into crypto liquidity for settlements.


## Development:

Requirements:

- Rust
- Cairo
- Starknet foundry
- Node
- Yarn

## Installation Guide:

Step 1:

1. Fork the repo

2. Clone the forked repo to your local machine

```bash
git clone https://github.com/your-user-name/auto-swap
```

3. Setup contract:

```
cd contracts
```

// Install asdf scarb and starknet foundry:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.starkup.dev | sh
```

// Method 2:

Install asdf and install scarb, and starknet foundry: https://foundry-rs.github.io/starknet-foundry/getting-started/installation.html

4. Add development tools

```bash
asdf set --home scarb 2.11.4

asdf set --home starknet-foundry 0.43.0

```

5. Ensure installed properly

```bash
snforge --version

scarb --version
```

6. Build

```bash
scarb build
```

7. Test

```bash
snforge test
```

# Contributing

We welcome contributions! Please follow these steps:

## Getting Started

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/your-feature-name`)
3. Commit your changes with meaningful messages (`git commit -m 'feat: add new capability'`)
4. Test your changes thoroughly before submission

## Testing Requirements

Before submitting your PR:

1. All tests must pass locally before proceeding

## Pull Request Process

1. Ensure your branch is up to date with main (`git pull origin main`)
2. Include comprehensive test cases covering your changes
3. Update documentation to reflect your modifications
4. Provide a detailed description in your PR explaining:
   - The problem solved
   - Implementation approach
   - Any potential impacts
5. Request review from project maintainers

## Code Standards

- Follow the existing code style and conventions
- Write clean, readable, and maintainable code
- Include comments for complex logic
- Keep commits focused and atomic

## Support

Need help with your contribution? You can:

- Open an issue in the GitHub repository
- Join our Telegram channel for community assistance
- Check existing documentation and discussions

We aim to review all contributions promptly and appreciate your efforts to improve the project!
