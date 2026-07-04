import React from "react";
import { ensureHarpyCss } from "./Button.jsx";
import { Icon } from "./Icon.jsx";

const harpyCalloutCss = `
.hp-callout{display:flex;gap:10px;padding:12px 14px;border-radius:var(--radius-md);font-family:var(--font-sans);font-size:var(--text-sm);line-height:var(--leading-snug);}
.hp-callout__icon{margin-top:1px;}
.hp-callout__title{font-weight:var(--weight-semibold);margin:0 0 2px;}
.hp-callout--info{background:var(--status-info-bg);color:var(--status-info-text);}
.hp-callout--success{background:var(--status-success-bg);color:var(--status-success-text);}
.hp-callout--warning{background:var(--status-warning-bg);color:var(--status-warning-text);}
.hp-callout--error{background:var(--status-error-bg);color:var(--status-error-text);}
`;

const harpyCalloutIcons = {
  info: "info",
  success: "circle-check",
  warning: "triangle-alert",
  error: "circle-alert",
};

export function Callout({ variant = "info", title, children, className = "", ...rest }) {
  ensureHarpyCss("hp-callout-css", harpyCalloutCss);
  return (
    <div className={`hp-callout hp-callout--${variant} ${className}`} role="status" {...rest}>
      <Icon className="hp-callout__icon" name={harpyCalloutIcons[variant]} size={16} />
      <div>
        {title ? <p className="hp-callout__title">{title}</p> : null}
        <div>{children}</div>
      </div>
    </div>
  );
}
