# 🔐 Secure Vault Extension — AI Build Spec Add-on

## 🎯 Objective

Add **encrypted folders (Vaults)** for sensitive notes (e.g., passwords, private data) using **hardware-backed encryption** from Android/iOS.

This must be:

* Secure by design
* Minimal UX friction
* Fully isolated from normal notes

---

## 🧠 Core Concept

Introduce a new entity:

Vault

* Locked container for sensitive notes
* Requires authentication (biometric/PIN)
* Uses device-backed encryption keys

---

## 🧱 Data Model

### Vault Entity

* id: String
* name: String
* createdAt: DateTime
* isLocked: bool

---

### SecureNote Entity (inside Vault)

* id: String
* vaultId: String
* encryptedData: String (AES encrypted payload)
* createdAt: DateTime
* updatedAt: DateTime

---

## 🔐 Encryption Architecture

### DO NOT:

* Store raw passwords
* Implement custom crypto algorithms
* Store encryption keys in plain storage

---

### USE PLATFORM APIs

#### Android

* Use Android Keystore
* Generate AES key (hardware-backed if available)
* Key is non-exportable

#### iOS

* Use Keychain
* Store encryption key securely
* Use Secure Enclave when available

---

### Encryption Flow

1. Generate encryption key (first vault creation)

2. Store key in Keystore/Keychain

3. On note save:

   * Serialize content → JSON
   * Encrypt using AES-GCM
   * Store encrypted blob

4. On unlock:

   * Authenticate user
   * Decrypt in memory only

---

## 🔑 Authentication

### Use Biometrics First

Flutter plugin:

* `local_auth`

Supports:

* Fingerprint
* Face unlock
* Device PIN fallback

---

### Vault Unlock Flow

1. User taps vault
2. Trigger biometric prompt
3. On success:

   * Fetch key
   * Decrypt notes
4. Auto-lock after timeout or app background

---

## 📂 UX Design

### Entry Point

* Separate section: “Vault”
* NOT mixed with normal notes

---

### Vault Behavior

* Locked state:

  * No preview of notes
  * No metadata leak

* Unlocked state:

  * Works like normal notes

---

### Visual Cues

* 🔒 icon for locked vault
* Blur content in app switcher

---

## ⚡ Performance Constraints

* Decryption must be fast (<100ms per note)
* Avoid decrypting all notes at once
* Use lazy decryption

---

## 🧪 Security Constraints

* No logs of decrypted data
* Clear memory after use (best effort)
* Prevent screenshots (optional but recommended)

---

## 🚫 Critical Non-Goals

* No cloud sync for encrypted data (initially)
* No password autofill system (not a password manager replacement)
* No custom encryption schemes

---

## 🧠 AI Agent Implementation Steps

1. Implement Vault entity + UI shell
2. Integrate biometric authentication
3. Add secure key generation (platform-specific)
4. Implement AES-GCM encryption layer
5. Create SecureNote CRUD
6. Add auto-lock + lifecycle handling
7. Add security hardening (no previews, no logs)

---

## ✅ Definition of Done

* User can:

  * Create a vault
  * Unlock with biometrics
  * Store encrypted notes
  * Lock vault manually or automatically

* Data remains encrypted at rest

* Keys never leave secure hardware storage

---

## 🔮 Future Enhancements

* Auto-lock timer customization
* Multiple vaults
* Secure sharing (advanced)
* Backup/export (encrypted)

---

## 🔚 End of Vault Spec
