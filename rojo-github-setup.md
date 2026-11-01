# 🎮 Rojo + GitHub Setup Guide (Full CLI)

> [!IMPORTANT]
> All steps below are done entirely via CLI — no GUI required (except connecting Rojo plugin inside Roblox Studio once).

---

## ✅ Prerequisites

Install these first if you haven't:

| Tool | Install Command |
|------|----------------|
| [Git](https://git-scm.com/) | `winget install Git.Git` |
| [Aftman](https://github.com/LPGhatguy/aftman) | Download from releases, add to PATH |
| [GitHub CLI](https://cli.github.com/) | `winget install GitHub.cli` |

Verify installs:
```powershell
git --version
gh --version
aftman --version
```

---

## 🔐 Step 1 — Authenticate GitHub CLI

```powershell
gh auth login
# Choose: GitHub.com → HTTPS → Login with a web browser
```

---

## 📦 Step 2 — Install Rojo via Aftman

```powershell
# Install Aftman globally (run once ever)
aftman install

# Add Rojo to your global tools
aftman add --global rojo-rbx/rojo
```

Verify:
```powershell
rojo --version
```

---

## 📁 Step 3 — Create Your Project

```powershell
# Replace "MyGame" with your project name
$PROJECT = "MyGame"

mkdir $PROJECT
cd $PROJECT

# Initialize Rojo project
rojo init
```

This creates:
```
MyGame/
├── default.project.json
└── src/
    ├── client/
    ├── server/
    └── shared/
```

---

## ⚙️ Step 4 — Configure `default.project.json`

Replace the contents with a proper structure:

```powershell
@"
{
  "name": "MyGame",
  "tree": {
    "\$className": "DataModel",
    "ServerScriptService": {
      "\$className": "ServerScriptService",
      "Server": {
        "\$path": "src/server"
      }
    },
    "StarterPlayer": {
      "\$className": "StarterPlayer",
      "StarterPlayerScripts": {
        "\$className": "StarterPlayerScripts",
        "Client": {
          "\$path": "src/client"
        }
      }
    },
    "ReplicatedStorage": {
      "\$className": "ReplicatedStorage",
      "Shared": {
        "\$path": "src/shared"
      }
    }
  }
}
"@ | Set-Content default.project.json
```

---

## 📝 Step 5 — Add Initial Files

```powershell
# Create placeholder scripts
New-Item src/server/Main.server.lua -Force
New-Item src/client/Main.client.lua -Force
New-Item src/shared/Types.lua -Force

# Write starter content
"-- Server entry point" | Set-Content src/server/Main.server.lua
"-- Client entry point" | Set-Content src/client/Main.client.lua
"-- Shared types and utilities" | Set-Content src/shared/Types.lua
```

---

## 🙈 Step 6 — Create `.gitignore`

```powershell
@"
# Roblox place files (don't commit these)
*.rbxl
*.rbxlx

# Aftman lockfile (optional, keep if you want reproducible versions)
# aftman.toml

# OS junk
.DS_Store
Thumbs.db
desktop.ini

# Editor
.vscode/settings.json
"@ | Set-Content .gitignore
```

---

## 📖 Step 7 — Create `README.md`

```powershell
@"
# MyGame

A Roblox game built with [Rojo](https://rojo.space/).

## Setup

1. Install [Aftman](https://github.com/LPGhatguy/aftman)
2. Run \`aftman install\` to get Rojo
3. Run \`rojo serve\` and connect via the Rojo Studio plugin

## Structure

| Folder | Maps To |
|--------|---------|
| \`src/server/\` | ServerScriptService |
| \`src/client/\` | StarterPlayerScripts |
| \`src/shared/\` | ReplicatedStorage |
"@ | Set-Content README.md
```

---

## 🔁 Step 8 — Initialize Git & Commit

```powershell
git init
git add .
git commit -m "chore: initial Rojo project setup"
```

---

## ☁️ Step 9 — Create GitHub Repo & Push

```powershell
# Creates a public repo on GitHub and pushes
gh repo create MyGame --public --source=. --remote=origin --push

# Or private:
gh repo create MyGame --private --source=. --remote=origin --push
```

> [!TIP]
> After this, your repo is live at `https://github.com/YOUR_USERNAME/MyGame`

---

## ▶️ Step 10 — Start Rojo & Sync with Studio

```powershell
rojo serve
```

Then in **Roblox Studio**:
- Open the **Rojo plugin** (install from Roblox marketplace if needed)
- Click **Connect** — it auto-connects to `localhost:34872`

Any file you save in VS Code instantly appears in Studio. ✅

---

## 🔄 Daily Workflow

```powershell
# Start your session
cd MyGame
rojo serve

# After making changes, commit & push
git add .
git commit -m "feat: add new mechanic"
git push
```

---

## 🧰 Optional: Add More Tools via Aftman

Create `aftman.toml` in your project for per-project tools:

```powershell
@"
[tools]
rojo = "rojo-rbx/rojo@7.4.4"
selene = "Kampfkarren/selene@0.27.1"
stylua = "JohnnyMorganz/StyLua@0.20.0"
wally = "UpliftGames/wally@0.3.2"
"@ | Set-Content aftman.toml

# Install them all
aftman install
```

| Tool | Purpose |
|------|---------|
| **Selene** | Luau linter — catches bugs |
| **StyLua** | Auto-formats your Luau code |
| **Wally** | Package manager (like npm for Roblox) |

---

## 📌 Full Command Cheatsheet

```powershell
rojo serve               # Start sync server
rojo build -o game.rbxl  # Build a .rbxl place file
rojo fmt                 # (if applicable)

git status               # Check changes
git add .                # Stage all
git commit -m "message"  # Commit
git push                 # Push to GitHub

gh repo view --web       # Open repo in browser
gh pr create             # Create a pull request
```
