import React from "react";
import { ensureHarpyCss } from "../core/Button.jsx";

const harpyTooltipCss = `
.hp-tooltip-wrap{position:relative;display:inline-flex;}
.hp-tooltip{position:absolute;bottom:calc(100% + 6px);left:50%;transform:translateX(-50%) translateY(2px);background:var(--surface-inverse);color:var(--text-inverse);font-family:var(--font-sans);font-size:var(--text-xs);font-weight:var(--weight-medium);line-height:1.3;padding:5px 8px;border-radius:var(--radius-sm);white-space:nowrap;pointer-events:none;opacity:0;transition:opacity var(--duration-fast) var(--ease-out),transform var(--duration-fast) var(--ease-out);z-index:50;}
.hp-tooltip-wrap:hover .hp-tooltip,.hp-tooltip-wrap:focus-within .hp-tooltip{opacity:1;transform:translateX(-50%) translateY(0);}
.hp-tooltip--bottom{bottom:auto;top:calc(100% + 6px);}
`;

export function Tooltip({ label, side = "top", children, className = "", ...rest }) {
  ensureHarpyCss("hp-tooltip-css", harpyTooltipCss);
  return (
    <span className={`hp-tooltip-wrap ${className}`} {...rest}>
      {children}
      <span className={`hp-tooltip ${side === "bottom" ? "hp-tooltip--bottom" : ""}`} role="tooltip">
        {label}
      </span>
    </span>
  );
}
