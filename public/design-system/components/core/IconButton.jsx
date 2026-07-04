import React from "react";
import { ensureHarpyCss } from "./Button.jsx";

const harpyIconButtonCss = `
.hp-iconbtn{display:inline-flex;align-items:center;justify-content:center;border:1px solid transparent;border-radius:var(--radius-md);background:transparent;color:var(--text-secondary);cursor:pointer;transition:background var(--duration-fast) var(--ease-out),color var(--duration-fast) var(--ease-out);}
.hp-iconbtn:hover:not(:disabled){background:var(--ink-100);color:var(--text-body);}
.hp-iconbtn:active:not(:disabled){background:var(--ink-200);}
.hp-iconbtn:focus-visible{outline:none;box-shadow:var(--focus-ring);}
.hp-iconbtn:disabled{opacity:.45;cursor:not-allowed;}
.hp-iconbtn--outline{border-color:var(--border-strong);background:var(--surface-card);}
.hp-iconbtn--sm{width:28px;height:28px;}
.hp-iconbtn--md{width:36px;height:36px;}
.hp-iconbtn--lg{width:44px;height:44px;}
`;

export function IconButton({ variant = "ghost", size = "md", "aria-label": ariaLabel, children, className = "", ...rest }) {
  ensureHarpyCss("hp-iconbtn-css", harpyIconButtonCss);
  return (
    <button
      className={`hp-iconbtn hp-iconbtn--${variant} hp-iconbtn--${size} ${className}`}
      aria-label={ariaLabel}
      {...rest}
    >
      {children}
    </button>
  );
}
