"""
Converts a question body containing mixed plain text + LaTeX (delimited by
$...$ inline or $$...$$ block, per point #20/6 in the spec) into HTML the
WeasyPrint template can render, with LaTeX segments rasterized to inline
SVG/PNG via matplotlib's mathtext (no external LaTeX install required,
which keeps this deployable on a normal server / container).
"""
import re
import base64
import io
from django.utils.html import escape

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

LATEX_PATTERN = re.compile(r'\$\$(.+?)\$\$|\$(.+?)\$', re.DOTALL)


def _render_latex_to_data_uri(latex_src: str, fontsize: int = 16) -> str:
    """Rasterize a LaTeX/mathtext expression to a base64 PNG data URI."""
    fig = plt.figure(figsize=(0.01, 0.01))
    fig.patch.set_alpha(0)
    text = fig.text(0, 0, f"${latex_src}$", fontsize=fontsize)

    buf = io.BytesIO()
    fig.savefig(buf, format='png', dpi=220, transparent=True, bbox_inches='tight', pad_inches=0.03)
    plt.close(fig)
    buf.seek(0)
    b64 = base64.b64encode(buf.read()).decode('ascii')
    return f"data:image/png;base64,{b64}"


def render_mixed_body(raw_body: str, latex_fontsize: int = 16) -> str:
    """
    Turns raw_body (plain text interleaved with $...$/$$...$$ LaTeX) into
    safe HTML with LaTeX segments replaced by <img> tags, and everything
    else HTML-escaped (never trust stored question text as raw HTML).
    """
    out = []
    last_end = 0
    for match in LATEX_PATTERN.finditer(raw_body):
        out.append(escape(raw_body[last_end:match.start()]))
        latex_src = match.group(1) or match.group(2)
        is_block = match.group(1) is not None
        try:
            data_uri = _render_latex_to_data_uri(latex_src, fontsize=latex_fontsize)
            style = 'display:block;margin:4px auto;' if is_block else 'vertical-align:middle;'
            out.append(f'<img class="latex" style="{style}" src="{data_uri}">')
        except Exception:
            # Fail safe: fall back to showing the raw source rather than crashing PDF generation
            out.append(f'<code>{escape(latex_src)}</code>')
        last_end = match.end()
    out.append(escape(raw_body[last_end:]))
    return ''.join(out)
