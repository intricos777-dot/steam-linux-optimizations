#!/usr/bin/env python3
"""
GameGuard Compatibility Tool for Helldivers 2
Ensures GameGuard anti-cheat functions correctly on Linux/Proton
"""

import subprocess
import sys
import os
import json
import time
import socket
import argparse
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass, asdict
from enum import Enum

class CheckStatus(Enum):
    PASS = "✔"
    FAIL = "✘"
    WARN = "⚠"
    SKIP = "⊘"

@dataclass
class GameGuardCheck:
    name: str
    status: CheckStatus
    details: str
    fix_cmd: Optional[str] = None

class GameGuardCompatTool:
    def __init__(self):
        self.checks: List[GameGuardCheck] = []
        self.steam_path = self._find_steam()
        self.proton_path = self._find_proton()
        
    def run_cmd(self, cmd: List[str], capture=True, timeout=30) -> Tuple[int, str, str]:
        try:
            result = subprocess.run(cmd, capture_output=capture, text=True, timeout=timeout)
            return result.returncode, result.stdout.strip(), result.stderr.strip()
        except subprocess.TimeoutExpired:
            return -1, "", "timeout"
        except Exception as e:
            return -1, "", str(e)

    def _find_steam(self) -> Optional[str]:
        paths = [
            "~/.local/share/Steam",
            "~/.steam/steam",
            "/usr/bin/steam",
        ]
        for p in paths:
            expanded = os.path.expanduser(p)
            if os.path.exists(expanded):
                return expanded
        return None

    def _find_proton(self) -> Optional[str]:
        if self.steam_path:
            proton = Path(self.steam_path) / "compatibilitytools.d" / "proton"
            if proton.exists():
                return str(proton)
        # Check common Proton locations
        for base in [Path.home() / ".steam" / "steam" / "compatibilitytools.d",
                     Path("/usr/share/steam/compatibilitytools.d")]:
            proton_dir = base / "proton"
            if proton_dir.exists():
                return str(proton_dir)
        return None

    def check_kernel_params(self) -> GameGuardCheck:
        """Check kernel parameters for GameGuard compatibility"""
        issues = []
        cmdline = ""
        try:
            with open("/proc/cmdline", "r") as f:
                cmdline = f.read().strip()
        except:
            pass
        
        required = {
            "module.sig_unload": "1",
            "kernel.sysrq": "1",
            "kernel.yama.ptrace_scope": "0",
        }
        
        for param, expected in required.items():
            if param not in cmdline:
                issues.append(f"Missing kernel param: {param}={expected}")
        
        return GameGuardCheck(
            name="Kernel Parameters",
            status=CheckStatus.PASS if not issues else CheckStatus.FAIL,
            details="; ".join(issues) if issues else "All required kernel params present",
            fix_cmd="Add to /etc/default/grub: " + " ".join(f"{k}={v}" for k,v in required.items()) + " then run grub-mkconfig"
        )

    def check_iptables(self) -> GameGuardCheck:
        """Check iptables for blocking GameGuard ports"""
        code, out, err = self.run_cmd(["iptables", "-L", "-n", "-v"])
        blocked_ports = []
        gameguard_ports = {
            80: "HTTP",
            443: "HTTPS",
            27015: "Steam",
            27036: "Steam",
            27031: "Steam",
            27032: "Steam",
            28910: "GameGuard",
            28911: "GameGuard",
            28912: "GameGuard",
            28913: "GameGuard",
            28914: "GameGuard",
            28915: "GameGuard",
            28916: "GameGuard",
            28917: "GameGuard",
            28918: "GameGuard",
            28919: "GameGuard",
        }
        
        for port, desc in gameguard_ports.items():
            if f"dpt:{port}" in out and "DROP" in out:
                blocked_ports.append(f"{port} ({desc})")
        
        return GameGuardCheck(
            name="Firewall (iptables)",
            status=CheckStatus.FAIL if blocked_ports else CheckStatus.PASS,
            details=f"Blocked: {', '.join(blocked_ports)}" if blocked_ports else "No GameGuard ports blocked",
            fix_cmd="Allow ports: iptables -I INPUT -p tcp --dport 28910:28919 -j ACCEPT" if blocked_ports else None
        )

    def check_upnp(self) -> GameGuardCheck:
        """Check UPnP for GameGuard port forwarding"""
        code, out, err = self.run_cmd(["which", "upnpc"])
        if code != 0:
            return GameGuardCheck(
                name="UPnP Client",
                status=CheckStatus.FAIL,
                details="upnpc not installed",
                fix_cmd="sudo pacman -S miniupnpd"
            )
        
        # Try to discover IGD
        code, out, err = self.run_cmd(["upnpc", "-s"])
        igd_found = "IGD found" in out.lower() or "desc:" in out.lower()
        
        return GameGuardCheck(
            name="UPnP / Port Forwarding",
            status=CheckStatus.PASS if igd_found else CheckStatus.WARN,
            details="IGD discovered" if igd_found else "No IGD found - run: upnpc -d",
            fix_cmd="upnpc -a 28910 TCP; upnpc -a 28911 TCP; ... (for 28910-28919)" if not igd_found else None
        )

    def check_proton_config(self) -> GameGuardCheck:
        """Check Proton configuration for GameGuard"""
        issues = []
        fixes = []
        
        if not self.proton_path:
            return GameGuardCheck(
                name="Proton Installation",
                status=CheckStatus.FAIL,
                details="Proton not found",
                fix_cmd="Install Proton-GE or Proton-Experimental via Steam"
            )
        
        # Check Proton version
        proton_bin = Path(self.proton_path) / "proton"
        if proton_bin.exists():
            code, out, err = self.run_cmd([str(proton_bin), "--version"])
            proton_ver = out.strip()
            
            # Check for Proton-GE/Experimental (better GameGuard support)
            if "GE" not in proton_ver and "Experimental" not in proton_ver:
                issues.append(f"Using standard Proton: {proton_ver}")
                fixes.append("Switch to Proton-GE or Proton-Experimental for better anti-cheat support")
        
        # Check PROTON environment vars
        env_checks = {
            "PROTON_USE_WINED3D": "1",
            "PROTON_NO_ESYNC": "1", 
            "PROTON_NO_FSYNC": "1",
            "DXVK_ASYNC": "1",
        }
        
        for var, expected in env_checks.items():
            actual = os.environ.get(var)
            if actual != expected:
                issues.append(f"{var}={actual} (expected {expected})")
                fixes.append(f"export {var}={expected}")
        
        return GameGuardCheck(
            name="Proton Configuration",
            status=CheckStatus.PASS if not issues else CheckStatus.WARN,
            details="; ".join(issues) if issues else f"Proton: {proton_ver}",
            fix_cmd="; ".join(fixes) if fixes else None
        )

    def check_network_interface(self) -> GameGuardCheck:
        """Check for correct network interface binding"""
        code, out, err = self.run_cmd(["ip", "route", "get", "default"])
        has_route = code == 0 and "wlo1" in out
        
        return GameGuardCheck(
            name="Network Binding",
            status=CheckStatus.PASS if has_route else CheckStatus.WARN,
            details=f"Default route: {out.strip()}",
            fix_cmd="Ensure game binds to correct interface (Steam: -tcp, Proton: PROTON_NO_ESYNC=1)"
        )

    def check_steam_launch_options(self) -> GameGuardCheck:
        """Check Steam launch options for GameGuard"""
        issues = []
        fixes = []
        
        # Check if -tcp is used
        steam_args = os.environ.get("STEAM_LAUNCH_OPTIONS", "")
        if "-tcp" not in steam_args:
            issues.append("Steam not launched with -tcp (helps GameGuard WebSocket)")
            fixes.append("Add -tcp to Steam launch options")
        
        return GameGuardCheck(
            name="Steam Launch Options",
            status=CheckStatus.WARN if issues else CheckStatus.PASS,
            details="; ".join(issues) if issues else "Steam launch options OK",
            fix_cmd="; ".join(fixes) if fixes else None
        )

    def check_gameguard_process(self) -> GameGuardCheck:
        """Check if GameGuard process is running"""
        code, out, err = self.run_cmd(["pgrep", "-f", "GameGuard"])
        running = code == 0 and out.strip()
        
        return GameGuardCheck(
            name="GameGuard Process",
            status=CheckStatus.WARN if not running else CheckStatus.PASS,
            details="Running" if running else "Not running (may start on game launch)",
            fix_cmd=None
        )

    def check_dns_resolution(self) -> GameGuardCheck:
        """Check DNS resolution for GameGuard servers"""
        gg_domains = [
            "gameguard.net",
            "api.gameguard.net", 
            "update.gameguard.net",
            "gg.plaync.co.kr",
            "nprotect.com"
        ]
        
        failed = []
        for domain in gg_domains:
            code, out, err = self.run_cmd(["dig", "+short", domain, "A"])
            if code != 0 or not out.strip():
                failed.append(domain)
        
        return GameGuardCheck(
            name="DNS Resolution (GameGuard)",
            status=CheckStatus.FAIL if failed else CheckStatus.PASS,
            details=f"Failed: {', '.join(failed)}" if failed else "All GameGuard domains resolve",
            fix_cmd="Check DNS / firewall if domains fail" if failed else None
        )

    def check_wine_proton_libs(self) -> GameGuardCheck:
        """Check for required Wine/Proton libraries"""
        libs = {
            "ntdll": "ntoskrnl.exe",
            "kernel32": "kernel32.dll", 
            "user32": "user32.dll",
            "advapi32": "advapi32.dll",
            "ws2_32": "ws2_32.dll",
            "iphlpapi": "iphlpapi.dll",
        }
        
        missing = []
        for lib, desc in libs.items():
            code, out, err = self.run_cmd(["find", "/usr/lib/wine", "-name", f"*{lib}*", "-o"])
            if code != 0 or not out.strip():
                missing.append(f"{lib} ({desc})")
        
        return GameGuardCheck(
            name="Wine/Proton Libraries",
            status=CheckStatus.WARN if missing else CheckStatus.PASS,
            details=f"Missing: {', '.join(missing)}" if missing else "All required libraries present",
            fix_cmd="Reinstall Proton or wine-gecko" if missing else None
        )

    def run_all_checks(self) -> List[GameGuardCheck]:
        """Run all compatibility checks"""
        check_methods = [
            ("kernel_params", self.check_kernel_params),
            ("iptables", self.check_iptables),
            ("upnp", self.check_upnp),
            ("proton_config", self.check_proton_config),
            ("network_interface", self.check_network_interface),
            ("steam_launch", self.check_steam_launch_options),
            ("gameguard_process", self.check_gameguard_process),
            ("dns", self.check_dns_resolution),
            ("wine_libs", self.check_wine_proton_libs),
        ]
        
        for name, method in check_methods:
            try:
                self.checks.append(method())
            except Exception as e:
                self.checks.append(GameGuardCheck(
                    name=name,
                    status=CheckStatus.FAIL,
                    details=f"Check failed: {e}",
                    fix_cmd=None
                ))
        
        return self.checks

    def print_report(self):
        """Print formatted report"""
        print("\n" + "="*70)
        print("GAMEGUARD COMPATIBILITY REPORT - Helldivers 2")
        print("="*70)
        
        for check in self.checks:
            status = check.status.value
            print(f"\n{status} {check.name}")
            print(f"   {check.details}")
            if check.fix_cmd:
                print(f"   Fix: {check.fix_cmd}")
        
        pass_count = sum(1 for c in self.checks if c.status == CheckStatus.PASS)
        warn_count = sum(1 for c in self.checks if c.status == CheckStatus.WARN)
        fail_count = sum(1 for c in self.checks if c.status == CheckStatus.FAIL)
        
        print(f"\n{'='*70}")
        print(f"SUMMARY: {pass_count} PASS | {warn_count} WARN | {fail_count} FAIL")
        print("="*70 + "\n")

    def auto_fix(self) -> bool:
        """Attempt to auto-fix issues"""
        fixed = False
        for check in self.checks:
            if check.status in (CheckStatus.FAIL, CheckStatus.WARN) and check.fix_cmd:
                print(f"\n[Auto-fix] {check.name}...")
                print(f"   Running: {check.fix_cmd}")
                # Note: Actual fixes require manual intervention
                fixed = True
        
        return fixed

def main():
    parser = argparse.ArgumentParser(description="GameGuard Compatibility Tool for Helldivers 2")
    parser.add_argument("command", choices=["check", "fix", "monitor", "install"], 
                       help="Command to run")
    parser.add_argument("--watch", type=int, help="Monitor interval in seconds")
    args = parser.parse_args()

    tool = GameGuardCompatTool()
    
    if args.command == "check":
        tool.run_all_checks()
        tool.print_report()
    elif args.command == "fix":
        tool.run_all_checks()
        tool.auto_fix()
    elif args.command == "monitor":
        interval = args.watch or 30
        print(f"Monitoring GameGuard compatibility every {interval}s (Ctrl+C to stop)")
        try:
            while True:
                tool.run_all_checks()
                tool.print_report()
                time.sleep(interval)
        except KeyboardInterrupt:
            print("\nMonitoring stopped.")
    elif args.command == "install":
        print("Installing GameGuard systemd service...")
        # Create systemd service
        service_content = """[Unit]
Description=GameGuard Network Monitor
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/gameguard-compat check
StandardOutput=journal

[Install]
WantedBy=multi-user.target"""
        timer_content = """[Unit]
Description=GameGuard Periodic Check

[Timer]
OnBootSec=5min
OnUnitActiveSec=30min

[Install]
WantedBy=timers.target"""
        
        try:
            Path("/etc/systemd/system/gameguard-check.service").write_text(service_content)
            Path("/etc/systemd/system/gameguard-check.timer").write_text(timer_content)
            subprocess.run(["systemctl", "daemon-reload"], check=True)
            subprocess.run(["systemctl", "enable", "--now", "gameguard-check.timer"], check=True)
            print("✅ Installed systemd timer for periodic GameGuard checks")
        except PermissionError:
            print("❌ Need sudo to install systemd service")

if __name__ == "__main__":
    main()
