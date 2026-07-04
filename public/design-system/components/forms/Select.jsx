import React from "react";
import { ensureHarpyCss } from "../core/Button.jsx";
import { Icon } from "../core/Icon.jsx";

const harpySelectCss = `
.hp-select-wrap{position:relative;display:inline-flex;width:100%;}
.hp-select{appearance:none;width:100%;height:36px;padding:0 34px 0 12px;border:1px solid var(--border-strong);border-radius:var(--radius-md);background:var(--surface-card);font-family:var(--font-sans);font-size:var(--text-base);color:var(--text-body);cursor:pointer;transition:border-color var(--duration-fast) var(--ease-out);}
.hp-select:hover:not(:disabled){border-color:var(--ink-400);}
.hp-select:focus{outline:none;border-color:var(--sun-400);box-shadow:var(--focus-ring);}
.hp-select:disabled{background:var(--surface-sunken);color:var(--text-muted);cursor:not-allowed;}
.hp-select-wrap__chevron{position:absolute;right:10px;top:50%;transform:translateY(-50%);color:var(--text-muted);pointer-events:none;display:inline-flex;}
`;

export function Select({ children, className = "", style, ...rest }) {
  ensureHarpyCss("hp-select-css", harpySelectCss);
  return (
    <span className="hp-select-wrap" style={style}>
      <select className={`hp-select ${className}`} {...rest}>
        {children}
      </select>
      <span className="hp-select-wrap__chevron">
        <Icon name="chevron-down" size={16} />
      </span>
    </span>
  );
}
