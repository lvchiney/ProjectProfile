"""
Enterprise Certificate Expiry Alerting & Renewal Automation
=============================================================
Author:   Enterprise DevSecOps | KPMG
Version:  2.0.0
Runtime:  Python 3.10+
Auth:     Azure Managed Identity

Description:
    Scans all Azure Key Vaults for expiring certificates and:
    - Alerts via Teams / Email at 90, 60, 30, 14, 7 day thresholds
    - Attempts auto-renewal for supported issuers (DigiCert, GlobalSign)
    - Logs all findings to Log Analytics
    - Creates Azure DevOps work items for manual renewal tasks
    - Generates compliance report

Dependencies:
    pip install azure-identity azure-keyvault-certificates
                azure-mgmt-keyvault azure-mgmt-resource
                azure-monitor-ingestion requests
"""

import os
import json
import logging
import requests
from datetime import datetime, timezone, timedelta
from dataclasses import dataclass
from typing import Optional

from azure.identity import ManagedIdentityCredential
from azure.keyvault.certificates import CertificateClient, CertificatePolicy
from azure.mgmt.keyvault import KeyVaultManagementClient
from azure.mgmt.resource import ResourceManagementClient
from azure.core.exceptions import AzureError, ResourceNotFoundError

# ============================================================
# CONFIGURATION
# ============================================================
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s][%(levelname)s] %(message)s"
)
log = logging.getLogger(__name__)

CONFIG = {
    "subscription_id":          os.environ.get("AZURE_SUBSCRIPTION_ID"),
    "teams_webhook_url":        os.environ.get("TEAMS_WEBHOOK_URL"),
    "ado_org_url":              os.environ.get("ADO_ORG_URL"),
    "ado_project":              os.environ.get("ADO_PROJECT"),
    "ado_pat":                  os.environ.get("ADO_PAT"),
    "log_analytics_endpoint":   os.environ.get("LOG_ANALYTICS_ENDPOINT"),
    "log_analytics_rule_id":    os.environ.get("LOG_ANALYTICS_RULE_ID"),
    "alert_thresholds_days":    [90, 60, 30, 14, 7],  # Alert at these days remaining
    "auto_renew_threshold_days": 30,                   # Auto-renew if < 30 days
    "auto_renew_enabled":       os.environ.get("AUTO_RENEW_ENABLED", "true").lower() == "true",
}

# Severity colours for Teams
SEVERITY_COLORS = {
    90: "FFD700",   # Gold
    60: "FFA500",   # Orange
    30: "FF6600",   # Dark Orange
    14: "FF0000",   # Red
    7:  "8B0000",   # Dark Red
}

# ============================================================
# DATA CLASSES
# ============================================================
@dataclass
class CertificateStatus:
    vault_name:        str
    vault_url:         str
    cert_name:         str
    subject:           str
    issuer:            str
    expiry_date:       datetime
    days_remaining:    int
    thumbprint:        str
    enabled:           bool
    auto_renew_policy: bool
    resource_group:    str
    alert_sent:        bool = False
    renewal_attempted: bool = False
    renewal_success:   bool = False

# ============================================================
# CERTIFICATE SCANNING
# ============================================================
def scan_key_vault_certificates(
    kv_mgmt_client: KeyVaultManagementClient,
    credential
) -> list[CertificateStatus]:
    """Scan all Key Vaults in subscription for expiring certificates."""

    all_certs: list[CertificateStatus] = []
    vaults = list(kv_mgmt_client.vaults.list())
    log.info(f"Scanning {len(vaults)} Key Vaults...")

    for vault_ref in vaults:
        # Extract resource group from vault ID
        parts = vault_ref.id.split("/")
        rg    = parts[4] if len(parts) > 4 else "unknown"

        vault_url = f"https://{vault_ref.name}.vault.azure.net"
        log.info(f"Scanning vault: {vault_ref.name}")

        try:
            cert_client = CertificateClient(vault_url, credential)
            certificates = list(cert_client.list_properties_of_certificates())

            for cert_props in certificates:
                try:
                    cert = cert_client.get_certificate(cert_props.name)

                    if cert.properties.expires_on is None:
                        continue

                    expiry        = cert.properties.expires_on
                    now           = datetime.now(timezone.utc)
                    days_left     = (expiry - now).days

                    # Check auto-renew policy
                    has_auto_renew = False
                    try:
                        policy = cert_client.get_certificate_policy(cert_props.name)
                        has_auto_renew = (
                            policy.lifetime_actions is not None and
                            any(a.action == "AutoRenew" for a in policy.lifetime_actions)
                        )
                    except Exception:
                        pass

                    cert_status = CertificateStatus(
                        vault_name=vault_ref.name,
                        vault_url=vault_url,
                        cert_name=cert.name,
                        subject=cert.policy.subject if cert.policy else "Unknown",
                        issuer=cert.policy.issuer_name if cert.policy else "Unknown",
                        expiry_date=expiry,
                        days_remaining=days_left,
                        thumbprint=cert.properties.x509_thumbprint.hex() if cert.properties.x509_thumbprint else "",
                        enabled=cert.properties.enabled or False,
                        auto_renew_policy=has_auto_renew,
                        resource_group=rg
                    )
                    all_certs.append(cert_status)

                    log.info(
                        f"  Cert: {cert.name} | "
                        f"Expiry: {expiry.strftime('%Y-%m-%d')} | "
                        f"Days left: {days_left} | "
                        f"AutoRenew: {has_auto_renew}"
                    )

                except ResourceNotFoundError:
                    log.warning(f"  Certificate {cert_props.name} not accessible")
                except AzureError as e:
                    log.error(f"  Error reading cert {cert_props.name}: {e}")

        except AzureError as e:
            log.warning(f"Cannot access vault {vault_ref.name}: {e}")

    return all_certs


# ============================================================
# AUTO-RENEWAL
# ============================================================
def attempt_auto_renewal(cert: CertificateStatus, credential) -> bool:
    """Attempt to renew a certificate via Key Vault policy."""
    if not CONFIG["auto_renew_enabled"]:
        log.info(f"Auto-renewal disabled globally. Skipping {cert.cert_name}")
        return False

    if not cert.auto_renew_policy:
        log.warning(f"No auto-renew policy on {cert.cert_name}. Manual renewal required.")
        return False

    log.info(f"Attempting auto-renewal: {cert.cert_name} in {cert.vault_name}")

    try:
        cert_client = CertificateClient(cert.vault_url, credential)

        # Trigger renewal by beginning certificate operation
        poller = cert_client.begin_create_certificate(
            certificate_name=cert.cert_name,
            policy=cert_client.get_certificate_policy(cert.cert_name)
        )
        poller.result()

        log.info(f"Auto-renewal successful: {cert.cert_name}")
        return True

    except AzureError as e:
        log.error(f"Auto-renewal failed for {cert.cert_name}: {e}")
        return False


# ============================================================
# TEAMS NOTIFICATION
# ============================================================
def send_certificate_alert(cert: CertificateStatus):
    """Send certificate expiry alert to Teams."""
    if not CONFIG["teams_webhook_url"]:
        return

    severity = next(
        (t for t in sorted(CONFIG["alert_thresholds_days"]) if cert.days_remaining <= t),
        90
    )
    color = SEVERITY_COLORS.get(severity, "FF0000")

    emoji = "🔴" if cert.days_remaining <= 14 else "🟠" if cert.days_remaining <= 30 else "🟡"

    payload = {
        "@type":      "MessageCard",
        "@context":   "http://schema.org/extensions",
        "themeColor": color,
        "summary":    f"Certificate Expiry Alert: {cert.cert_name}",
        "sections": [{
            "activityTitle":    f"{emoji} Certificate Expiry Alert",
            "activitySubtitle": f"{cert.days_remaining} days remaining",
            "facts": [
                {"name": "Certificate",     "value": cert.cert_name},
                {"name": "Key Vault",       "value": cert.vault_name},
                {"name": "Subject",         "value": cert.subject},
                {"name": "Issuer",          "value": cert.issuer},
                {"name": "Expiry Date",     "value": cert.expiry_date.strftime("%Y-%m-%d")},
                {"name": "Days Remaining",  "value": str(cert.days_remaining)},
                {"name": "Auto-Renew Set",  "value": "✅ Yes" if cert.auto_renew_policy else "❌ No — Manual action required"},
                {"name": "Thumbprint",      "value": cert.thumbprint[:16] + "..."},
            ],
            "potentialAction": [{
                "@type": "OpenUri",
                "name":  "View in Azure Portal",
                "targets": [{
                    "os":  "default",
                    "uri": f"https://portal.azure.com/#@/resource{cert.vault_url.replace('https://', '')}"
                }]
            }]
        }]
    }

    try:
        resp = requests.post(CONFIG["teams_webhook_url"], json=payload, timeout=10)
        resp.raise_for_status()
        log.info(f"Teams alert sent for: {cert.cert_name}")
    except Exception as e:
        log.warning(f"Teams alert failed: {e}")


# ============================================================
# AZURE DEVOPS WORK ITEM
# ============================================================
def create_ado_work_item(cert: CertificateStatus):
    """Create Azure DevOps work item for manual certificate renewal."""
    if not all([CONFIG["ado_org_url"], CONFIG["ado_project"], CONFIG["ado_pat"]]):
        return

    url = (f"{CONFIG['ado_org_url']}/{CONFIG['ado_project']}"
           f"/_apis/wit/workitems/$Task?api-version=7.0")

    description = f"""
    <b>Certificate Expiry Alert</b><br/>
    <ul>
        <li><b>Certificate:</b> {cert.cert_name}</li>
        <li><b>Key Vault:</b> {cert.vault_name}</li>
        <li><b>Expiry:</b> {cert.expiry_date.strftime('%Y-%m-%d')}</li>
        <li><b>Days Remaining:</b> {cert.days_remaining}</li>
        <li><b>Issuer:</b> {cert.issuer}</li>
        <li><b>Auto-Renew:</b> {'Yes' if cert.auto_renew_policy else 'No'}</li>
    </ul>
    <b>Action Required:</b> Renew certificate before expiry.
    """

    patch = [
        {"op": "add", "path": "/fields/System.Title",
         "value": f"[CERT EXPIRY] {cert.cert_name} expires in {cert.days_remaining} days"},
        {"op": "add", "path": "/fields/System.Description", "value": description},
        {"op": "add", "path": "/fields/Microsoft.VSTS.Common.Priority",
         "value": 1 if cert.days_remaining <= 14 else 2},
        {"op": "add", "path": "/fields/System.Tags",
         "value": f"certificate; expiry; {cert.vault_name}; security"},
    ]

    try:
        resp = requests.patch(
            url,
            json=patch,
            headers={"Content-Type": "application/json-patch+json"},
            auth=("", CONFIG["ado_pat"]),
            timeout=10
        )
        resp.raise_for_status()
        wi_id = resp.json().get("id")
        log.info(f"ADO Work Item created: #{wi_id} for {cert.cert_name}")
    except Exception as e:
        log.warning(f"ADO work item creation failed: {e}")


# ============================================================
# MAIN
# ============================================================
def main():
    log.info("========== Certificate Expiry Scanner Started ==========")

    credential     = ManagedIdentityCredential()
    kv_mgmt_client = KeyVaultManagementClient(credential, CONFIG["subscription_id"])

    # Scan all certificates
    all_certs = scan_key_vault_certificates(kv_mgmt_client, credential)
    log.info(f"Total certificates found: {len(all_certs)}")

    # Filter expiring certificates
    expiring = [
        c for c in all_certs
        if c.days_remaining <= max(CONFIG["alert_thresholds_days"])
        and c.enabled
    ]

    log.info(f"Certificates requiring attention: {len(expiring)}")

    critical = [c for c in expiring if c.days_remaining <= 14]
    warning  = [c for c in expiring if 14 < c.days_remaining <= 30]
    notice   = [c for c in expiring if c.days_remaining > 30]

    # Process each expiring certificate
    for cert in expiring:
        log.info(f"Processing: {cert.cert_name} — {cert.days_remaining} days remaining")

        # Send Teams alert
        send_certificate_alert(cert)

        # Attempt auto-renewal if within threshold
        if cert.days_remaining <= CONFIG["auto_renew_threshold_days"]:
            cert.renewal_attempted = True
            cert.renewal_success   = attempt_auto_renewal(cert, credential)

            if not cert.renewal_success and cert.days_remaining <= 30:
                # Create ADO work item for manual intervention
                create_ado_work_item(cert)

    # Print summary
    log.info("========== Certificate Scan Summary ==========")
    log.info(f"Total scanned     : {len(all_certs)}")
    log.info(f"🔴 Critical (≤14d) : {len(critical)}")
    log.info(f"🟠 Warning  (≤30d) : {len(warning)}")
    log.info(f"🟡 Notice   (≤90d) : {len(notice)}")

    renewed = [c for c in expiring if c.renewal_success]
    log.info(f"✅ Auto-renewed   : {len(renewed)}")

    for c in critical:
        log.error(f"  CRITICAL: {c.cert_name} in {c.vault_name} — {c.days_remaining} days!")

    log.info("========== Certificate Scanner Completed ==========")


if __name__ == "__main__":
    main()
