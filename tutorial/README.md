# Overview
> **Note:** This tutorial walks through how to build a payment application using the Swift Wallet SDK. It primarily uses the [`stellar-wallet-sdk`](https://developers.stellar.org/docs/building-apps/wallet/overview) (version 0.6.6+) and in some cases also uses the core [`stellar-ios-mac-sdk`](https://github.com/Soneso/stellar-ios-mac-sdk).

We'll walk through the steps as we build a sample application called [`SwiftBasicPay`](https://github.com/Soneso/SwiftBasicPay), which showcases various features of the Stellar Swift Wallet SDK.

## Installation

Clone the [`SwiftBasicPay`](https://github.com/Soneso/SwiftBasicPay) repository and open the project in Xcode:

```bash
git clone https://github.com/Soneso/SwiftBasicPay.git
cd SwiftBasicPay
open SwiftBasicPay.xcodeproj
```

Build and run using iPhone simulator (iOS 17.5+).

## Chapters

1. [`Secure data storage`](secure_data_storage.md) - Keychain integration for secret keys and sensitive data
2. [`Authentication`](authentication.md) - PIN-based authentication and signing key management
3. [`Sign up and sign in`](signup_and_sign_in.md) - Account creation and user onboarding
4. [`Dashboard Data`](dashboard_data.md) - State management with domain managers
5. [`Account creation`](account_creation.md) - Funding accounts on the Stellar Network
6. [`Manage trust`](manage_trust.md) - Adding and removing asset trustlines
7. [`Payment`](payment.md) - Sending simple payments with the Stellar Wallet SDK
8. [`Path payment`](path_payment.md) - Cross-asset payments using order books
9. [`Anchor integration`](anchor_integration.md) - SEP-6/24 deposits and withdrawals

## SDK Dependencies

- `stellar-wallet-sdk` (0.6.6+): High-level wallet operations
- `stellar-ios-mac-sdk` (3.2.3+): Core Stellar protocol implementation
- `SimpleKeychain` (1.3.0): Secure storage wrapper
- `CryptoSwift` (1.8.4): Encryption utilities

## Next

Continue with [`Secure data storage`](secure_data_storage.md).