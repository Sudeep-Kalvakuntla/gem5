import os
import re
import pandas as pd

# Benchmark list mapping benchmark names to their actual directory names in /mnt/d
BENCHMARK_DIRS = {
    "blackscholes": "gem5_output_64bit_blackscholes",
    "bodytrack": "gem5_output_64bit_bodytrack",
    "canneal": "gem5_output_64bit_canneal",
    "dedup": "gem5_output_64bit_dedup",
    "facesim": "gem5_output_64bit_facesim",
    "ferret": "gem5_output_64bit_ferret",
    "fluidanimate": "gem5_output_fluidanimate",  # named without '_64bit_' in /mnt/d
    "freqmine": "gem5_output_64bit_freqmine",
    "raytrace": "gem5_output_64bit_raytrace",
    "streamcluster": "gem5_output_64bit_streamcluster",
    "swaptions": "gem5_output_64bit_swaptions",
    "vips": "gem5_output_64bit_vips",
    "x264": "gem5_output_64bit_x264"
}

BASE_DIR = "/mnt/d"
WARMUP_LIMIT = 30000
OUTPUT_CSV = "benchmark_summary.csv"

summary_data = []

for bench, folder_name in BENCHMARK_DIRS.items():
    log_path = os.path.join(BASE_DIR, folder_name, "simulation.log")
    
    if not os.path.isfile(log_path):
        print(f"Warning: File not found at '{log_path}'. Skipping.")
        continue

    before_probs = []
    after_probs = []

    with open(log_path, "r", encoding="utf-8", errors="ignore") as file:
        for line in file:
            match = re.search(r"Before:\s*([0-9.]+),\s*After:\s*([0-9.]+)", line)
            if match:
                before_probs.append(float(match.group(1)))
                after_probs.append(float(match.group(2)))

    total_packets = len(before_probs)
    if total_packets == 0:
        print(f"Warning: No valid entries found in '{log_path}'. Skipping.")
        continue

    df = pd.DataFrame({
        "Packet Sequence": range(1, total_packets + 1),
        "Before (%)": before_probs,
        "After (%)": after_probs
    })

    # Relative percentage reduction: ((Before - After) / Before) * 100
    df["Pct Change (%)"] = ((df["Before (%)"] - df["After (%)"]) / df["Before (%)"]) * 100

    df_post_warmup = df[df["Packet Sequence"] > WARMUP_LIMIT]

    if not df_post_warmup.empty:
        max_idx = df_post_warmup["Pct Change (%)"].idxmax()
        max_row = df.loc[max_idx]
        
        avg_reduction = df_post_warmup["Pct Change (%)"].mean()
        max_reduction = max_row["Pct Change (%)"]
        max_packet_num = int(max_row["Packet Sequence"])
    else:
        avg_reduction = None
        max_reduction = None
        max_packet_num = None

    summary_data.append({
        "benchmark name": bench,
        "simulation size": "simsmall",
        "total packets simulated": total_packets,
        "average switching probability reduction": round(avg_reduction, 4) if avg_reduction is not None else "N/A",
        "max switching probability reduction": round(max_reduction, 4) if max_reduction is not None else "N/A",
        "max switch probability packet number": max_packet_num if max_packet_num is not None else "N/A",
        "max switch probability being tested after what packet": WARMUP_LIMIT
    })

summary_df = pd.DataFrame(summary_data)
summary_df.to_csv(OUTPUT_CSV, index=False)

print(f"Processed {len(summary_data)} benchmarks. Output written to '{OUTPUT_CSV}'.")