# Hytale Dedicated Server – Docker Deployment

## Overview

This repository provides a Docker-based deployment for a Hytale dedicated server.

The container image embeds the official Hytale downloader at build time, while server binaries and runtime data are managed at runtime through a bind-mounted data directory.
Authentication and initial provisioning require an interactive terminal and therefore **must be performed using an attached container session**.

## Architecture Summary

* Java runtime: Eclipse Temurin (JRE, pinned version)
* Container runtime: Docker
* Orchestration: Docker Compose
* Execution user: non-root (UID 42420)
* Init system: `tini` (proper PID 1 handling)
* Persistence model: bind mount on local filesystem
* Network protocol: UDP (QUIC-based)

## Prerequisites

* Docker Engine (recent stable version)
* Docker Compose v2
* Linux host recommended

## Environment Configuration

Configuration is managed through environment variables defined in `.env`.

Key parameters include:

* Network binding (IP and UDP port)
* JVM memory sizing and garbage collection options
* Authentication mode
* Update channel selection
* Optional server runtime arguments

An example configuration is provided in `.env.example`.

## Build and Startup

Build and start the server in detached mode:

```bash
docker compose up --build
```

During the first startup, the server will display a device authentication URL similar to:
```
https://oauth.accounts.hytale.com/oauth2/device/verify?user_code=XXXXX
```

1. Open the displayed link in a web browser

2. Complete the authentication process on the Hytale website

3. Return to the server console

Wait until the following message appears in the console:

```
No server tokens configured. Use /auth login to authenticate.
```

Press `d` for detach from `compose up`

At this stage, the server process will start, but authentication may not yet be completed.

## Mandatory Interactive Authentication (Attach Required)

### Important Notice

The Hytale authentication workflow **requires an attached TTY**.
Authentication commands are supported only from an attached TTY and are not guaranteed to work correctly through logs, exec-only sessions, or detached mode.

The container **must be attached** during the authentication phase.

### Attach to the Container

```bash
docker compose attach hytale
```

Once attached, the server console is directly accessible.

## Authentication Procedure

The following commands **must be executed from the attached server console**:

1. Device login:

   ```text
   /auth login device
   ```

the server will display a device authentication URL similar to:

```
 https://oauth.accounts.hytale.com/oauth2/device/verify?user_code=????
```

   - Open the displayed link in a web browser

   - Complete the authentication process on the Hytale website

   - Return to the server console

2. Persistent authentication:

   ```text
   /auth persistence Encrypted
   ```

These steps generate and store authentication artifacts inside the persistent data directory.

After successful completion, the container can be safely detached.
Do **not** stop the server using `Ctrl+C`, as this will terminate the process.
To detach while keeping the server running, use `Ctrl+P` followed by `Ctrl+Q` (AZERTY keyboard layout).

## Server Configuration

Server configuration is stored in:

```text
data/server/config.json
```

The configuration file is **generated automatically by Hytale during the first server startup**.

### Editing the Configuration (Linux)

Copy the configuration file from the container to the host:

```bash
docker cp hytale:/data/server/config.json ./config.json
```

Edit the file using any text editor:

```bash
nano config.json
# or vim / code / etc.
```

Copy the modified file back into the container and restart the server:

```bash
docker cp ./config.json hytale:/data/server/config.json
docker compose restart hytale
```

### Common Configuration Adjustments

```json
{
  ...
  "ServerName": "Server Name",
  "MaxViewRadius": 12,
  ...
}
```

Reducing `MaxViewRadius` can significantly improve server performance by lowering the amount of world data processed and sent to clients, especially on machines with limited CPU or memory resources.

Most configuration changes require a server restart to take effect.

## Runtime Management

### View Logs

```bash
docker compose logs -f hytale
```

### Re-attach to the Console

```bash
docker compose attach hytale
```

### Stop the Server

```bash
docker compose down
```

### Reset data

```bash
docker compose down -v
```

## Persistence Model

All runtime data is stored under the `data/` directory:

* Server binaries
* Assets
* Authentication state
* Configuration
* Logs

Rebuilding or updating the container image does **not** affect persistent data.

## JVM and Performance Considerations

* JVM heap size must remain consistent with available host memory
* Container memory limits should exceed `-Xmx` by a safe margin to avoid native out-of-memory conditions
