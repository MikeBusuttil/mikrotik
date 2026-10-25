# Mikrotinkering

## Reset router

- bake values from .env into config & upload
  ```bash
  source .env && envsubst < foxes.busuttil.ca > rsc/reset.rsc
  scp -O rsc/reset.rsc admin@192.168.1.1:flash/reset.rsc
  ```

- ssh in & reset
  ```routeros
  /system reset-configuration no-defaults=yes run-after-reset=flash/reset.rsc
  ```

## Configure SSH access

- upload public key
  ```sh
  scp -O ~/.ssh/id_rsa.pub admin@192.168.1.1:id_rsa.pub
  ```

- activate key and clean-up
  ```routeros
  /user ssh-keys import user=admin public-key-file=id_rsa.pub
  /file remove id_rsa.pub
  ```

## VPN Setup

- Generate a .ovpn file for each remote client:

  ```bash
  ./VPN.sh mike-laptop
  ```
