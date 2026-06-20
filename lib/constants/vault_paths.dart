/// Root of the Obsidian vault that's synced onto this device (e.g. via
/// Syncthing) and shared by the Notes screen and the Python scrapers' Inbox
/// digests.
const String vaultRootPath = '/storage/emulated/0/Remote_vault/Cross_Study';

/// Folder inside the vault where the Python scrapers write
/// slack_digest.json / email_digest.json. See python/README.md.
const String vaultInboxPath = '$vaultRootPath/_inbox';
