# Grapple Movement System

A momentum based grapple system for Roblox.

---

## Features

- Server-side raycast validation
- Momentum-preserving movement
- Smooth acceleration-based pull
- Multiple gameplay modes:
  - Balanced
  - Arcade
  - Competitive
  - Swing (rope physics)
- Cooldown system
- Anti-air grappling protection
- Wind audio effect
- Automatic cleanup for all physics objects

---

## Configuration

All tuning values are located inside the server script:

- `MaxDistance`
- `MinDistance`
- `StopDistance`
- `Cooldown`
- `PullAcceleration`
- `ArcBoost`
- `Mode`

These values control range, strength, and overall balance.

---

## Project Structure

Inside the Tool:

- Server Script (handles physics, validation, cooldowns)
- Local Script (handles input, animations, effects)
- RemoteEvent (client ↔ server communication)
- Animations:
  - Walk
  - Jump
  - Grapple
  - Grapple Fly

---

## Functionality

1. The player equips the tool.
2. Clicking sends a request to the server.
3. The server performs a raycast check.
4. If the target is valid:
   - A pulling force is applied using VectorForce.
   - A visual beam is created.
   - The client plays screen effects and sound.
5. Everything is cleaned up automatically when finished.

All movement physics are handled on the server to keep the system secure and exploit resistant.

---

Built with clean structure, performance, and gameplay balance in mind.
