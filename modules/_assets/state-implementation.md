# Runtime State Persistence (`modules/state.nix`)

Framework for persisting runtime state across reboots for services that have no
inherent persistence. Generic and data-driven: every tracked service is one
entry in `services.state.items`; no module code changes are needed to add more.

## Why

- **Wifi** — NetworkManager already persists the global radio
  (`WirelessEnabled`) in `/var/lib/NetworkManager/NetworkManager.state` and
  re-applies it at daemon start (`nm_manager_start` in `nm-manager.c` reads the
  state file and forces kernel rfkill to match). Nothing needed.
- **Bluetooth** — BlueZ does not persist the `Powered` state. `AutoEnable=true`
  in `/etc/bluetooth/main.conf` only auto-powers when stored link keys exist, so
  the controller always boots `Powered: no`. This is the current item.

## Design

One `state-save.service` snapshots all items on graceful shutdown; one
`state-restore-<name>.service` per item re-applies it at boot.

- `state-save.service` is `Type = oneshot` + `RemainAfterExit = true`, so it
  starts once at boot, stays active, and its `ExecStop` runs at shutdown.
  `After =` the union of every item's `saveAfter` makes systemd stop it **first**
  at shutdown (reverse start order) — while the underlying services still answer.
- Each item's `save` snippet writes its snapshot to `/var/lib/state/<name>`
  (dir created via `systemd.tmpfiles.rules`).
- Each `state-restore-<name>.service` runs at boot after `restoreAfter` units
  (`wants` + `after`), plus `after = state-save.service` to avoid racing.

## Files

| File | Role |
| --- | --- |
| `/etc/nixos/modules/state.nix` | Framework: `services.state.items` option + generated units |
| `/etc/nixos/configuration.nix` | Imports the module, defines the `bluetooth` item |

## Option reference

`services.state.items.<name>`:

| Option | Type | Description |
| --- | --- | --- |
| `save` | string | Shell snippet run at shutdown. Runs while units in `saveAfter` are still up. |
| `restore` | string | Shell snippet run at boot, after units in `restoreAfter`. |
| `saveAfter` | list of string | Units that must still be running when `save` executes. |
| `restoreAfter` | list of string | Units that must be started before `restore` runs. |

## Current item: bluetooth

```nix
services.state.items = {
  bluetooth = {
    saveAfter = [ "bluetooth.service" ];
    restoreAfter = [ "bluetooth.service" ];
    save = ''
      if ${pkgs.bluez}/bin/bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
        echo on > /var/lib/state/bluetooth
      else
        echo off > /var/lib/state/bluetooth
      fi
    '';
    restore = ''
      if [ ! -f /var/lib/state/bluetooth ]; then
        exit 0
      fi
      target=$(cat /var/lib/state/bluetooth)
      btctl=${pkgs.bluez}/bin/bluetoothctl
      if [ "$target" = "on" ]; then
        for _ in $(seq 1 15); do
          if $btctl power on >/dev/null 2>&1; then
            exit 0
          fi
          sleep 1
        done
      else
        $btctl power off >/dev/null 2>&1 || true
      fi
    '';
  };
};
```

- `saveAfter`/`restoreAfter` = `bluetooth.service` — save happens while BlueZ is
  up; restore waits for the controller (hci0 registers late).
- `restore` retries `bluetoothctl power on` for up to 15s to ride out the
  adapter-registration race, and idempotently powers off otherwise.

## Generated units

```
state-save.service
  Type=oneshot  RemainAfterExit=true
  ExecStart=/nix/store/...-coreutils.../bin/true
  ExecStop=/nix/store/...-state-save          # concatenated `save` snippets
  After=[bluetooth.service]
  WantedBy=multi-user.target

state-restore-bluetooth.service
  Type=oneshot
  ExecStart=/nix/store/...-state-restore-bluetooth
  After=[state-save.service, bluetooth.service]
  Wants=[bluetooth.service]
  WantedBy=multi-user.target
```

Plus tmpfiles rule `d /var/lib/state 0755 root root -`.

## Adding a new item

For any service without inherent state persistence (e.g. a new radio daemon),
add one key to `services.state.items` with its four fields. No framework change.

## Verification

```sh
systemctl status state-save state-restore-bluetooth
bluetoothctl power on    # then reboot
bluetoothctl show | grep Powered   # expect "Powered: yes"
cat /var/lib/state/bluetooth
```

## Deploy

```sh
sudo cp modules/state.nix /etc/nixos/modules/
sudo cp configuration.nix /etc/nixos/
sudo nixos-rebuild switch
```
