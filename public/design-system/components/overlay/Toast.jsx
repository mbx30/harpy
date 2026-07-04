import React from "react";
import { ensureHarpyCss } from "../core/Button.jsx";
import { Icon } from "../core/Icon.jsx";
import { IconButton } from "../core/IconButton.jsx";

const harpyToastCss = `
@keyframes hp-toast-in { from { opacity: 0; transform: translateY(6px); } to { opacity: 1; transform: none; } }
.hp-toast{display:flex;align-items:center;gap:10px;background:var(--surface-inverse);color:var(--text-inverse);border-radius:var(--radius-md);box-shadow:var(--shadow-lg);padding:10px 12px;font-family:var(--font-sans);font-size:var(--text-sm);font-weight:var(--weight-medium);max-width:360px;animation:hp-toast-in var(--duration-slow) var(--ease-out);}
.hp-toast__icon--success{color:var(--sun-400);}
.hp-toast__icon--error{color:#E58B75;}
.hp-toast__msg{flex:1;}
.hp-toast .hp-iconbtn{color:var(--ink-400);}
.hp-toast .hp-iconbtn:hover:not(:disabled){background:var(--ink-800);color:var(--ink-0);}
`;

const harpyToastIcons = { success: "circle-check", error: "circle-alert", neutral: "info" };

export function Toast({ variant = "neutral", onDismiss, children, className = "", ...rest }) {
  ensureHarpyCss("hp-toast-css", harpyToastCss);
  return (
    <div className={`hp-toast ${className}`} role="status" {...rest}>
      <span className={`hp-toast__icon--${variant}`} style={{ display: "inline-flex" }}>
        <Icon name={harpyToastIcons[variant]} size={16} />
      </span>
      <span className="hp-toast__msg">{children}</span>
      {onDismiss ? (
        <IconButton size="sm" aria-label="Dismiss" onClick={onDismiss}>
          <Icon name="x" size={14} />
        </IconButton>
      ) : null}
    </div>
  );
}
