# Plan: DreamHost + GitHub Actions (CI/CD)

## Description

Set up CI/CD pipeline: push to main triggers tests in
GitHub Actions, then deploys to DreamHost via SSH + rsync.

## Flow

**Push → GitHub Actions runs tests → If pass, deploy via
SSH to DreamHost.**

---

## 1. Configure SSH access on DreamHost

Generate an SSH key pair and add the public key on
DreamHost (`~/.ssh/authorized_keys` of your user).

## 2. Add secrets on GitHub

In the repository, go to
**Settings → Secrets and variables → Actions** and add:

- `DH_HOST` — your server (e.g. `myserver.dreamhost.com`)
- `DH_USER` — your SSH user
- `DH_SSH_KEY` — the private key

## 3. Create the workflow

File: `.github/workflows/deploy.yml`

```yaml
name: Test and Deploy

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: |
          # your test commands here
          npm install && npm test

  deploy:
    needs: test  # only runs if tests pass
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.DH_SSH_KEY }}" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa
          ssh-keyscan ${{ secrets.DH_HOST }} >> ~/.ssh/known_hosts

      - name: Deploy via rsync
        run: |
          rsync -avz --delete \
            --exclude '.git' \
            --exclude 'node_modules' \
            ./ ${{ secrets.DH_USER }}@${{ secrets.DH_HOST }}:~/seusite.com/
```

## Notes

- `needs: test` ensures deploy only happens if test job
  passes.
- `rsync` transfers only modified files, making deploy
  fast.
- If the project needs a build step (generate static
  files), add it before rsync.
- With DreamHost + Passenger (Node/Python/Ruby), add
  `touch tmp/restart.txt` after rsync to restart the app.
- Simpler alternative for static/PHP sites: action
  `SamKirkland/FTP-Deploy-Action` with SFTP (but rsync
  is more robust).

## Tasks

- [ ] Generate SSH key pair for DreamHost
- [ ] Add public key to DreamHost `~/.ssh/authorized_keys`
- [ ] Add GitHub secrets (`DH_HOST`, `DH_USER`, `DH_SSH_KEY`)
- [ ] Create/update `.github/workflows/deploy.yml`
- [ ] Test pipeline end-to-end

## Progress

- (pending)
