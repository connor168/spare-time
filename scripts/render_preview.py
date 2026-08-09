from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "preview" / "focus_flow_preview.png"

BG = (246, 248, 247, 255)
SURFACE = (255, 255, 255, 255)
SURFACE_SOFT = (238, 247, 244, 255)
TEXT = (20, 48, 43, 255)
MUTED = (96, 113, 108, 255)
ACCENT = (21, 122, 110, 255)
ACCENT_SOFT = (220, 243, 237, 255)
BORDER = (214, 224, 220, 255)
SHADOW = (20, 48, 43, 34)
PHONE_FRAME = (21, 24, 28, 255)
TABLET_FRAME = (18, 21, 24, 255)


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(Path(r"C:\Windows\Fonts") / name), size=size)


F_REG = font("msyh.ttc", 18)
F_BOLD = font("msyhbd.ttc", 18)
F_SMALL = font("msyh.ttc", 14)
F_SMALL_BOLD = font("msyhbd.ttc", 14)
F_TINY = font("msyh.ttc", 12)
F_TINY_BOLD = font("msyhbd.ttc", 12)


def rounded_shadow(base: Image.Image, xy: tuple[int, int, int, int], radius: int, fill: tuple[int, int, int, int]) -> None:
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(shadow)
    draw.rounded_rectangle((xy[0] + 8, xy[1] + 12, xy[2] + 8, xy[3] + 12), radius=radius, fill=SHADOW)
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    base.alpha_composite(shadow)
    draw = ImageDraw.Draw(base)
    draw.rounded_rectangle(xy, radius=radius, fill=fill)


def draw_text(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, fill, font_obj, anchor: str = "la") -> None:
    draw.text(xy, text, font=font_obj, fill=fill, anchor=anchor)


def line(draw: ImageDraw.ImageDraw, xy, fill, width=1):
    draw.line(xy, fill=fill, width=width)


def handle(draw: ImageDraw.ImageDraw, cx: int, cy: int, color) -> None:
    for offset in (-8, 0, 8):
        line(draw, (cx - 8, cy + offset, cx + 8, cy + offset), color, width=2)


def circle(draw: ImageDraw.ImageDraw, bbox, fill):
    draw.ellipse(bbox, fill=fill)


def draw_phone(base: Image.Image, x: int, y: int) -> None:
    outer = (x, y, x + 430, y + 890)
    rounded_shadow(base, outer, 40, PHONE_FRAME)
    screen = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(screen)
    sx, sy = x + 16, y + 16
    ex, ey = x + 414, y + 874
    draw.rounded_rectangle((sx, sy, ex, ey), radius=30, fill=BG)

    draw.text((sx + 16, sy + 18), "09:41", font=F_TINY_BOLD, fill=(70, 85, 80, 255))
    draw.text((ex - 58, sy + 18), "5G  ▪︎  92%", font=F_TINY_BOLD, fill=(70, 85, 80, 255), anchor="ra")

    # app bar
    ay = sy + 52
    draw.rounded_rectangle((sx + 14, ay, ex - 14, ay + 76), radius=24, fill=(255, 255, 255, 215), outline=BORDER, width=1)
    circle(draw, (sx + 30, ay + 18, sx + 66, ay + 54), fill=ACCENT)
    draw.text((sx + 78, ay + 19), "Focus Flow", font=F_BOLD, fill=TEXT)
    draw.text((sx + 78, ay + 44), "今天的安排", font=F_TINY, fill=MUTED)
    draw.rounded_rectangle((ex - 96, ay + 18, ex - 24, ay + 54), radius=18, fill=SURFACE_SOFT, outline=BORDER, width=1)
    draw.text((ex - 60, ay + 35), "+ 新建", font=F_TINY_BOLD, fill=ACCENT, anchor="mm")

    # title
    tx = sx + 18
    ty = ay + 98
    draw.text((tx, ty), "周五 · 8 月 7 日", font=F_TINY, fill=MUTED)
    draw.text((tx, ty + 32), "把今天安排好", font=font("msyhbd.ttc", 28), fill=TEXT)

    # progress card
    cy = ty + 92
    draw.rounded_rectangle((sx + 16, cy, ex - 16, cy + 128), radius=24, fill=SURFACE_SOFT, outline=(209, 231, 226, 255), width=1)
    circle(draw, (sx + 36, cy + 34, sx + 96, cy + 94), fill=(255, 255, 255, 255))
    circle(draw, (sx + 36, cy + 34, sx + 96, cy + 94), fill=None)
    draw.arc((sx + 36, cy + 34, sx + 96, cy + 94), start=210, end=360, fill=ACCENT, width=8)
    draw.arc((sx + 36, cy + 34, sx + 96, cy + 94), start=0, end=210, fill=(192, 230, 223, 255), width=8)
    draw.text((sx + 66, cy + 65), "2/3", font=F_TINY_BOLD, fill=ACCENT, anchor="mm")
    draw.text((sx + 116, cy + 38), "2 / 3 已完成", font=F_BOLD, fill=TEXT)
    draw.text((sx + 116, cy + 68), "保持专注，按时间推进，提醒会在到点时出现。", font=F_SMALL, fill=MUTED)

    # focus card
    fy = cy + 146
    draw.rounded_rectangle((sx + 16, fy, ex - 16, fy + 90), radius=22, fill=SURFACE, outline=BORDER, width=1)
    circle(draw, (sx + 34, fy + 30, sx + 52, fy + 48), fill=ACCENT)
    draw.text((sx + 66, fy + 24), "下一条提醒", font=F_SMALL_BOLD, fill=TEXT)
    draw.text((sx + 66, fy + 48), "09:00 · 深度工作：产品规格", font=F_TINY, fill=MUTED)

    draw.text((sx + 18, fy + 112), "今日时间轴", font=font("msyhbd.ttc", 22), fill=TEXT)
    draw.text((ex - 18, fy + 114), "任务按各自时区显示", font=F_TINY, fill=MUTED, anchor="ra")

    task_y = fy + 146
    tasks = [
        ("深度工作：产品规格", "09:00 - 10:30", True),
        ("午间散步", "12:30 - 13:00", False),
        ("整理今日笔记", "18:00 - 18:30", True),
    ]
    for i, (title, time_txt, done) in enumerate(tasks):
        y1 = task_y + i * 90
        draw.rounded_rectangle((sx + 16, y1, ex - 16, y1 + 74), radius=18, fill=SURFACE, outline=BORDER, width=1)
        box = (sx + 34, y1 + 28, sx + 52, y1 + 46)
        draw.rounded_rectangle(box, radius=4, outline=(125, 143, 139, 255), width=2)
        if done:
            line(draw, (sx + 37, y1 + 37, sx + 43, y1 + 43), ACCENT, width=2)
            line(draw, (sx + 43, y1 + 43, sx + 50, y1 + 31), ACCENT, width=2)
        draw.text((sx + 66, y1 + 16), title, font=F_SMALL_BOLD, fill=TEXT)
        draw.text((sx + 66, y1 + 40), time_txt, font=F_TINY, fill=(70, 85, 80, 255))
        handle(draw, ex - 28, y1 + 38, (142, 152, 149, 255))

    # bottom nav
    by = ey - 86
    draw.rounded_rectangle((sx, by, ex, ey), radius=24, fill=(255, 255, 255, 242), outline=(228, 233, 231, 255), width=1)
    nav_items = [("今日", True), ("AI 资讯", False), ("知识库", False)]
    for idx, (label, active) in enumerate(nav_items):
        nx0 = sx + 18 + idx * 120
        nx1 = nx0 + 108
        if active:
            draw.rounded_rectangle((nx0, by + 12, nx1, by + 64), radius=16, fill=ACCENT_SOFT)
        circle(draw, (nx0 + 40, by + 18, nx0 + 60, by + 38), fill=ACCENT if active else (140, 151, 148, 255))
        draw.text(((nx0 + nx1) // 2, by + 48), label, font=F_TINY_BOLD if active else F_TINY, fill=ACCENT if active else MUTED, anchor="mm")

    base.alpha_composite(screen)


def draw_tablet(base: Image.Image, x: int, y: int) -> None:
    outer = (x, y, x + 1040, y + 780)
    rounded_shadow(base, outer, 34, TABLET_FRAME)
    screen = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(screen)
    sx, sy = x + 14, y + 14
    ex, ey = x + 1026, y + 766
    draw.rounded_rectangle((sx, sy, ex, ey), radius=26, fill=BG)

    # rail
    rail_w = 104
    draw.rectangle((sx, sy, sx + rail_w, ey), fill=(255, 255, 255, 255))
    draw.line((sx + rail_w, sy, sx + rail_w, ey), fill=BORDER, width=1)
    circle(draw, (sx + 30, sy + 28, sx + 70, sy + 68), fill=ACCENT)
    draw.text((sx + 52, sy + 90), "Focus", font=F_TINY_BOLD, fill=TEXT, anchor="mm")
    draw.text((sx + 52, sy + 110), "Flow", font=F_TINY_BOLD, fill=TEXT, anchor="mm")
    rail_items = [("今日", True), ("AI 资讯", False), ("知识库", False)]
    for idx, (label, active) in enumerate(rail_items):
        iy = sy + 150 + idx * 74
        if active:
            draw.rounded_rectangle((sx + 12, iy - 8, sx + rail_w - 12, iy + 46), radius=16, fill=ACCENT_SOFT)
        circle(draw, (sx + 38, iy, sx + 62, iy + 24), fill=ACCENT if active else (145, 154, 151, 255))
        draw.text((sx + 52, iy + 36), label, font=F_TINY_BOLD if active else F_TINY, fill=ACCENT if active else MUTED, anchor="mm")

    # content header
    cx = sx + rail_w + 18
    draw.text((cx, sy + 24), "平板 / 分屏 / 横屏", font=F_TINY, fill=MUTED)
    draw.text((cx, sy + 54), "更宽的视野，更多信息同时可见", font=font("msyhbd.ttc", 28), fill=TEXT)
    draw.text((cx, sy + 92), "左边看时间轴，右边看提醒和知识库摘要，不需要在几个页面里来回跳。", font=F_SMALL, fill=MUTED)
    draw.rounded_rectangle((ex - 166, sy + 24, ex - 22, sy + 60), radius=18, fill=SURFACE_SOFT, outline=BORDER, width=1)
    draw.text((ex - 94, sy + 42), "+ 新建任务", font=F_TINY_BOLD, fill=ACCENT, anchor="mm")

    # main columns
    col_y = sy + 132
    left_x = cx
    left_w = 474
    right_x = left_x + left_w + 18
    right_w = ex - right_x - 18

    # left column schedule
    draw.rounded_rectangle((left_x, col_y, left_x + left_w, col_y + 286), radius=24, fill=SURFACE, outline=BORDER, width=1)
    draw.text((left_x + 18, col_y + 18), "今日计划", font=F_BOLD, fill=TEXT)
    draw.text((left_x + left_w - 18, col_y + 18), "3 项任务", font=F_TINY, fill=MUTED, anchor="ra")
    events = [
        ("09:00  深度工作：产品规格", "提醒：提前 15 分钟 · Asia/Tokyo"),
        ("12:30  午间散步", "轻任务 · 可拖拽调整"),
        ("18:00  整理今日笔记", "完成后自动归档到知识库"),
    ]
    ey0 = col_y + 62
    for i, (title, meta) in enumerate(events):
        yy = ey0 + i * 72
        draw.rounded_rectangle((left_x + 18, yy, left_x + left_w - 18, yy + 58), radius=18, fill=SURFACE_SOFT, outline=(218, 235, 230, 255), width=1)
        draw.text((left_x + 34, yy + 16), title, font=F_TINY_BOLD, fill=TEXT)
        draw.text((left_x + 34, yy + 36), meta, font=F_TINY, fill=MUTED)

    # right top digest
    draw.rounded_rectangle((right_x, col_y, right_x + right_w, col_y + 286), radius=24, fill=SURFACE, outline=BORDER, width=1)
    draw.text((right_x + 18, col_y + 18), "AI 资讯摘要", font=F_BOLD, fill=TEXT)
    news = [
        ("Agent 工作流仓库热度上升", "open-source/agent-patterns", "围绕工具调用、编排和评估的 GitHub 仓库，适合每日筛选。"),
        ("本地模型工具链更新", "community/local-models", "聚焦轻量部署和端侧推理，适合跟踪趋势和版本变化。"),
    ]
    ny = col_y + 60
    for i, (title, repo, desc) in enumerate(news):
        yy = ny + i * 108
        draw.rounded_rectangle((right_x + 18, yy, right_x + right_w - 18, yy + 92), radius=18, fill=SURFACE_SOFT, outline=(218, 235, 230, 255), width=1)
        draw.text((right_x + 34, yy + 14), title, font=F_TINY_BOLD, fill=TEXT)
        draw.text((right_x + 34, yy + 36), repo, font=F_TINY_BOLD, fill=ACCENT)
        draw.text((right_x + 34, yy + 58), desc, font=F_TINY, fill=MUTED)

    # lower full-width knowledge + editor region
    lower_y = col_y + 304
    lower_x1 = ex - 18
    draw.rounded_rectangle((left_x, lower_y, lower_x1, ey - 18), radius=24, fill=SURFACE, outline=BORDER, width=1)

    notes_w = 338
    notes_x = left_x + 18
    editor_x = notes_x + notes_w + 18
    editor_w = lower_x1 - editor_x - 18

    draw.text((notes_x, lower_y + 18), "知识库", font=F_BOLD, fill=TEXT)
    draw.rounded_rectangle((notes_x, lower_y + 56, notes_x + notes_w, lower_y + 94), radius=16, fill=(255, 255, 255, 255), outline=BORDER, width=1)
    draw.text((notes_x + 16, lower_y + 74), "搜索笔记、标签、片段", font=F_TINY, fill=MUTED, anchor="lm")

    chips = [("全部", True), ("工作流", False), ("想法", False), ("书摘", False)]
    chip_x = notes_x
    chip_y = lower_y + 108
    for label, active in chips:
        w = 52 + len(label) * 10
        if chip_x + w > notes_x + notes_w:
            break
        draw.rounded_rectangle((chip_x, chip_y, chip_x + w, chip_y + 30), radius=15, fill=ACCENT_SOFT if active else SURFACE, outline=(187, 227, 219, 255) if active else BORDER, width=1)
        draw.text((chip_x + w / 2, chip_y + 15), label, font=F_TINY_BOLD if active else F_TINY, fill=ACCENT if active else MUTED, anchor="mm")
        chip_x += w + 8

    notes = [
        "把复杂问题拆成可验证的假设",
        "夜间复盘模板",
    ]
    for i, title in enumerate(notes):
        yy = lower_y + 154 + i * 78
        draw.rounded_rectangle((notes_x, yy, notes_x + notes_w, yy + 60), radius=16, fill=SURFACE_SOFT, outline=(218, 235, 230, 255), width=1)
        draw.text((notes_x + 16, yy + 16), title, font=F_TINY_BOLD, fill=TEXT)
        draw.text((notes_x + 16, yy + 36), "今天看到的 AI 趋势、任务复盘和灵感片段。", font=F_TINY, fill=MUTED)

    draw.text((editor_x, lower_y + 18), "编辑区示意", font=F_BOLD, fill=TEXT)
    draw.rounded_rectangle((editor_x, lower_y + 56, editor_x + editor_w, lower_y + 92), radius=16, fill=(255, 255, 255, 255), outline=BORDER, width=1)
    draw.text((editor_x + 16, lower_y + 74), "标题：今天的工作要点", font=F_TINY, fill=MUTED, anchor="lm")
    draw.rounded_rectangle((editor_x, lower_y + 108, editor_x + editor_w, ey - 78), radius=16, fill=(255, 255, 255, 255), outline=BORDER, width=1)
    draw.multiline_text((editor_x + 16, lower_y + 126), "内容：这里写下今天看到的 AI 趋势、任务复盘\n和灵感片段。支持 Markdown、搜索和导出。", font=F_TINY, fill=MUTED, spacing=8)
    draw.text((editor_x, ey - 44), "这块后续会接到本地数据库和离线同步。", font=F_TINY, fill=MUTED)

    base.alpha_composite(screen)


def draw_background(base: Image.Image) -> None:
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    d.ellipse((-120, -160, 780, 620), fill=(21, 122, 110, 26))
    d.ellipse((1180, 460, 1900, 1180), fill=(55, 98, 206, 18))
    d.ellipse((1240, -140, 1740, 340), fill=(21, 122, 110, 18))
    overlay = overlay.filter(ImageFilter.GaussianBlur(40))
    base.alpha_composite(overlay)


def main() -> None:
    canvas = Image.new("RGBA", (1780, 1180), BG)
    draw_background(canvas)
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle((34, 30, 170, 64), radius=18, fill=(255, 255, 255, 210), outline=(229, 234, 231, 255), width=1)
    circle(d, (48, 42, 62, 56), fill=ACCENT)
    draw_text(d, (74, 49), "静态预览", MUTED, F_TINY_BOLD, anchor="lm")
    draw_text(d, (38, 104), "Focus Flow", TEXT, font("msyhbd.ttc", 34))
    draw_text(d, (38, 150), "这是当前 Flutter 原型的浏览器版示意，先把手机 / 平板布局和内容结构给你看。", MUTED, F_SMALL)
    draw_text(d, (38, 188), "实际 App 还在等 Flutter SDK 安装后再跑真机。", MUTED, F_SMALL)
    d.rounded_rectangle((1468, 34, 1722, 74), radius=20, fill=(255, 255, 255, 210), outline=(229, 234, 231, 255), width=1)
    draw_text(d, (1595, 54), "兼容：手机 · 平板 · 横竖屏 · 分屏", ACCENT, F_TINY_BOLD, anchor="mm")

    draw_phone(canvas, 46, 258)
    draw_tablet(canvas, 500, 258)

    canvas = canvas.convert("RGB")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(OUT, quality=95)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
