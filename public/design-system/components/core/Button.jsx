import React from "react";

const harpyButtonCss = `
.hp-btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;border:1px solid transparent;border-radius:var(--radius-md);font-family:var(--font-sans);font-weight:var(--weight-medium);cursor:pointer;transition:background var(--duration-fast) var(--ease-out),border-color var(--duration-fast) var(--ease-out);white-space:nowrap;}
.hp-btn:focus-visible{outline:none;box-shadow:var(--focus-ring);}
.hp-btn:disabled{opacity:.45;cursor:not-allowed;}
.hp-btn--md{height:36px;padding:0 16px;font-size:var(--text-base);}
.hp-btn--sm{height:28px;padding:0 12px;font-size:var(--text-sm);}
.hp-btn--lg{height:44px;padding:0 20px;font-size:var(--text-md);}
.hp-btn--primary{background:var(--accent);color:var(--accent-contrast);}
.hp-btn--primary:hover:not(:disabled){background:var(--accent-hover);}
.hp-btn--primary:active:not(:disabled){background:var(--accent-active);}
.hp-btn--secondary{background:var(--surface-card);border-color:var(--border-strong);color:var(--text-body);}
.hp-btn--secondary:hover:not(:disabled){background:var(--ink-100);}
.hp-btn--secondary:active:not(:disabled){background:var(--ink-200);}
.hp-btn--ghost{background:transparent;color:var(--text-body);}
.hp-btn--ghost:hover:not(:disabled){background:var(--ink-100);}
.hp-btn--ghost:active:not(:disabled){background:var(--ink-200);}
.hp-btn--danger{background:var(--status-error);color:var(--ink-0);}
.hp-btn--danger:hover:not(:disabled){background:var(--red-700);}
.hp-btn--danger:active:not(:disabled){background:var(--red-700);}
`;

export function ensureHarpyCss(id, css) {
  if (typeof document === "undefined") return;
  if (document.getElementById(id)) return;
  const el = document.createElement("style");
  el.id = id;
  el.textContent = css;
  document.head.appendChild(el);
}

export function Button({ variant = "primary", size = "md", icon, children, className = "", ...rest }) {
  ensureHarpyCss("hp-btn-css", harpyButtonCss);
  return (
    <button className={`hp-btn hp-btn--${variant} hp-btn--${size} ${className}`} {...rest}>
      {icon}
      {children}
    </button>
  );
}
