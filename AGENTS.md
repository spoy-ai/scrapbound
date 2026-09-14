# Scrapbound version safety

- Preserve the playable baseline tag `v0.3.0`. Never move or delete an existing stable tag, force-push history, or overwrite a release asset as a routine update.
- Before a new round of implementation, inspect the working tree and create a development branch from the appropriate current state. Preserve user changes and checkpoint meaningful stages.
- Keep runtime art, animations, fonts and music in Git. Store raw source media in release archives; exclude platform job/status/request/response records and signed download URLs.
- Validate a clean restoration, including first-run resource import, before publishing a new baseline. Add a new version tag rather than replacing an earlier one.
- Use GitHub commits and version tags as the rollback mechanism. The user explicitly declined separate recovery scripts, offline bundles, and persistent local backup/test-copy directories. Do not reintroduce them unless requested.
- Publishing or sending external messages requires authorization from the conversation. The initial repository and v0.3.0 release are authorized by the user.
