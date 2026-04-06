from __future__ import annotations

import math
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np


ROOT = Path(__file__).resolve().parent
FIG_DIR = ROOT / "figures"


COLORS = {
    "ink": "#102A43",
    "muted": "#7B8794",
    "grid": "#D9E2EC",
    "navy": "#143D59",
    "teal": "#1A7F8E",
    "gold": "#F0B429",
    "coral": "#E76F51",
    "slate": "#52606D",
    "fog": "#F5F7FA",
    "ice": "#E6FFFA",
    "rose": "#FFF1F2",
}


def configure_matplotlib() -> None:
    plt.rcParams.update(
        {
            "figure.facecolor": "white",
            "axes.facecolor": "white",
            "savefig.facecolor": "white",
            "font.family": "DejaVu Sans",
            "font.size": 11,
            "axes.titlesize": 18,
            "axes.titleweight": "bold",
            "axes.labelsize": 12,
            "axes.edgecolor": COLORS["grid"],
            "axes.labelcolor": COLORS["ink"],
            "axes.spines.top": False,
            "axes.spines.right": False,
            "axes.grid": True,
            "grid.color": COLORS["grid"],
            "grid.alpha": 0.85,
            "grid.linestyle": "-",
            "xtick.color": COLORS["slate"],
            "ytick.color": COLORS["slate"],
            "text.color": COLORS["ink"],
            "legend.frameon": False,
            "legend.fontsize": 10,
            "svg.fonttype": "none",
        }
    )


def half_life_alpha(days: float) -> float:
    return 1.0 - math.exp(-math.log(2.0) / days)


def ema(values: np.ndarray, alpha: float) -> np.ndarray:
    smoothed = np.empty_like(values, dtype=float)
    smoothed[0] = values[0]
    for i in range(1, len(values)):
        smoothed[i] = alpha * values[i] + (1.0 - alpha) * smoothed[i - 1]
    return smoothed


def add_title(fig: plt.Figure, title: str, subtitle: str) -> None:
    fig.suptitle(title, x=0.065, y=0.98, ha="left", color=COLORS["ink"])
    fig.text(0.065, 0.935, subtitle, ha="left", va="top", color=COLORS["slate"])


def save_figure(fig: plt.Figure, name: str) -> None:
    FIG_DIR.mkdir(parents=True, exist_ok=True)
    fig.savefig(FIG_DIR / f"{name}.svg", bbox_inches="tight")
    plt.close(fig)


def plot_weight_smoothing() -> None:
    rng = np.random.default_rng(7)
    days = np.arange(60)

    true_trend = 82.4 - 0.047 * days + 0.10 * np.sin(days / 17.0)
    water = 0.75 * np.sin(2 * np.pi * days / 7.0 + 0.6)
    slow_shift = 0.22 * np.sin(2 * np.pi * days / 15.0)
    noise = rng.normal(0.0, 0.14, size=days.size)
    scale = true_trend + water + slow_shift + noise
    estimated_trend = ema(scale, half_life_alpha(7))

    fig, ax = plt.subplots(figsize=(11.5, 6.4), constrained_layout=False)
    add_title(
        fig,
        "Trend Weight Is a State Estimate",
        "Daily scale weight oscillates around the slower tissue-change signal the controller actually needs.",
    )

    ax.plot(days, scale, color=COLORS["muted"], lw=1.4, alpha=0.55, zorder=1)
    ax.scatter(
        days,
        scale,
        s=36,
        color="white",
        edgecolor=COLORS["muted"],
        linewidth=1.2,
        alpha=0.95,
        label="Measured scale weight",
        zorder=2,
    )
    ax.plot(
        days,
        true_trend,
        color=COLORS["gold"],
        lw=2.4,
        ls=(0, (6, 4)),
        label="Underlying body-mass trend",
        zorder=3,
    )
    ax.plot(
        days,
        estimated_trend,
        color=COLORS["teal"],
        lw=3.2,
        label="Estimated trend weight (EMA, 7-day half-life)",
        zorder=4,
    )

    ax.fill_between(days, scale, estimated_trend, color=COLORS["fog"], alpha=0.65, zorder=0)
    ax.set_xlabel("Day")
    ax.set_ylabel("Body weight (kg)")
    ax.set_xlim(days.min(), days.max())
    ax.set_ylim(scale.min() - 0.55, scale.max() + 0.55)
    ax.legend(loc="upper right", ncol=1)

    ax.annotate(
        "Short-term swings are mostly water and timing noise",
        xy=(18, scale[18]),
        xytext=(5, scale.max() + 0.2),
        arrowprops=dict(arrowstyle="->", lw=1.2, color=COLORS["slate"]),
        color=COLORS["ink"],
        fontsize=10,
        bbox=dict(boxstyle="round,pad=0.35", fc="white", ec=COLORS["grid"]),
    )
    ax.annotate(
        "The controller should react to this slower state instead",
        xy=(42, estimated_trend[42]),
        xytext=(31, scale.min() - 0.25),
        arrowprops=dict(arrowstyle="->", lw=1.2, color=COLORS["teal"]),
        color=COLORS["ink"],
        fontsize=10,
        bbox=dict(boxstyle="round,pad=0.35", fc="white", ec=COLORS["grid"]),
    )

    save_figure(fig, "adaptive_control_weight_smoothing")


def plot_expenditure_observer() -> None:
    rng = np.random.default_rng(19)
    days = np.arange(90)

    true_expenditure = 2730 - 1.7 * days + 55 * np.sin(2 * np.pi * days / 48.0 + 0.4)
    target_intake = np.piecewise(
        days,
        [days < 30, (days >= 30) & (days < 60), days >= 60],
        [2250, 2175, 2100],
    ).astype(float)
    adherence = 95 * np.sin(2 * np.pi * days / 10.0 + 0.8) + rng.normal(0, 65, size=days.size)
    actual_intake = target_intake + adherence

    true_weight = np.empty(days.size)
    true_weight[0] = 84.1
    for k in range(days.size - 1):
        disturbance = rng.normal(0.0, 0.012)
        true_weight[k + 1] = true_weight[k] + (actual_intake[k] - true_expenditure[k]) / 7700.0 + disturbance

    scale_weight = true_weight + 0.65 * np.sin(2 * np.pi * days / 7.0 + 1.1) + rng.normal(0, 0.11, size=days.size)
    trend_weight = ema(scale_weight, half_life_alpha(7))

    raw_expenditure = np.full(days.size, np.nan)
    window = 21
    for k in range(window, days.size):
        avg_intake = np.mean(actual_intake[k - window + 1 : k + 1])
        delta_trend = trend_weight[k] - trend_weight[k - window]
        raw_expenditure[k] = avg_intake - 7700.0 * delta_trend / window

    estimated_expenditure = np.empty(days.size)
    estimated_expenditure[0] = 2700.0
    beta = half_life_alpha(14)
    for k in range(1, days.size):
        if np.isnan(raw_expenditure[k]):
            estimated_expenditure[k] = estimated_expenditure[k - 1]
        else:
            estimated_expenditure[k] = beta * raw_expenditure[k] + (1.0 - beta) * estimated_expenditure[k - 1]

    fig, ax = plt.subplots(figsize=(11.5, 6.4), constrained_layout=False)
    add_title(
        fig,
        "The Expenditure Observer Tracks a Hidden State",
        "A rolling energy-balance estimate is still noisy, so the observer smooths it before the controller uses it.",
    )

    ax.axvspan(0, window, color=COLORS["fog"], alpha=0.9, label="Seed / insufficient-data period")
    ax.plot(
        days,
        true_expenditure,
        color=COLORS["navy"],
        lw=2.5,
        ls=(0, (7, 4)),
        label="True expenditure (hidden state)",
        zorder=3,
    )
    ax.plot(
        days,
        raw_expenditure,
        color=COLORS["coral"],
        lw=1.6,
        alpha=0.35,
        label="Raw 21-day expenditure inference",
        zorder=2,
    )
    ax.plot(
        days,
        estimated_expenditure,
        color=COLORS["teal"],
        lw=3.2,
        label="Observer estimate used by controller",
        zorder=4,
    )

    ax.set_xlabel("Day")
    ax.set_ylabel("Energy expenditure (kcal/day)")
    ax.set_xlim(days.min(), days.max())
    ax.set_ylim(2400, 2825)
    ax.legend(loc="upper right")

    ax.annotate(
        "Before enough data exists,\nuse the onboarding TDEE seed",
        xy=(10, estimated_expenditure[10]),
        xytext=(18, 2790),
        arrowprops=dict(arrowstyle="->", lw=1.2, color=COLORS["slate"]),
        fontsize=10,
        bbox=dict(boxstyle="round,pad=0.35", fc="white", ec=COLORS["grid"]),
    )
    ax.annotate(
        "The smoothed estimate follows the real drift\nwithout chasing every temporary fluctuation",
        xy=(63, estimated_expenditure[63]),
        xytext=(46, 2455),
        arrowprops=dict(arrowstyle="->", lw=1.2, color=COLORS["teal"]),
        fontsize=10,
        bbox=dict(boxstyle="round,pad=0.35", fc="white", ec=COLORS["grid"]),
    )

    save_figure(fig, "adaptive_control_expenditure_observer")


def plot_rate_limited_controller() -> None:
    weeks = np.arange(1, 13)
    proposed = np.array([2250, 2235, 2215, 1910, 1885, 2210, 2230, 2205, 2170, 2145, 2120, 2100], dtype=float)

    applied = np.empty_like(proposed)
    applied[0] = proposed[0]
    max_step = 120.0
    for i in range(1, proposed.size):
        delta = proposed[i] - applied[i - 1]
        applied[i] = applied[i - 1] + np.clip(delta, -max_step, max_step)

    fig, ax = plt.subplots(figsize=(11.2, 6.0), constrained_layout=False)
    add_title(
        fig,
        "Weekly Rate Limits Prevent a Calorie Roller Coaster",
        "Temporary stalls can imply large corrections, but a slow controller should move only part of the way each week.",
    )

    ax.axvspan(3.5, 5.5, color=COLORS["rose"], alpha=0.95)
    ax.plot(
        weeks,
        proposed,
        color=COLORS["coral"],
        lw=2.2,
        marker="o",
        ms=6.5,
        label="Naive full correction",
        zorder=3,
    )
    ax.plot(
        weeks,
        applied,
        color=COLORS["teal"],
        lw=3.2,
        marker="o",
        ms=6.5,
        label="Rate-limited weekly target",
        zorder=4,
    )
    ax.hlines(proposed[0], 1, weeks.max(), color=COLORS["grid"], lw=1.0)

    ax.set_xlabel("Weekly check-in")
    ax.set_ylabel("Recommended calorie target (kcal/day)")
    ax.set_xlim(1, weeks.max())
    ax.set_ylim(1840, 2290)
    ax.set_xticks(weeks)
    ax.legend(loc="lower left")

    ax.annotate(
        "A noisy plateau makes the full-correction target dive",
        xy=(4, proposed[3]),
        xytext=(1.3, 1880),
        arrowprops=dict(arrowstyle="->", lw=1.2, color=COLORS["coral"]),
        fontsize=10,
        bbox=dict(boxstyle="round,pad=0.35", fc="white", ec=COLORS["grid"]),
    )
    ax.annotate(
        "The rate limit keeps the loop stable\nand easier for humans to follow",
        xy=(6, applied[5]),
        xytext=(7.2, 2260),
        arrowprops=dict(arrowstyle="->", lw=1.2, color=COLORS["teal"]),
        fontsize=10,
        bbox=dict(boxstyle="round,pad=0.35", fc="white", ec=COLORS["grid"]),
    )

    save_figure(fig, "adaptive_control_rate_limited_controller")


def plot_maintenance_deadband() -> None:
    deviation = np.linspace(-2.5, 2.5, 400)
    target_weight = 80.0
    band = 0.68
    nudge_rate = 0.15 / 100.0
    correction = np.zeros_like(deviation)
    correction[deviation < -band] = 7700.0 * (target_weight * nudge_rate) / 7.0
    correction[deviation > band] = -7700.0 * (target_weight * nudge_rate) / 7.0

    fig, ax = plt.subplots(figsize=(10.8, 5.7), constrained_layout=False)
    add_title(
        fig,
        "Maintenance Should Use a Deadband",
        "Inside the band, the controller does nothing. Outside the band, it applies a small nudge instead of chasing exact regulation.",
    )

    ax.axvspan(-band, band, color=COLORS["fog"], alpha=1.0, label="Maintenance band")
    ax.plot(deviation, correction, color=COLORS["navy"], lw=3.0)
    ax.axhline(0, color=COLORS["grid"], lw=1.1)
    ax.axvline(0, color=COLORS["grid"], lw=1.1)

    ax.set_xlabel("Trend-weight deviation from target (kg)")
    ax.set_ylabel("Calorie correction (kcal/day)")
    ax.set_xlim(deviation.min(), deviation.max())
    ax.set_ylim(-165, 165)
    ax.legend(loc="upper right")

    ax.annotate(
        "Below target: apply a small surplus",
        xy=(-1.5, correction[deviation < -band][0]),
        xytext=(-2.35, 115),
        arrowprops=dict(arrowstyle="->", lw=1.2, color=COLORS["navy"]),
        fontsize=10,
        bbox=dict(boxstyle="round,pad=0.35", fc="white", ec=COLORS["grid"]),
    )
    ax.annotate(
        "Inside the deadband: zero correction",
        xy=(0.0, 0.0),
        xytext=(-0.55, -110),
        arrowprops=dict(arrowstyle="->", lw=1.2, color=COLORS["slate"]),
        fontsize=10,
        bbox=dict(boxstyle="round,pad=0.35", fc="white", ec=COLORS["grid"]),
    )
    ax.annotate(
        "Above target: apply a small deficit",
        xy=(1.45, correction[deviation > band][0]),
        xytext=(0.7, -140),
        arrowprops=dict(arrowstyle="->", lw=1.2, color=COLORS["navy"]),
        fontsize=10,
        bbox=dict(boxstyle="round,pad=0.35", fc="white", ec=COLORS["grid"]),
    )

    save_figure(fig, "adaptive_control_maintenance_deadband")


def main() -> None:
    configure_matplotlib()
    plot_weight_smoothing()
    plot_expenditure_observer()
    plot_rate_limited_controller()
    plot_maintenance_deadband()
    print(f"Wrote figures to {FIG_DIR}")


if __name__ == "__main__":
    main()
