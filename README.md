# 🕷 Grapple Movement System

It's a momentum based grapple system for Roblox.

---

## ✨ Features

- Server side raycast validation
- Momentum preserving movement
- Smooth acceleration based pull
- Configurable modes:
  - Balanced
  - Arcade
  - Competitive
  - Swing (rope physics)
- Cooldown system
- Anti air grappling protection
- Wind audio effect
- Automatic cleanup system

---

## ⚙ Configuration

All main settings are located in the server script:

- `MaxDistance`
- `MinDistance`
- `StopDistance`
- `Cooldown`
- `PullAcceleration`
- `ArcBoost`
- `Mode`

You can tune these values to balance gameplay.

---

## 📁 Project Structure

GrappleTool (Tool)
│
├── ServerScript (Script)
├── ClientScript (LocalScript)
├── GrappleRemote (RemoteEvent)
│
├── WalkAnim (Animation)
├── JumpAnim (Animation)
├── GrappleAnim (Animation)
└── GrappleFlyAnim (Animation)

---

## 🧠 How It Works

1. Player clicks with tool equipped.
2. Client sends target position to server.
3. Server performs raycast validation.
4. If valid:
   - Pull force is applied using VectorForce.
   - Visual beam is created.
   - Client receives effects (shake + sound).
5. System cleans up automatically when finished.

All physics are handled on the server for security.
- Advanced combat systems

---

Built with clean structure and performance in mind.
