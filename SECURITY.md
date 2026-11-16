# Security

## Reporting a Vulnerability

Please report security problems privately through GitHub's [private vulnerability reporting](../../security/advisories/new) for this repository, not in a public issue. Include the game, what triggers the problem, and the version tag or commit you tested.

## What Counts

The games keep saved progress and settings on the device and in the player's own iCloud, and collect no data, so any of these is a security bug:

- a crash, hang, or unbounded memory or disk use caused by a save file or other stored data;
- a save file or setting that makes a game write outside its own storage;
- player data sent anywhere other than the player's own iCloud or Game Center;
- a purchase check that can be bypassed.
