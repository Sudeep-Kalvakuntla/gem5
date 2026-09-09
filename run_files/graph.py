import os
import re
import matplotlib.pyplot as plt
import pandas as pd

# List of folders shown in the image
folders = [
    "gem5_output_64bit_blackscholes",
    "gem5_output_64bit_bodytrack",
    "gem5_output_64bit_vips",
    "gem5_output_64bit_x264",
]

base_dir = r"D:"
output_dir = r"C:\Users\LENOVO\Desktop\NoC\outputs_simsmall"
os.makedirs(output_dir, exist_ok=True)

WARMUP_LIMIT = 30000

for folder in folders:
    # Extract benchmark name (strip prefix)
    benchmark_name = folder.replace("gem5_output_64bit_", "")
    log_path = os.path.join(base_dir, folder, "simulation.log")

    print(f"\nProcessing {benchmark_name} ({log_path})...")

    if not os.path.exists(log_path):
        print(f"File not found: {log_path}. Skipping.")
        continue

    before_probs = []
    after_probs = []

    pattern = re.compile(r"Before:\s*([0-9.]+),\s*After:\s*([0-9.]+)")

    with open(log_path, "r") as file:
        for line in file:
            match = pattern.search(line)
            if match:
                before_probs.append(float(match.group(1)))
                after_probs.append(float(match.group(2)))

    if not before_probs:
        print(f"No matching data found in {log_path}. Skipping.")
        continue

    df = pd.DataFrame(
        {
            "Packet Sequence": range(1, len(before_probs) + 1),
            "Before (%)": before_probs,
            "After (%)": after_probs,
        }
    )

    df["Pct Change (%)"] = (
        (df["Before (%)"] - df["After (%)"]) / df["Before (%)"]
    ) * 100

    df_filtered = df[df["Packet Sequence"] > WARMUP_LIMIT]

    if df_filtered.empty:
        print(
            f"Fewer than {WARMUP_LIMIT} packets found (total: {len(df)}). Skipping."
        )
        continue

    max_change_idx = df_filtered["Pct Change (%)"].idxmax()
    max_row = df.loc[max_change_idx]

    max_pct_change = max_row["Pct Change (%)"]
    max_seq = int(max_row["Packet Sequence"])
    max_before = max_row["Before (%)"]
    max_after = max_row["After (%)"]

    print(f"Total points: {len(df)} | Analyzed post-{WARMUP_LIMIT}: {len(df_filtered)}")
    print(
        f"Peak Reduction (>30k): {max_pct_change:.2f}% at Packet {max_seq} "
        f"(Before: {max_before:.4f}%, After: {max_after:.4f}%)"
    )

    # Subsample for rendering performance
    step = max(1, len(df) // 5000)
    df_sampled = df.iloc[::step]

    # Plot
    plt.figure(figsize=(10, 6))

    plt.plot(
        df_sampled["Packet Sequence"],
        df_sampled["Before (%)"],
        label="Sequential (Baseline)",
        color="#d62728",
        linewidth=2,
    )
    plt.plot(
        df_sampled["Packet Sequence"],
        df_sampled["After (%)"],
        label="Out of Order (Optimized)",
        color="#2ca02c",
        linewidth=2,
    )

    plt.axvline(
        x=WARMUP_LIMIT,
        color="gray",
        linestyle=":",
        linewidth=1.5,
        label="30k Packet Threshold",
    )

    plt.scatter([max_seq], [max_after], color="blue", s=80, zorder=5)

    annotation_text = (
        f"Max Reduction (>30k): {max_pct_change:.2f}%\n"
        f"Seq: {max_seq}\n"
        f"({max_before:.2f}% → {max_after:.2f}%)"
    )

    plt.annotate(
        annotation_text,
        xy=(max_seq, max_after),
        xytext=(max_seq, max_after + (max(before_probs) * 0.1)),
        arrowprops=dict(facecolor="black", shrink=0.08, width=1, headwidth=6),
        fontsize=10,
        fontweight="bold",
        bbox=dict(boxstyle="round,pad=0.4", fc="yellow", alpha=0.6, ec="black"),
    )

    plt.title(
        f"Switching Probability with PARSEC {benchmark_name.capitalize()} (Post-30k Packets)",
        fontsize=14,
        fontweight="bold",
    )
    plt.xlabel("Packets Processed", fontsize=12)
    plt.ylabel("Average Switching Probability (%)", fontsize=12)
    plt.legend(fontsize=12, loc="upper right")
    plt.grid(True, linestyle="--", alpha=0.6)

    output_file = os.path.join(output_dir, f"{benchmark_name}.png")
    plt.tight_layout()
    plt.savefig(output_file, dpi=300)
    plt.close()

    print(f"Saved: {output_file}")