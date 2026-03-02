"""
validate_data.py — Training Data Quality Checks
Uses Great Expectations to validate schema and data quality
before submitting to Azure ML training job.
"""

import argparse
import sys
import pandas as pd
from azure.storage.blob import BlobServiceClient
from azure.identity import DefaultAzureCredential
import io


def validate_data(storage_account: str, container: str) -> None:
    print("🔍 Connecting to Azure Blob Storage...")

    credential  = DefaultAzureCredential()
    account_url = f"https://{storage_account}.blob.core.windows.net"
    client      = BlobServiceClient(account_url=account_url, credential=credential)

    # Download latest training data file
    container_client = client.get_container_client(container)
    blobs = sorted(
        container_client.list_blobs(),
        key=lambda b: b.last_modified,
        reverse=True
    )

    if not blobs:
        print("❌ No training data found in blob container.")
        sys.exit(1)

    latest_blob = blobs[0]
    print(f"📁 Validating: {latest_blob.name}")

    blob_data = container_client.download_blob(latest_blob.name).readall()
    df = pd.read_csv(io.BytesIO(blob_data))

    # ─── Validation Checks ───────────────────────────────────
    errors = []

    # 1. Required columns present
    required_columns = ["feature_1", "feature_2", "feature_3", "label"]
    missing_cols = [c for c in required_columns if c not in df.columns]
    if missing_cols:
        errors.append(f"Missing required columns: {missing_cols}")

    # 2. No empty dataframe
    if len(df) == 0:
        errors.append("Training data file is empty.")

    # 3. Minimum row count
    if len(df) < 100:
        errors.append(f"Too few rows: {len(df)} (minimum: 100)")

    # 4. No nulls in label column
    if "label" in df.columns and df["label"].isnull().sum() > 0:
        null_count = df["label"].isnull().sum()
        errors.append(f"Null values in label column: {null_count} rows")

    # 5. Label column has expected values
    if "label" in df.columns:
        unique_labels = df["label"].unique().tolist()
        expected_labels = [0, 1]
        unexpected = [l for l in unique_labels if l not in expected_labels]
        if unexpected:
            errors.append(f"Unexpected label values: {unexpected}")

    # ─── Results ─────────────────────────────────────────────
    print(f"\n📊 Rows:    {len(df)}")
    print(f"📊 Columns: {list(df.columns)}")

    if errors:
        print("\n❌ DATA VALIDATION FAILED:")
        for e in errors:
            print(f"   • {e}")
        sys.exit(1)

    print("\n✅ DATA VALIDATION PASSED — all checks passed.")
    print("🚀 Proceeding to Azure ML training job.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--storage-account", required=True)
    parser.add_argument("--container",        required=True)
    args = parser.parse_args()

    validate_data(args.storage_account, args.container)
