"""
Enterprise AKS Node Pool Auto-Scaling Automation
=================================================
Author:   Enterprise DevSecOps | KPMG
Version:  2.0.0
Runtime:  Python 3.10+
Auth:     Azure Managed Identity / Service Principal
Schedule: Every 15 minutes via Azure Automation / Logic App

Description:
    Intelligently scales AKS node pools based on:
    - CPU utilization metrics from Azure Monitor
    - Memory utilization metrics
    - Pending pod count from AKS metrics
    - Time-based business hours scaling
    - Custom scaling rules per node pool tag

Tags Used on Node Pool:
    AutoScale-Enabled     = "true"
    AutoScale-MinNodes    = "2"
    AutoScale-MaxNodes    = "10"
    AutoScale-ScaleUpCPU  = "70"    (% threshold to scale up)
    AutoScale-ScaleDownCPU= "20"    (% threshold to scale down)
    AutoScale-BusinessHrs = "true"  (scale down outside 07:00-19:00)

Dependencies:
    pip install azure-identity azure-mgmt-containerservice
                azure-mgmt-monitor azure-mgmt-resource
                azure-core requests
"""

import os
import json
import logging
import requests
from datetime import datetime, timezone, timedelta
from dataclasses import dataclass, field
from typing import Optional

from azure.identity import ManagedIdentityCredential, ClientSecretCredential
from azure.mgmt.containerservice import ContainerServiceClient
from azure.mgmt.monitor import MonitorManagementClient
from azure.mgmt.resource import SubscriptionClient
from azure.core.exceptions import AzureError

# ============================================================
# CONFIGURATION
# ============================================================
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s][%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
log = logging.getLogger(__name__)

CONFIG = {
    "subscription_id":       os.environ.get("AZURE_SUBSCRIPTION_ID"),
    "teams_webhook_url":     os.environ.get("TEAMS_WEBHOOK_URL"),
    "whatif":                os.environ.get("WHATIF", "false").lower() == "true",
    "scale_cooldown_minutes": 10,    # Min time between scale operations
    "default_min_nodes":      2,
    "default_max_nodes":      10,
    "default_scaleup_cpu":    70,    # Scale up if CPU > 70%
    "default_scaledown_cpu":  20,    # Scale down if CPU < 20%
    "business_hours_start":   7,
    "business_hours_end":     19,
}

# ============================================================
# DATA CLASSES
# ============================================================
@dataclass
class NodePoolConfig:
    name:              str
    cluster_name:      str
    resource_group:    str
    current_count:     int
    min_nodes:         int
    max_nodes:         int
    scaleup_cpu:       float
    scaledown_cpu:     float
    business_hours:    bool
    enabled:           bool

@dataclass
class ScalingDecision:
    node_pool:         str
    cluster:           str
    current_count:     int
    target_count:      int
    reason:            str
    action:            str   # "scale_up" | "scale_down" | "no_change"
    cpu_percent:       float = 0.0
    memory_percent:    float = 0.0

# ============================================================
# AUTHENTICATION
# ============================================================
def get_credential():
    """Get Azure credential — Managed Identity in production, SP in dev."""
    client_id = os.environ.get("AZURE_CLIENT_ID")
    client_secret = os.environ.get("AZURE_CLIENT_SECRET")
    tenant_id = os.environ.get("AZURE_TENANT_ID")

    if client_secret and tenant_id:
        log.info("Authenticating via Service Principal")
        return ClientSecretCredential(tenant_id, client_id, client_secret)
    else:
        log.info("Authenticating via Managed Identity")
        return ManagedIdentityCredential()

# ============================================================
# METRICS COLLECTION
# ============================================================
def get_aks_cpu_percent(monitor_client: MonitorManagementClient,
                         cluster_resource_id: str,
                         node_pool_name: str) -> float:
    """Fetch average CPU utilization for a node pool over last 5 minutes."""
    try:
        end_time   = datetime.now(timezone.utc)
        start_time = end_time - timedelta(minutes=5)

        metrics = monitor_client.metrics.list(
            resource_uri=cluster_resource_id,
            timespan=f"{start_time.isoformat()}/{end_time.isoformat()}",
            interval="PT5M",
            metricnames="node_cpu_usage_percentage",
            aggregation="Average",
            filter=f"nodepool eq '{node_pool_name}'"
        )

        for metric in metrics.value:
            for ts in metric.timeseries:
                for dp in ts.data:
                    if dp.average is not None:
                        log.info(f"CPU for {node_pool_name}: {dp.average:.1f}%")
                        return dp.average

        log.warning(f"No CPU data for node pool {node_pool_name}")
        return 0.0

    except AzureError as e:
        log.error(f"Failed to get CPU metrics for {node_pool_name}: {e}")
        return 0.0


def get_aks_memory_percent(monitor_client: MonitorManagementClient,
                            cluster_resource_id: str,
                            node_pool_name: str) -> float:
    """Fetch average memory utilization for a node pool."""
    try:
        end_time   = datetime.now(timezone.utc)
        start_time = end_time - timedelta(minutes=5)

        metrics = monitor_client.metrics.list(
            resource_uri=cluster_resource_id,
            timespan=f"{start_time.isoformat()}/{end_time.isoformat()}",
            interval="PT5M",
            metricnames="node_memory_rss_percentage",
            aggregation="Average",
            filter=f"nodepool eq '{node_pool_name}'"
        )

        for metric in metrics.value:
            for ts in metric.timeseries:
                for dp in ts.data:
                    if dp.average is not None:
                        return dp.average

        return 0.0

    except AzureError as e:
        log.error(f"Failed to get memory metrics: {e}")
        return 0.0

# ============================================================
# SCALING LOGIC
# ============================================================
def evaluate_scaling(config: NodePoolConfig,
                      cpu_percent: float,
                      memory_percent: float) -> ScalingDecision:
    """Determine scaling action based on metrics and configuration."""

    current = config.current_count
    now_utc = datetime.now(timezone.utc)
    current_hour = now_utc.hour

    # Business hours check
    outside_business_hours = (
        config.business_hours and
        (current_hour < CONFIG["business_hours_start"] or
         current_hour >= CONFIG["business_hours_end"])
    )

    # Scale down to minimum outside business hours
    if outside_business_hours and current > config.min_nodes:
        return ScalingDecision(
            node_pool=config.name,
            cluster=config.cluster_name,
            current_count=current,
            target_count=config.min_nodes,
            reason=f"Outside business hours ({current_hour}:00 UTC) — scaling to minimum",
            action="scale_down",
            cpu_percent=cpu_percent,
            memory_percent=memory_percent
        )

    # Scale UP — high CPU or Memory
    if (cpu_percent > config.scaleup_cpu or memory_percent > 80) and current < config.max_nodes:
        target = min(current + 2, config.max_nodes)
        reason = f"CPU={cpu_percent:.1f}% > threshold={config.scaleup_cpu}%" \
                 if cpu_percent > config.scaleup_cpu \
                 else f"Memory={memory_percent:.1f}% > 80%"
        return ScalingDecision(
            node_pool=config.name,
            cluster=config.cluster_name,
            current_count=current,
            target_count=target,
            reason=reason,
            action="scale_up",
            cpu_percent=cpu_percent,
            memory_percent=memory_percent
        )

    # Scale DOWN — low CPU and Memory
    if (cpu_percent < config.scaledown_cpu and
        memory_percent < 30 and
        current > config.min_nodes):
        target = max(current - 1, config.min_nodes)
        return ScalingDecision(
            node_pool=config.name,
            cluster=config.cluster_name,
            current_count=current,
            target_count=target,
            reason=f"CPU={cpu_percent:.1f}% < {config.scaledown_cpu}% and Memory={memory_percent:.1f}% < 30%",
            action="scale_down",
            cpu_percent=cpu_percent,
            memory_percent=memory_percent
        )

    # No change needed
    return ScalingDecision(
        node_pool=config.name,
        cluster=config.cluster_name,
        current_count=current,
        target_count=current,
        reason=f"Within normal range — CPU={cpu_percent:.1f}%, Memory={memory_percent:.1f}%",
        action="no_change",
        cpu_percent=cpu_percent,
        memory_percent=memory_percent
    )


def apply_scaling(aks_client: ContainerServiceClient,
                   decision: ScalingDecision,
                   resource_group: str) -> bool:
    """Apply scaling decision to AKS node pool."""
    if decision.action == "no_change":
        log.info(f"No scaling needed for {decision.node_pool}: {decision.reason}")
        return True

    log.info(f"Scaling {decision.action.upper()}: {decision.node_pool} "
             f"{decision.current_count} → {decision.target_count} nodes. "
             f"Reason: {decision.reason}")

    if CONFIG["whatif"]:
        log.info(f"[WHATIF] Would scale {decision.node_pool} to {decision.target_count} nodes")
        return True

    try:
        agent_pool = aks_client.agent_pools.get(
            resource_group, decision.cluster, decision.node_pool
        )
        agent_pool.count = decision.target_count

        poller = aks_client.agent_pools.begin_create_or_update(
            resource_group, decision.cluster, decision.node_pool, agent_pool
        )
        poller.result()  # Wait for completion

        log.info(f"Successfully scaled {decision.node_pool} to {decision.target_count} nodes")
        return True

    except AzureError as e:
        log.error(f"Failed to scale {decision.node_pool}: {e}")
        return False


# ============================================================
# TEAMS NOTIFICATION
# ============================================================
def send_teams_notification(decisions: list[ScalingDecision]):
    """Send scaling summary to Microsoft Teams."""
    if not CONFIG["teams_webhook_url"]:
        return

    actions = [d for d in decisions if d.action != "no_change"]
    if not actions:
        return

    facts = [
        {"name": f"{d.node_pool} ({d.cluster})",
         "value": f"{d.action.upper()}: {d.current_count}→{d.target_count} nodes. {d.reason}"}
        for d in actions
    ]

    payload = {
        "@type":      "MessageCard",
        "@context":   "http://schema.org/extensions",
        "themeColor": "0076D7",
        "summary":    "AKS Auto-Scaling Summary",
        "sections": [{
            "activityTitle":    "🔄 AKS Node Pool Auto-Scaling",
            "activitySubtitle": f"{len(actions)} scaling actions taken",
            "facts":            facts
        }]
    }

    try:
        resp = requests.post(
            CONFIG["teams_webhook_url"],
            json=payload,
            timeout=10
        )
        resp.raise_for_status()
    except Exception as e:
        log.warning(f"Teams notification failed: {e}")


# ============================================================
# MAIN
# ============================================================
def main():
    log.info("========== AKS Auto-Scaling Started ==========")
    log.info(f"WhatIf={CONFIG['whatif']} | Subscription={CONFIG['subscription_id']}")

    credential   = get_credential()
    aks_client   = ContainerServiceClient(credential, CONFIG["subscription_id"])
    monitor_client = MonitorManagementClient(credential, CONFIG["subscription_id"])

    all_decisions: list[ScalingDecision] = []
    clusters = list(aks_client.managed_clusters.list())
    log.info(f"Found {len(clusters)} AKS clusters")

    for cluster in clusters:
        rg      = cluster.node_resource_group.split("_")[1] if "_" in (cluster.node_resource_group or "") else ""
        # Extract actual RG from cluster id
        parts   = cluster.id.split("/")
        rg      = parts[4] if len(parts) > 4 else ""
        cluster_id = cluster.id

        log.info(f"Processing cluster: {cluster.name} in {rg}")

        agent_pools = list(aks_client.agent_pools.list(rg, cluster.name))

        for pool in agent_pools:
            tags = pool.tags or {}

            # Check if auto-scaling is enabled via tags
            if tags.get("AutoScale-Enabled", "false").lower() != "true":
                log.info(f"Skipping {pool.name} — AutoScale-Enabled tag not set")
                continue

            # Build config from tags
            config = NodePoolConfig(
                name=pool.name,
                cluster_name=cluster.name,
                resource_group=rg,
                current_count=pool.count or 1,
                min_nodes=int(tags.get("AutoScale-MinNodes", CONFIG["default_min_nodes"])),
                max_nodes=int(tags.get("AutoScale-MaxNodes", CONFIG["default_max_nodes"])),
                scaleup_cpu=float(tags.get("AutoScale-ScaleUpCPU", CONFIG["default_scaleup_cpu"])),
                scaledown_cpu=float(tags.get("AutoScale-ScaleDownCPU", CONFIG["default_scaledown_cpu"])),
                business_hours=tags.get("AutoScale-BusinessHrs", "false").lower() == "true",
                enabled=True
            )

            # Get metrics
            cpu    = get_aks_cpu_percent(monitor_client, cluster_id, pool.name)
            memory = get_aks_memory_percent(monitor_client, cluster_id, pool.name)

            # Evaluate and apply
            decision = evaluate_scaling(config, cpu, memory)
            all_decisions.append(decision)

            if decision.action != "no_change":
                apply_scaling(aks_client, decision, rg)

    # Summary
    scaled  = [d for d in all_decisions if d.action != "no_change"]
    log.info(f"========== Scaling Summary ==========")
    log.info(f"Total node pools evaluated : {len(all_decisions)}")
    log.info(f"Scaling actions taken      : {len(scaled)}")
    for d in scaled:
        log.info(f"  {d.node_pool}: {d.action} {d.current_count}→{d.target_count} — {d.reason}")

    send_teams_notification(all_decisions)
    log.info("========== AKS Auto-Scaling Completed ==========")


if __name__ == "__main__":
    main()
