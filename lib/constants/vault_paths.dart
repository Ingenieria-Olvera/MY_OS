import '../services/vault_access.dart';

/// Resolves the `_inbox` folder URI inside the vault the user picked via
/// the Storage Access Framework (see [VaultAccess]). Returns null if no
/// vault has been picked yet, or if the picked vault has no `_inbox`
/// folder (the Python scrapers create it on first write).
Future<String?> resolveVaultInboxUri() => VaultAccess.resolveInboxUri();

/// Resolves the picked vault's root folder URI, or null if none picked yet.
Future<String?> resolveVaultRootUri() => VaultAccess.getVaultRootUri();
