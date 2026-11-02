#!/usr/bin/env python3
"""docs/architecture.png 생성 스크립트.

미션 요구: VPC, Subnet, Internet Gateway, EC2, Security Group 구성 요소와
외부 -> 서비스 트래픽 흐름이 표현되어야 한다.

실행:  python3 scripts/make_architecture_diagram.py
의존:  matplotlib (pip install matplotlib)
"""
from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch  # noqa: E402

OUTPUT = Path(__file__).resolve().parent.parent / "docs" / "architecture.png"

# 한글 폰트: macOS/Windows/Linux 순서로 탐색, 없으면 영문 폰트로 대체
KOREAN_FONT_CANDIDATES = ["AppleGothic", "Apple SD Gothic Neo", "Malgun Gothic", "NanumGothic", "Noto Sans CJK KR"]
AWS_ORANGE = "#FF9900"
VPC_GREEN = "#1D8102"
SUBNET_BLUE = "#248814"
EC2_ORANGE = "#ED7100"
SG_RED = "#DD344C"
GRAY = "#545B64"


def pick_font() -> str:
    available = {f.name for f in matplotlib.font_manager.fontManager.ttflist}
    for name in KOREAN_FONT_CANDIDATES:
        if name in available:
            return name
    return "DejaVu Sans"


def box(ax, x, y, w, h, label, color, *, fill="none", lw=2.0, fontsize=11, title_pos="tl", style="round,pad=0.02"):
    patch = FancyBboxPatch((x, y), w, h, boxstyle=style, linewidth=lw, edgecolor=color, facecolor=fill)
    ax.add_patch(patch)
    if title_pos == "tl":
        ax.text(x + 0.15, y + h - 0.15, label, ha="left", va="top", fontsize=fontsize, color=color, weight="bold")
    else:
        ax.text(x + w / 2, y + h / 2, label, ha="center", va="center", fontsize=fontsize, color=color, weight="bold")
    return patch


def arrow(ax, start, end, label="", color=GRAY, offset=(0.0, 0.0), fontsize=9):
    ax.add_patch(FancyArrowPatch(start, end, arrowstyle="-|>", mutation_scale=18, linewidth=2, color=color))
    if label:
        mx, my = (start[0] + end[0]) / 2 + offset[0], (start[1] + end[1]) / 2 + offset[1]
        ax.text(mx, my, label, ha="center", va="center", fontsize=fontsize, color=color,
                bbox=dict(boxstyle="round,pad=0.25", fc="white", ec="none"))


def main() -> None:
    font = pick_font()
    plt.rcParams["font.family"] = font
    plt.rcParams["font.monospace"] = [font, "DejaVu Sans Mono"]
    plt.rcParams["axes.unicode_minus"] = False

    fig, ax = plt.subplots(figsize=(14, 9), dpi=160)
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 9)
    ax.axis("off")

    ax.text(7, 8.6, "Codyssey B3-1  ·  AWS 단일 Public Subnet 웹 서비스 아키텍처  (ap-northeast-2, 서울)",
            ha="center", va="center", fontsize=14, weight="bold", color="#232F3E")

    # AWS Cloud / Region (계정 수준)
    box(ax, 4.2, 0.5, 9.4, 7.6, "AWS Cloud  ·  Region: ap-northeast-2 (Seoul)", "#232F3E", lw=1.5, fontsize=10)

    # IAM (계정 수준 통제, VPC 바깥)
    box(ax, 8.4, 7.3, 5.0, 0.6, "", SG_RED, fill="#FDECEE", lw=1.5)
    ax.text(10.9, 7.6, "IAM User 1개 · 최소권한(EC2/VPC/SG만) · AdministratorAccess 없음",
            ha="center", va="center", fontsize=8.5, color=SG_RED, weight="bold")

    # VPC
    box(ax, 4.6, 0.9, 8.6, 6.2, "VPC  10.0.0.0/16", VPC_GREEN, fontsize=12)

    # Route Table (Public Subnet 바로 위)
    box(ax, 7.2, 5.6, 3.1, 1.3, "", GRAY, fill="#F2F3F3", lw=1.5)
    ax.text(8.75, 6.65, "Route Table (Public)", ha="center", va="center", fontsize=10, weight="bold", color=GRAY)
    ax.text(8.75, 6.25, "10.0.0.0/16 → local", ha="center", va="center", fontsize=9, color=GRAY, family="monospace")
    ax.text(8.75, 5.9, "0.0.0.0/0   → igw-xxxx", ha="center", va="center", fontsize=9, color=GRAY, family="monospace")
    arrow(ax, (7.5, 5.6), (7.5, 5.32), "", color=GRAY)
    ax.text(7.62, 5.45, "subnet에 연결(associate)", ha="left", va="center", fontsize=8, color=GRAY)

    # 아웃바운드 설명 (Route Table 오른쪽)
    ax.text(11.6, 6.25, "아웃바운드 인터넷\n(apt, curl https://example.com)\nEC2 → 0.0.0.0/0 경로 → IGW",
            ha="center", va="center", fontsize=8.5, color="#2E7D32")

    # Public Subnet
    box(ax, 6.6, 1.3, 6.2, 4.0, "Public Subnet  10.0.1.0/24  (2a)  ·  퍼블릭 IP 자동할당 ON",
        SUBNET_BLUE, fill="#F1F8E9", fontsize=10)

    # Security Group (EC2를 둘러싼 Stateful 방화벽)
    box(ax, 7.0, 1.6, 5.4, 3.1, "", SG_RED)
    ax.text(12.25, 4.55, "Security Group (Stateful 방화벽)", ha="right", va="top", fontsize=10, color=SG_RED,
            weight="bold")
    ax.text(7.2, 2.7, "Inbound  TCP 80  ←  0.0.0.0/0      (HTTP, 누구나)", fontsize=9, color=SG_RED, family="monospace")
    ax.text(7.2, 2.4, "Inbound  TCP 22  ←  <내 IP>/32     (SSH, 본인만)", fontsize=9, color=SG_RED, family="monospace")
    ax.text(7.2, 2.1, "Outbound ALL     →  0.0.0.0/0      (기본값 유지)", fontsize=9, color=SG_RED, family="monospace")
    ax.text(7.2, 1.75, "※ 0.0.0.0/0 에 전체 포트(0-65535) 허용 규칙 없음", fontsize=8.5, color=SG_RED)

    # EC2
    box(ax, 7.4, 3.0, 4.6, 1.3, "", EC2_ORANGE, fill="#FFF8F0", lw=2.2)
    ax.text(9.7, 3.98, "EC2  t2.micro / t3.micro  ·  Ubuntu 24.04 LTS  ·  EBS 8 GiB", ha="center", va="center",
            fontsize=10, weight="bold", color=EC2_ORANGE)
    ax.text(9.7, 3.58, "Nginx :80   /  → index.html   ·   /health → 200 \"OK\"", ha="center", va="center",
            fontsize=9, color="#232F3E", family="monospace")
    ax.text(9.7, 3.22, "Private IP 10.0.1.x   ·   Public IP x.x.x.x", ha="center", va="center", fontsize=9, color=GRAY)

    # Internet Gateway (VPC 경계에 걸침)
    box(ax, 4.1, 4.3, 1.9, 1.0, "Internet\nGateway", AWS_ORANGE, fill="#FFF3E0", title_pos="c", fontsize=10)

    # 외부 사용자 / 평가자
    box(ax, 0.4, 4.1, 2.6, 1.4, "", "#232F3E", fill="#FFFFFF", lw=1.5)
    ax.text(1.7, 5.1, "인터넷 사용자 / 평가자", ha="center", va="center", fontsize=10, weight="bold", color="#232F3E")
    ax.text(1.7, 4.65, "브라우저 http://<퍼블릭IP>/\ncurl http://<퍼블릭IP>/health", ha="center", va="center",
            fontsize=8.5, color=GRAY, family="monospace")

    # 학습자 (SSH)
    box(ax, 0.4, 2.6, 2.6, 1.2, "", "#232F3E", fill="#FFFFFF", lw=1.5)
    ax.text(1.7, 3.45, "학습자 (내 IP)", ha="center", va="center", fontsize=10, weight="bold", color="#232F3E")
    ax.text(1.7, 3.0, "ssh -i key.pem ubuntu@<퍼블릭IP>", ha="center", va="center", fontsize=8.5, color=GRAY,
            family="monospace")

    # 인바운드 HTTP 흐름 (파랑)
    arrow(ax, (3.0, 4.8), (4.1, 4.8), "① HTTP :80", color="#1565C0", offset=(0, 0.28))
    arrow(ax, (6.0, 4.8), (7.4, 4.0), "② 라우팅 → SG 80 허용", color="#1565C0", offset=(-0.35, 0.42), fontsize=8.5)
    ax.text(5.45, 4.05, "③ Nginx 200 응답\n(Stateful → 응답 자동 허용)", ha="center", va="center", fontsize=8,
            color="#1565C0")

    # SSH (보라)
    arrow(ax, (3.0, 3.3), (7.4, 3.3), "SSH :22  (내 IP /32 만 허용)", color="#6A1B9A", offset=(-1.1, 0.22), fontsize=8.5)

    # 아웃바운드 (초록): EC2 → 서브넷 밖 → Route Table 설명으로
    ax.add_patch(FancyArrowPatch((12.0, 3.7), (12.6, 3.7), arrowstyle="-", linewidth=2, color="#2E7D32"))
    arrow(ax, (12.6, 3.7), (12.6, 5.7), "", color="#2E7D32")

    legend = ("범례:  파랑 = 외부 → 서비스 인바운드 HTTP,   보라 = 운영자 SSH,   초록 = EC2 아웃바운드 인터넷\n"
              "요청 경로:  사용자 → Internet → IGW → Route Table(0.0.0.0/0) → Public Subnet → Security Group(80 허용) → EC2 ENI → Nginx")
    ax.text(7, 0.2, legend, ha="center", va="center", fontsize=8.5, color=GRAY)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUTPUT, bbox_inches="tight", facecolor="white")
    print(f"saved: {OUTPUT}")


if __name__ == "__main__":
    main()
