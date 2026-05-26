# How to Set This Up in Your Own Homelab

Hey there! If you're looking at this repo and thinking, "I want to run this on my own home server," you're in the right place. 

I built this project to manage my home server using enterprise-scale Fleet Operations practices, intentionally designing it so you can safely run it on a spare PC, a Raspberry Pi, or a dedicated bare-metal server in your closet without breaking your home network.

Here is the step-by-step guide on how to clone this and get it running.

---

## Prerequisites
Before you begin, you just need:
1. A machine running a Debian-based Linux distribution (Ubuntu Server 22.04/24.04 or Debian 12 is highly recommended).
2. SSH access to that machine.
3. A user account with `sudo` privileges.

## Step 1: Clone the Repository
SSH into your home server and clone this repo into your `/opt` directory (or wherever you prefer to keep your infrastructure code):

```bash
cd /opt
sudo git clone https://github.com/YOUR_USERNAME/baremetal-homelab.git
cd baremetal-homelab
```

## Step 2: Run the ZTP Bootstrap (Zero-Touch Provisioning)
First, we need to get the baseline dependencies installed. The bootstrap script will automatically install essential sysadmin tools (`lm-sensors`, `htop`, `net-tools`), setup the Docker CE runtime, and get your system prepped.

Run it with sudo:
```bash
sudo bash provisioning/server_bootstrap.sh
```
*Note: Depending on your internet speed, this usually takes about 2-3 minutes. It will log everything to `/var/log/baremetal-bootstrap.log` if you want to tail it in another window!*

## Step 3: Harden the OS (Read This Carefully!)
Next up is the OS hardening. 

> **WARNING:** This script configures a strict `UFW` (Uncomplicated Firewall) default-deny policy. 

To make sure you don't accidentally lock yourself out of SSH, the script automatically attempts to detect your current local LAN subnet (e.g., `192.168.1.0/24`) and whitelists it. However, always double-check the script logic to ensure it matches your router's network before running it blindly!

When you're ready to tune your TCP/IP stack (BBR congestion control) and lock down the firewall, run:
```bash
sudo bash security/harden_server.sh
```

## Step 4: Fire Up the Hardware Telemetry
This part is really cool. Instead of relying on simulated data, we are going to use `lm-sensors` to scrape your *actual* physical CPU temperatures and disk usage.

1. Copy the systemd service to your system:
   ```bash
   sudo cp systemd/hardware-telemetry.service /etc/systemd/system/
   ```
2. Enable and start the daemon:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now hardware-telemetry.service
   ```
3. You can verify it's running by checking the status: `sudo systemctl status hardware-telemetry.service`. It will start dumping real hardware metrics into `/var/lib/prometheus/node-exporter/`.

## Step 5: Deploy the Fleet Control Plane (via Ansible)
Now for the grand finale. We are going to use Ansible to deploy our Docker Compose stack (Prometheus, Grafana, Pi-hole, and our Nginx proxy) to prove our configuration management works perfectly.

Make sure Ansible is installed (the bootstrap script should have handled the python prerequisites), then run the playbook:
```bash
sudo apt install -y ansible
ansible-playbook -i ansible/inventory.ini ansible/site.yml
```

### What just happened?
Ansible just reached out to your local machine, verified the telemetry service is running, and stood up the entire Docker Compose control plane.

## Step 6: Access Your New Dashboards!
Everything is now routed through the Nginx reverse proxy on port 80.
Open a web browser on your laptop and type in the IP address of your home server:

* **Grafana Dashboard**: `http://<YOUR_SERVER_IP>/` (Login: `admin` / `homelab_secure_password`)
* **Pi-hole Admin**: `http://<YOUR_SERVER_IP>/admin` (Password: `homelab_secure_password`)

*(Pro-tip: Don't forget to change these passwords in the `docker-compose.yml` file!)*

---

### Need to check the health of the system?
I wrote a Python operational tool to verify everything is running smoothly. Give it a run:
```bash
sudo python3 tools/fleet_health.py
```
It will check your systemd services, parse your disk space to ensure your mounts aren't full, and verify all Docker containers are healthy.

Enjoy your new enterprise-grade homelab! If you run into any issues, feel free to open an issue on GitHub.
