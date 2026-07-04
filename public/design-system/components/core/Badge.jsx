import React from "react";
import { ensureHarpyCss } from "./Button.jsx";

const harpyBadgeCss = `
.hp-badge{display:inline-flex;align-items:center;gap:6px;height:22px;padding:0 10px;border-radius:var(--radius-pill);font-family:var(--font-sans);font-size:var(--text-xs);font-weight:var(--weight-medium);white-space:nowrap;}
.hp-badge__dot{width:6px;height:6px;border-radius:50%;background:currentColor;}
.hp-badge--neutral{background:var(--ink-100);color:var(--ink-700);}
.hp-badge--accent{background:var(--sun-100);color:var(--sun-700);}
.hp-badge--success{background:var(--status-success-bg);color:var(--status-success-text);}
.hp-badge--error{background:var(--status-error-bg);color:var(--status-error-text);}
.hp-badge--warning{background:var(--status-warning-bg);color:var(--status-warning-text);}
.hp-badge--info{background:var(--status-info-bg);color:var(--status-info-text);}
`;

export function Badge({ variant = "neutral", dot = false, children, className = "", ...rest }) {
  ensureHarpyCss("hp-badge-css", harpyBadgeCss);
  return (
    <span className={`hp-badge hp-badge--${variant} ${className}`} {...rest}>
      {dot ? <span className="hp-badge__dot"></span> : null}
      {children}
    </span>
  );
}
