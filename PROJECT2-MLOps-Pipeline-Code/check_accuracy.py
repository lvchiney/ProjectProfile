"""
check_accuracy.py — MLOps Quality Gate
Fails the pipeline (exit code 1) if model accuracy < threshold.
"""

import argparse
import sys
from azure.ai.ml import MLClient
from azure.identity import DefaultAzureCredential


def check_accuracy(workspace: str, resource_group: str, threshold: float) -> None:
    credential = MLClient(
        credential=DefaultAzureCredential(),
        subscription_id=None,   # picked up from az login context
        resource_group_name=resource_group,
        workspace_name=workspace,
    )

    # Get the latest completed training job
    jobs = list(credential.jobs.list(tag="latest_run=true"))
    if not jobs:
        print("❌ No completed training jobs found.")
        sys.exit(1)

    latest_job = jobs[0]
    metrics = latest_job.properties.get("metrics", {})
    accuracy = float(metrics.get("accuracy", 0.0))

    print(f"📊 Model accuracy:  {accuracy:.4f}")
    print(f"📏 Threshold:       {threshold:.4f}")

    if accuracy < threshold:
        print(f"❌ QUALITY GATE FAILED — accuracy {accuracy:.4f} < threshold {threshold:.4f}")
        print("🚫 Model will NOT be deployed to staging.")
        sys.exit(1)   # Non-zero exit fails the pipeline stage

    print(f"✅ QUALITY GATE PASSED — accuracy {accuracy:.4f} >= threshold {threshold:.4f}")
    print("🚀 Proceeding to staging deployment.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace",       required=True)
    parser.add_argument("--resource-group",  required=True)
    parser.add_argument("--threshold",       type=float, default=0.85)
    args = parser.parse_args()

    check_accuracy(args.workspace, args.resource_group, args.threshold)
