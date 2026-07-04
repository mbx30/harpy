import React from "react";
import { ensureHarpyCss } from "./Button.jsx";
import { Icon } from "./Icon.jsx";

const harpyTagCss = `
.hp-tag{display:inline-flex;align-items:center;gap:6px;height:24px;padding:0 4px 0 10px;border-radius:var(--radius-pill);border:1px solid var(--border-default);background:var(--surface-card);font-family:var(--font-sans);font-size:var(--text-xs);font-weight:var(--weight-medium);color:var(--text-body);white-space:nowrap;}
.hp-tag--plain{padding-right:10px;}
.hp-tag__x{display:inline-flex;align-items:center;justify-content:center;width:16px;height:16px;border:none;border-radius:50%;background:transparent;color:var(--text-muted);cursor:pointer;transition:background var(--duration-fast) var(--ease-out),color var(--duration-fast) var(--ease-out);padding:0;}
.hp-tag__x:hover{background:var(--ink-100);color:var(--text-body);}
.hp-tag__x:focus-visible{outline:none;box-shadow:var(--focus-ring);}
`;

export function Tag({ onRemove, children, className = "", ...rest }) {
  ensureHarpyCss("hp-tag-css", harpyTagCss);
  return (
    <span className={`hp-tag ${onRemove ? "" : "hp-tag--plain"} ${className}`} {...rest}>
      {children}
      {onRemove ? (
        <button type="button" className="hp-tag__x" aria-label="Remove" onClick={onRemove}>
          <Icon name="x" size={11} />
        </button>
      ) : null}
    </span>
  );
}
